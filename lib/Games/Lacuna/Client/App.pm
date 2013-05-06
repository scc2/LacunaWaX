use 5.12.0;
package Games::Lacuna::Client::App;
use Data::Dumper; $Data::Dumper::Indent = 1;
use Moose;
use MooseX::NonMoose;
use Moose::Util::TypeConstraints;
extends qw( Games::Lacuna::Client );

# $Id: App.pm 308 2013-04-24 21:05:58Z jon $
# $URL: https://tmtowtdi.gotdns.com:15000/svn/LacunaWaX/trunk/lib/Games/Lacuna/Client/App.pm $

use Carp qw(carp croak confess);
use CHI;
use DateTime;
use DateTime::Format::ISO8601;
use File::Temp qw(tempdir);
use Games::Lacuna::Client::Util;
use Games::Lacuna::Client::Task::Mailbox;
use Games::Lacuna::Schema;
use Log::Dispatch;
use Math::BigFloat;
use Try::Tiny;
use WWW::Mechanize;
use YAML::XS;

BEGIN {
    my $revision = '$Rev: 308 $';
    $Games::Lacuna::Client::Task::App::VERSION = '0.1.' . join '', $revision =~ m/(\d+)/;
}

### Required
has 'name'     => ( is => 'rw', isa => 'Str' );
has 'password' => ( is => 'rw', isa => 'Str' );
has 'schema' => (
    is          => 'rw',
    isa         => 'Games::Lacuna::Schema', 
    required    => 1,
);
has 'users_schema' => (
    is          => 'rw',
    isa         => 'Games::Lacuna::Webtools::Schema',
    required    => 1,
);

### Required by GLC, but defaults given.
has 'uri' => ( 
    is      => 'rw',
    isa     => 'Str',
    default => 'https://us1.lacunaexpanse.com',
    documentation => q{ This absolutely cannot end with a slash. }
);
has 'api_key'  => (
    is      => 'rw',
    isa     => 'Str',
    default => '02484d96-804d-43e9-a6c4-e8e80f239573',  # tmtowtdi's API key
);

### Optional
has 'no_cache'  => (
    is      => 'rw',
    isa     => 'Int',
    default => sub{1},
    documentation => q{
        Tells the Task/* modules whether or not they should use their internal caches.
    }
);
has 'caller_type'  => (
    is      => 'rw',
    isa     => enum( [qw(local web)] ),
    default => sub{ 'local' },
    documentation => q{
        When this is 'local' call() will sleep for a minute, then re-attempt 
        the request, when it encounters the Slow down! RPC usage error.
        When this is 'web', call() will simply die on that error; you must catch 
        the death.
        This may soon be deprecated; I've been using a separate 'webcall' sub 
        in my webapp.
    }
);
has 'chi' => ( 
    is          => 'rw',
    isa         => 'Object',
    lazy_build  => 1,
    trigger     => sub {
        my $self    = shift;
        my $new_chi = shift;
        unless( $new_chi->driver_class eq 'CHI::Driver::RawMemory' ) {
            die "RawMemory driver required for built-in CHI object; got " . $new_chi->driver_class;
        }
    },
    documentation => q{
        Right now, each of my Task::*.pm modules that have their own CHI object are
        creating them themselves.

        This is retarded.  Those modules should each be using $client->chi rather than
        making new CHI objects of their own.

        CHI.pm is doing some horsing around with Moose and Class::MOP, so doing 
                my $c = CHI->new(...);
                say ref $c;
        ...returns 'Moose::Meta::Class::__ANON__::SERIAL::<INCREMENTING INTEGER>'.
        Since the CHI object's class changes each time it's constructed, I can't tell
        Moose that this isa => 'Cache::CHI'.  So it isa => 'Object'.
    },
);


###########################################################################################

has 'log_file'    => (
    is      => 'rw',
    isa     => 'Str',
    default => sub{q//},
    documentation => q{
        DEPRECATED
        Path to logfile, will be created if ! exists and appended to if it does.
        But see the 'log' and 'logger' attributes below; this 'log_file' 
        attribute is eventually going away.
    },
);
has 'log_screen'  => (
    is      => 'rw',
    isa     => 'Int',
    default => sub{1},
    documentation => q{
        DEPRECATED
        Boolean.  If on, the default, we'll log to STDOUT.
        But see the 'log' and 'logger' attributes below; this 'log_screen' 
        attribute is eventually going away.
    }
);

### 'log' is the LD object used throughout all my GLC modules.  This module 
### creates that log object based on the log_file and log_screen parameters...
has 'log'       => ( isa => 'Log::Dispatch', is => 'rw' );
### ...UNLESS an already-created LD object is passed in the 'logger' 
### parameter.  In which case that 'logger' object will just get assigned to 
### the 'log' parameter, and then this module will _not_ create its own.
has 'logger'    => ( isa => 'Log::Dispatch', is => 'rw' );

### That log nonsense above is for BC.  I want to start always passing the LD 
### object in here, but that's not what my current code is doing.  Eventually, 
### this module will require a logger object to be passed in.  At that point, 
### the name of the parameter accepting that passed LD object should change 
### from 'logger' to just 'log'.
###
### A GLCApp object created via GLContainer.pm will use that method of passing 
### an LD 'logger' object.
###
### bin/periodic_tasks.pl and dev/container_test.pl are now both doing the 
### right thing.

###########################################################################################

### Non arg attributes
has 'ute'       => ( isa => 'Games::Lacuna::Client::Util', lazy_build => 1, is => 'rw', );
has 'planets'   => (
    isa => 'HashRef', is => 'rw', lazy => 1, builder => '_get_my_planets',
    documentation => q/
        This contains _only_ planet name and id, NO planet objects.
        Indexed both {id => name} and {name => id}.
        If you want a hashref of just name => id or id => name that you can 
        iterate, see planets_names() and planets_ids().
        The IDs here are from the game, so my database's Planets.game_id, not 
        Planets.id.
    /,
);
has 'rpc_start' => (
    isa => 'Int', is => 'rw',
    documentation => 'Number of RPCs left today at object creation' ,
);
has 'rpc_last' => (
    isa => 'Int', is => 'rw',
    documentation => 'Number of RPCs left today since the last call to rpc_elapsed()' ,
);

### Private
sub BUILD {#{{{
    my( $self, $params ) = @_;

    ### JDB
    ### This conditional is eventually going to go away once I'm sure I've 
    ### cleaned up all remnants of the old version which passed log_screen and 
    ### log_file rather than a fully-formed LD object.
    if( $self->logger and ref $self->logger eq 'Log::Dispatch' ) {
        $self->log( $self->logger );
    }
    else {
        $self->set_logger();
    }

    my $rpcs = $self->rpc_count || 0;

    $self->rpc_start($rpcs);
    $self->rpc_last($rpcs);
}#}}}
sub _build_chi {#{{{
    my $self = shift;
    ### We're now allowing for this to be passed in as an arg.
    CHI->new( 
        driver     => 'RawMemory',
        expires_variance => 0.2,
        expires_in => '15 minutes',
        global     => 1,
        namespace  => __PACKAGE__,
    );
}#}}}
sub _build_ute {#{{{
    my $self = shift;

=head2 TBD

This originally used read_yaml from Util.pm.  However, the only version that 
gives over YAML::XS::LoadFile is the modification of datetime strings to 
DateTime objects.  Our main config file has none of those.

The enormous disadvantage to using read_yaml is that it lives in Util, which 
meant we had to have Util loaded to read the prefs file which here we were 
trying to use to load Util.  Circular logic no worky-worky because circular 
logic no worky-worky because (you get the idea).

=cut

    my $me = $self->users_schema->resultset('Login')->find({ username => $self->name });
    my $ute = Games::Lacuna::Client::Util->new( time_zone => $me->game_prefs->time_zone );
    $self->ute( $ute );
}#}}}

sub _get_my_planets {                       # 1 RPC {{{
    my $self    = shift;
    my $planets = {};

    my $emp = ($self->no_cache)
        ? $self->call( $self, 'empire')
        : $self->chi->compute( (join ':', ('empire', $self->{name}, 'object')), {}, sub{ $self->call( $self, 'empire') } );
    my $s = ($self->no_cache)
        ? $self->call($emp, 'get_status')
        : $self->chi->compute( (join ':', ('empire', $self->{name}, 'status')), {}, sub{ $self->call($emp, 'get_status') } );
    ($emp and $s) or return $planets;

    foreach my $id ( keys %{$s->{'empire'}{'planets'}} ) {
        my $name = $s->{'empire'}{'planets'}{$id};
        $planets->{$name} = $id;
        $planets->{$id} = $name;
    }
    $self->planets( $planets );
}#}}}

### Misc utes
sub call {#{{{
    my $self = shift;
    my( $obj, $meth, $args, $depth, $interactive ) = @_;
    (ref $args eq 'ARRAY') or $args = [];


=pod

Use this to make all remote calls.  If an RPC error is encountered, it will be 
handled if possible.  If the error cannot be handled gracefully, the error 
will be logged and this will croak.

Keep in mind that this module and its objects inherit from Games::Lacuna::Client, 
so if the object you need to call a method on is a client object, send your $lc 
object.  It may look a little unusual.

 my $planet = $client->body(id => $body_id);
becomes
 my $planet = $lc->call( $lc, 'body', [id => $body_id] );

 my $blgs = $planet->get_buildings();
becomes
 my $blgs = $lc->call( $planet, 'get_buildings' );

=cut

    $depth++;
    if( $depth > 3 ) {
        $self->log->log_and_croak(level => 'critical',
            message => "call() detected likely infinite recursion. Method $meth, Object " . (ref $obj) . ".",
        )
    }

    my $rv = try {
        return $obj->$meth(@$args);
    }
    catch {
        if( $self->caller_type eq 'web' ) {
            die Dumper $_;
        }
        given( $_ ) {#{{{
            my $err = $_;

            #$self->log->debug("GOT ERROR '$err' - attempting to deal with it.");

            ### Right now, the error (1011: Not enough resouces) has a bug on the 
            ### server; instead of returning the error string, it's returning a 
            ### dump of the Exception object as it exists on the server.  
            ### Actually, this may be a bug in G::L::C, not the server.  At this 
            ### point though, it doesn't matter where it's coming from.  In any 
            ### case, $err is a blessed hashref rather than a string.  I put a 
            ### full dump of the hashref in object_dumps.txt.
            if( ref $err ) {
                if( defined $err->{'message'} ) {
                    $err = $err->{'message'};
                }
                else {
                    $err = Dumper $err;
                }
            }

            if( $err !~ /\((\-?\d{4,5})\)/ ) {
                ### 'Proper' exceptions from the server have a four-digit error 
                ### code in parens.  If we didn't get that, what we got is an 
                ### actual 'error' rather than an exception.
                if( $err =~ /malformed JSON string/ ) {
                    ### Some postings about this online 
                    ### (http://community.lacunaexpanse.com/forums/support/random-malformed-json), 
                    ### along with the fact that I'm getting "Server closed 
                    ### connec..." make me think the remote server has just gotten 
                    ### sleepy.  Give it a few seconds and try again.
                    sleep 5;
                    if( my $rv = $self->call($obj, $meth, $args, $depth) ) {
                        $self->log->debug("'$meth' succeeded after bad json string and a nap.");
                        return $rv;
                    }
                }
                else {
                    $self->log->log_and_croak(level => 'emergency', message => "1 Encountered unexpected eval error: '$err'");
                }
            }

            when( /-32603/ ) { # Internal error
                ### I've started getting these 07/2012.  The entire error 
                ### message is just "Internal error", and they're not all 
                ### coming from the same point in my code.
                ### So the server has started deciding to take a shit in some 
                ### cases and this is what it returns.  I have no idea how to 
                ### fix the problem, because "Internal error" doesn't fucking 
                ### tell me anything useful.
                $self->log->debug("Got internal error; trying again if we're not too deep ($err)");
                sleep 61;
                if( my $rv = $self->call($obj, $meth, $args, $depth) ) {
                    $self->log->debug("'$meth' succeeded after a nap.");
                    return $rv;
                }
            }
            when( /1002/ ) { # Object does not exist
                ### Unknown ship type, Proposition not found
                $self->log->log_and_die(level => 'critical', message => "Object does not exist: ($err)");
            }
            when( /1004/ ) { # Password incorrect
                $self->log->log_and_die(level => 'critical', message => "Password Incorrect.");
            }
            when( /1010/ ) { # Insufficient privileges
                when( /Slow down/ ) {
                    if( $self->caller_type eq 'web' ) {
                        ### It shouldn't be possible for a web caller to get 
                        ### here.
                        $self->log->log_and_die(level => 'critical', message => "Used over 60 RPCs in a minute.");
                    }
                    $self->log->info("Used too many RPCs; sleeping for 1 minute");
                    sleep 61;
                    if( my $rv = $self->call($obj, $meth, $args, $depth) ) {
                        $self->log->debug("'$meth' succeeded after a nap.");
                        return $rv;
                    }
                }
                when( /You have already made the maximum number/ ) {
                    $self->log->critical( "User is out of RPCs for the day; cannot continue." );
                    return 0;
                }
            }
            when( /1011/ ) { # Not enough resources in storage
                when( /Not enough resources/ ) {
                    $self->log->log_and_die(level => 'notice', message => $err);
                }
            }
            when( /1013/ ) { # Missing Prerequisites
                when( /isn't complete/ ) {
                    $self->log->log_and_die( level => 'error', 
                        message => "Attempt to perform action on a building below level 1: $err");
                }
            }
            when( /1016/ ) { # Needs to solve a captcha
                $self->log->debug("Method '$meth' requires solving a captcha");
                $self->log->log_and_die( level => 'error', message => "Will not attempt captcha unless running in interactive mode.")
                    unless $interactive;
                unless( $self->check_captcha() ) {
                    $self->log->log_and_die(level => 'critical',
                        message => 'Attempt to solve captcha failed; cannot continue'
                    );
                }
                if( my $rv = $self->call($obj, $meth, $args, $depth) ) {
                    $self->log->debug("Method '$meth' succeeded after solving captcha.");
                    return $rv;
                }
            }
            default {
                $self->log->log_and_croak( level => 'critical', message => $err );
            }
        }#}}}
    };

    return $rv;
}#}}}
sub clear_cache {#{{{
    my $self = shift;
    $self->chi->clear() unless $self->no_cache;
}#}}}
sub check_captcha {#{{{
    my $self = shift;
    my $mech = shift;

=pod

Presents you with a captcha image.  If you solve it correctly, returns true, 
otherwise returns false.

 if( $lt->check_captcha() ) {
    say "Yay you solved the captcha";
 }
 else {
    die "I think you may not be human.";
 }


Optionally accepts a pre-made WWW::Mechanize object.  If you have one lying 
around, send it, otherwise don't worry; it'll be created for you.

 my $mech = WWW::Mechanize->new();
 $lt->check_captcha( $mech );

 ### Does exactly the same thing as above, but has the extra overhead of 
 ### having to create the mech object.
 $lt->check_captcha();


You must run this from the CLI.  If you try to run it through Gvim, the captcha 
won't work, but this sub will notice what you're doing and die with a reminder 
that yer doin it rong.

The captcha image itself pops up rather rudely, using whatever your default .png 
viewer on the system is.  You need to Alt-Tab or otherwise go back to the CLI 
window and enter the solution to the captcha there.

This is rather ugly, but it does clean up after itself.  And once a single 
captcha is solved, you are assumed to be sitting in front of the computer for 
the next 30 minutes, so your program is then free to do things like assign jobs 
to spies.

Although it certainly involves hitting the server, this does not use any RPC 
calls, succeed or fail.

=cut

    if( exists $ENV{'VIMRUNTIME'} ) {
        ### Can't display the image if we're running inside Vim's IDE.
        die "This program requires you solve a captcha, so you cannot run it from within Vim.";
    }

    unless( ref $mech eq 'WWW::Mechanize' ) {
        $mech = WWW::Mechanize->new();
    }
    my $captcha = $self->call($self, 'captcha');
    my $puzzle = $captcha->fetch();
    $mech->get($puzzle->{'url'});

    ### This method of displaying the captcha image is pretty hokey.  See 
    ### Browser::Open for a better way of going about it.

    my $dir = tempdir( CLEANUP => 1 );
    my $fn = "$dir/lacuna_captcha" . time . ".png";
    open my $f, '>', $fn or die $!;
    binmode $f;
    print $f $mech->content;
    close $f;

    $self->ute->display_image($fn);
    print "Enter the solution here: ";
    chomp( my $resp = <STDIN> );

    eval{ $self->call($captcha, 'solve', [$resp]) };
    if( $@ ) {
        my $err = $@;
        if($err =~ /1014/) { # Captcha not valid
            $self->log->critical("You entered '$resp'; this is incorrect.  Captcha test failed.");
        }
        else {
            $self->log_and_die("Captcha display yielded unexpected error '$err'.");
        }
    }
    return 1;
}#}}}
sub check_planet_arg {#{{{
    my $self = shift;
    my $planet = shift;

=pod

Given either the name or the ID of one of the planets in the current empire, 
returns both the name and the id.

Allows for methods that need planet info to be called with either identifier.

 ($name, $id) = $self->check_planet_arg('bmots');
 ($name, $id) = $self->check_planet_arg(157231);

...Either way, $name is 'bmots' and $id is '157231'.

=cut

    my($name, $id) = ($planet =~ /^\d+/)
        ? ( $self->planets->{$planet}, $planet )
        : ( $planet, $self->planets->{$planet} );
    unless($name and $id) {
        $self->log->log_and_croak(level => 'critical', message => "'$planet': no such planet.  Check spelling.");
    }
    return( $name, $id );
}#}}}
sub get_buildings {                         # 1 RPC {{{
    my $self = shift;
    my($planet_name, $planet_id) = $self->check_planet_arg( shift );
    my $building_type = shift;

$self->log->warning("You just called get_buildings on your client object; stop doing that!  It's deprecated.");

=pod


DEPRECATED.  Having this here is retarded.  Use the one in Planet.pm.



 $all_buildings = $lt->get_buildings($planet_id);
 $space_ports   = $lt->get_buildings($planet_id, 'Space Port');

Returns an arrayref containing a list of building objects matching your request.

If 'building_type' is sent, it's checked as an exact match (eq) against the 
building's "Human Readable Name" (the one you see when you mouse-over the 
building in the game client) and also as a ci (//i) match against the 
building's "internal" name.  eg the internal name for the "Hydrocarbon Energy 
Plant" is 'HydroCarbon'.

This allows you to request buildings with similar names:

 $trainers = $lt->get_buildings($planet_id, 'TrAiNiNg');
 $trainers = $lt->get_buildings($planet_id, 'training');

...Those two calls are identical; in each case $trainers contains all of the 
buildings with 'training' in their internal name; this will include all four 
types of spy training building.  It'll also contain the pilot training 
facility, so you do still need to check each building to make sure it's 
reasonable for what you need it for.

=cut

    my $body = ($self->no_cache)
        ? $self->call($self, 'body', [id => $planet_id]) 
        : $self->chi->compute( "body:$planet_id", {}, sub{ $self->call($self, 'body', [id => $planet_id]) } );
    my $buildings = ($self->no_cache)
        ? $self->call($body, 'get_buildings')->{'buildings'}
        : $self->chi->compute( "bldgs_hr:$planet_id", {}, sub{ $self->call($body, 'get_buildings')->{'buildings'} });
    ($body and $buildings) or return;

    my $bldg_objs = [];
    while( my($bldg_id,$hr) = each %$buildings ) {
        my $type_arg = substr $hr->{'url'}, 1;  # remove the slash from eg '/command' or '/spaceport'

        if( $building_type ) {
            ### Just list buildings of this type
            if( 
                   $hr->{'name'} eq $building_type
                or $hr->{'url'} =~ /$building_type/i
            ) {
                ### Save time and RPCs by only instantiating the objects 
                ### actually requested this call.
                #my $b = $self->call( $self, 'building', [id => $bldg_id, type => $type_arg] );
                my $b = $self->no_cache
                    ? $self->call($self, 'building', [id => $bldg_id, type => $type_arg])
                    : $self->chi->compute( "bldgs_obj:$planet_id:$bldg_id", {}, sub{ $self->call($self, 'building', [id => $bldg_id, type => $type_arg]) } );
                push @$bldg_objs, $b;
            }
        }
        else {
            ### List all buildings on this body
            my $b = $self->no_cache
                ? $self->call($self, 'building', [id => $bldg_id, type => $type_arg])
                : $self->chi->compute( "bldgs_obj:$planet_id:$bldg_id", {}, sub{ $self->call($self, 'building', [id => $bldg_id, type => $type_arg]) });
            push @$bldg_objs, $b;
        }
    }
    return $bldg_objs;

}#}}}
sub get_ships {                             # 1 RPC {{{
    my $self = shift;
    my( $space_port, $ship_type, $tasks ) = @_;

$self->log->warning("You just called get_ships on your client object; stop doing that!  It's deprecated.");

=pod


DEPRECATED - like get_buildings, having this here is stupid.  Use the one in Planet.pm.

First, get a space port object
 my $space_port = $self->get_buildings($body_id, 'Space Port')->[0];


Then, get all ships at that port
 my $all_ships = $self->get_ships($space_port);

Or, get all instances of a specific type of ship at that port.  (Case-insensitive)
 my $all_scows = $self->get_ships($space_port, 'scow');

Or, get a type of ship currently performing any of a list of tasks.  Valid 
tasks are Docked, Building, Mining, Travelling, and Defend.
 my $docked_scows = $self->get_ships($space_port, 'scow', ['Docked']);

That last one is likely the one you're going to want to use most often.


Example return structure
    {
        '5777334' => {
            'can_recall' => 0,
            'fleet_speed' => '0',
            'name' => 'Scow 8',
            'task' => 'Docked',
            'date_available' => '11 08 2011 17:54:29 +0000',
            'stealth' => '0',
            'combat' => '660',
            'max_occupants' => 0,
            'can_scuttle' => 1,
            'speed' => '480',
            'hold_size' => '45360',
            'payload' => [],
            'type' => 'scow',
            'id' => '5777334',
            'type_human' => 'Scow',
            'date_started' => '11 08 2011 17:11:33 +0000'
        },
        '12345' => {
            'id' => '12345',    # yeah I made that up.
            ... similar data to the Scow 8 above ...
        },
        ...
    };


The optional 'ship type' arg is the human-readable type, including spaces etc.  
It's case-INsensitive.

Returns a hashref with data on each matching ship.

=cut

    ### Make only one request for ships per planet, and request everything, 
    ### then cache it.  We'll filter that full resultset in Perl instead of 
    ### making the server do it for us.
    my $paging = {no_paging => 1};
    my $filter = {};
    my $sp_id  = $space_port->{'building_id'};
    my $ships  = $self->no_cache
        ? $self->call( $space_port, 'view_all_ships', [$paging, $filter])->{'ships'}
        : $self->chi->compute( "ships_hr:$sp_id", {}, sub{ $self->call( $space_port, 'view_all_ships', [$paging, $filter])->{'ships'} });


    my $ret_ships = {};
    SHIP:
    foreach my $s(@$ships) {
        ### $ships is a LoH  right now; I want my retval to be a hr keyed on 
        ### ship ID.
        if( ref $tasks eq 'ARRAY' and @$tasks ) {
            next SHIP unless( /$s->{'task'}/i ~~ $tasks );
        }

        next SHIP if( $ship_type and lc $s->{'type'} ne lc $ship_type );
        $ret_ships->{ $s->{'id'} } = $s;
    }
    return $ret_ships;
}#}}}
sub get_star_name {                         # 0 RPC {{{
    my $self = shift;
    my $planet_id = shift;

=pod

 my $star_name = $lt->get_star_name($planet_id);

Returns the name of a planet's star, as long as load_planets.pl was run when 
the star was probed (the star does not need to be probed right now).

$planet_id here must be the ID from the game server.  I store this as 
Planets.game_id, NOT Planets.id.

The star name is being pulled from the database, every time, so this never uses
any RPCs.

Many of the other methods allow the 'planet' arg to be either a planet name or 
a planet ID; that only works for planets in your own empire.  This method 
returns the star name of any planet (if known), not just planets in your empire.

The upshot here is that the first arg to this must be the planet's ID, never its 
name.

=cut
    my $planet = $self->schema->resultset('Planet')->find({ game_id => $planet_id });
    return $planet->star->name;
}#}}}
sub get_zones {#{{{
    my $self = shift;

=pod

Returns an arrayref containing all of the zone names in the game in the same 
format they're recorded in the database (eg "0|0").

Attempts (meagerly, at this point) to hand the zones back such that those 
closest to 0|0 show up higher in the list.  

TBD
A better zone-sorting algorithm would be much appreciated.  I simply don't 
understand well enough how the things are laid out right now.

 my $zones = $lt->get_zones;

=cut

    my $zones;
    for my $x( 0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5 ) {
        for my $y( 0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5 ) {
            push @$zones, "$x|$y";
        }
    }
    return $zones;
}#}}}
sub get_travel_time {#{{{
    my $self  = shift;
    my $from  = shift;
    my $to    = shift;
    my $speed = shift =~ s/\D//gr or die "Third arg 'speed': NaN";

=head2 get_travel_time

Given an origin, a target, and a ship speed, returns two L<DateTime::Duration> 
objects indicating 1) the amount of time to get from point A to point B at the 
given speed and 2) the amount of time represented by a single unit of speed at 
that distance.

 $origin = 'my_planet';
 $target = 'enemy_planet';
 ($dur, $diff) = $lt->get_travel_time( $origin, $target, $speed );

$target may now be either:
    - A string, the name of the planet (requires the destination be in the 
      Planets table, meaning it must have been probed)
    - A hashref, containing the keys 'x' and 'y', being the destination coords; 
      this does not require the destination to have been previously probed.

Your best bet is to use L<DateTime::Format::Duration> to view the returned data:

 my $formatter = DateTime::Format::Duration->new(
  normalize => 1,
  pattern => '%e days, %H hours, %M minutes, %S seconds'
 );

 say $formatter->format_duration($dur) . " from $origin to $target with a ship of speed $speed.";
 say "At this distance, each point of speed represents " . $formatter->format_duration($diff);

Both the $origin and $target args can be either planet names or IDs.  If 
either $origin or $target is not found in the Planets table, this will die. 

=cut

    my $origin =
           $self->schema->resultset('Planet')->find({ name => $from })
        || $self->schema->resultset('Planet')->find({ id   => $from })
        or die "No such body found: $from";

    my $target = {};
    if( ref $to eq 'HASH' ) {
        $target = $to;
    }
    else {
        my $t;
        $t = $self->schema->resultset('Planet')->find({ name => $to });
        if( not $t and $to =~ /^\d+$/ ) {
            $t = $self->schema->resultset('Planet')->find({ id => $to });
        }

        ### No reason the target has to be a body.  Doing this will let us get 
        ### travel times to un-probed stars.
        unless( $t ) {
            $t = $self->schema->resultset('Star')->find({ name => $to });
            if( not $t and $to =~ /^\d+$/ ) {
                $t = $self->schema->resultset('Star')->find({ id => $to });
            }
        }

        $t or die "No such body found.";

        ### The above is ugly, and the below is reasonably pretty.  However, 
        ### if we get an actual alphabetic name, but it doesn't happen to be 
        ### in our database, then the following will trigger searching the 
        ### 'id' column with that alpha value.  Which will cause DBIx::Class 
        ### to throw a warning (not an exception that we could catch).  
        ###
        ### I could make a local sig warn handler, but that's ugly too.  
        ###
        ### Anyway, the point is, don't get clever and try to "clean up" the 
        ### code above into the code below.

        #my $t =
        #    $self->schema->resultset('Planet')->find({ name => $to })
        #    || $self->schema->resultset('Planet')->find({ id => $to })
        #    or die "No such body found: $to";

        $target->{'x'} = $t->x;
        $target->{'y'} = $t->y;
    }
    
    my $distance = $self->ute->cartesian_distance( 
        $origin->x, $origin->y, $target->{'x'}, $target->{'y'}
    );

    ### 60 * 60 * 100 is 360_000
    ### $distance may well be a quite big float; don't attempt division on it 
    ### without BigFloat or you're likely to end up with NaN errors.
    my $secs = Math::BigFloat->new($distance);
    $secs->bdiv($speed);
    $secs->bmul(360_000);
    $secs = sprintf "%.0f", $secs;

    ### 60 * 60 * 100 is 360_000
    my $dur  = DateTime::Duration->new( seconds => $secs );
    my $dur2 = DateTime::Duration->new( seconds => $secs );
    ### I'm pretty sure that this $diff_per_speed_point is wrong and 
    ### misleading and should be ignored.
    my $diff_per_speed_point = $dur2 - $dur;

    return $dur, $diff_per_speed_point, $distance;
}#}}}
sub insert_or_update_body_schema {#{{{
    my $self = shift;
    my $body = shift;

=pod

 my $body = {
  name => 'foobar',
  orbit => 8,
  empire => {
   name => 'kiamo',
   id => 12,
  }
 };

 $lt->insert_or_update_body_schema( $body );

Inserts a new or updates an existing Planets record into our local database.  
Links the Planets record with the appropriate Empires record, which is also 
created if needed.

If that Empire is in an alliance, and no appropriate record exists in the 
Alliances table, that will be inserted as well.  If the alliance's name has 
changed, the new name will be updated, though no other changed alliance data
will be updated (eg a changed leader_id).

The $body hashref arg is recommended to be something that came from the game, 
eg you've pulled a star hashref with get_stars() and then pulled its orbiting 
bodies as hashrefs.

However, if you want to add a body manually, you can do that as well.

Returns 1 on success.

=cut

    $body->{'recorded'} //= $self->ute->iso_datestring;

    my $empire_id = undef;
    if( $body->{'empire'} ) {
        $empire_id = $self->no_cache
             ?  $self->insert_or_update_empire_schema({
                    id   => $body->{'empire'}{'id'} // undef,
                    name => $body->{'empire'}{'name'},
                })
             : $self->chi->compute( (join ':', ('empire_updates', $body->{'empire'}{'name'})), {},
                    sub {
                        $self->insert_or_update_empire_schema({
                            id   => $body->{'empire'}{'id'} // undef,
                            name => $body->{'empire'}{'name'},
                        })
                    }
                );

    }

    my $db_body;
    if( $db_body = $self->schema->resultset('Planet')->find({ game_id => $body->{'id'} }) ) {
        ### Try to get the existing local DB record with the same game ID as 
        ### our input.
        ###
        ### Now, the coords we're about to record may not be the coords we've 
        ### got in the DB if the planet has been moved with a BHG.  In which 
        ### case we're going to record new x,y coords for this planet.
        ###
        ### HOWEVER, there's likely already a planet with those coords listed 
        ### in our database, and there's a compound constraint on (x,y) 
        ### coords, so updating the planet to these new (correct) coords will 
        ### fail.
        ###
        ### What we'll do is simply delete the other planet record with these 
        ### same coords.  If that planet's new location is within range of our 
        ### observatories, it'll get recorded later in this same session 
        ### anyway.
        if( my $body_in_the_way = $self->schema->resultset('Planet')->find(
            { x => $body->{'x'}, y => $body->{'y'} }, { key => 'coords' }
        )) {
            if( $body_in_the_way->game_id != $db_body->game_id ) {
                say "Deleting body from ($body->{'x'}, $body->{'y'}), which is in the way.";
                $body_in_the_way->delete;
            }
        }
    }
    else {
        ### ...if that fails, it's still possible to have a body at these 
        ### coords - either we never recorded its game ID or somebody moved it 
        ### with a BHG.  So find_or_create(), not just create().
        $db_body = $self->schema->resultset('Planet')->find_or_create(
            { x => $body->{'x'}, y => $body->{'y'}, name => $body->{'name'} },
            { key => 'coords' },
        );
    }

    $body->{'game_id'} = $body->{'id'};
    delete $body->{'id'};

    $self->log->debug("Updating record for body $body->{'name'}.");
    foreach my $column( qw(name game_id star_id recorded zone x y image orbit size type current water) ) {
        $db_body->$column( $body->{$column} );
    }
    foreach my $o( $self->ute->ore_types ) {
        $db_body->$o( $body->{'ore'}{$o} );
    }
    $db_body->empire_id($empire_id) if $empire_id;
    $db_body->update;

    return 1;
}#}}}
sub insert_or_update_empire_schema {#{{{
    my $self   = shift;
    my $emp_hr = shift;

=pod

Given a hashref containing at least an empire name, this pulls the full data 
on the empire from the server and adds or updates that record locally.

If the given empire is a member of an alliance, the alliance ID and current 
name will be part of the empire data returned from the server.  This information 
ONLY will be used to create/update an Alliances record.  So the ID and name 
will be current and correct, but other data (eg leader_id) will not be updated.

The hashref passed in /can/ contain just the empire name, but if you have the
empire ID as well, it should also be passed to save RPCs.

If that empire cannot be found on the server, returns undef.

Returns the empire ID.

 my $emp_hr = {
    name => 'tmtowtdi',
    id   => '23598',
 };

 # or, but not preferred...
 my $emp_hr = {
    name => 'tmtowtdi',
 };

 my $emp_id = $lt->insert_or_update_empire_schema($emp_hr);

 # Whichever $emp_hr you used:
 say $emp_id; # 23598

=cut

    if( not defined $emp_hr->{'name'} ) {
        $self->log->log_and_die(level => 'error', message => 'Name required by insert_or_update_empire_schema()');
    }

    my $empobj = $self->call($self, 'empire');
    if( not defined $emp_hr->{'id'} ) {
        my $temp_hr = $self->call($empobj, 'find', [$emp_hr->{'name'}]);
        $emp_hr->{'id'} = $temp_hr->{'empires'}[0]{'id'};
    }
    my $profile = $self->call($empobj, 'view_public_profile', [$emp_hr->{'id'}])->{'profile'};

    $self->log->debug("Updating record for empire $emp_hr->{'name'}.");
    my $db_empire = $self->schema->resultset('Empire')->find_or_create({
        id   => $emp_hr->{'id'},
        name => "$emp_hr->{'name'}", 
    });
    foreach my $key(qw(country status_message species description player_name city skype)) {
        $db_empire->$key( $profile->{$key} );
    }
    foreach my $key(qw(last_login date_founded)) {
        $db_empire->$key( $self->ute->game_strptime->parse_datetime($profile->{$key}) );
    }

    my $alliance_id = undef;
    if( 
            defined $profile->{'alliance'}
    ) {
        $alliance_id = $self->no_cache
            ? do {
                    $self->log->debug("Updating record for alliance $profile->{'alliance'}{'name'}.");
                    my $db_alliance = $self->schema->resultset('Alliance')->find_or_create({
                        id => $profile->{'alliance'}{'id'}
                    });
                    $db_alliance->name($profile->{'alliance'}{'name'});
                    $db_alliance->update;
                    $db_alliance->id;
                }
            :  $self->chi->compute( (join ':', ('alliance_updates', $profile->{'alliance'}{'name'})), {},
                    sub {
                        $self->log->debug("Updating record for alliance $profile->{'alliance'}{'name'}.");
                        my $db_alliance = $self->schema->resultset('Alliance')->find_or_create({
                            id => $profile->{'alliance'}{'id'}
                        });
                        $db_alliance->name($profile->{'alliance'}{'name'});
                        $db_alliance->update;
                        $db_alliance->id;
                    }
                )
    }

    ### The AI 'alliances' don't actually exist in-game, so if we encountered 
    ### any AI empires we just unset their alliances -- accurate per the game, 
    ### but not per my setup.  So reset those AI alliance IDs.
    $alliance_id = $db_empire->id if $db_empire->id < 0;

    $db_empire->alliance_id( $alliance_id );
    $db_empire->update;
    return $db_empire->id;
}#}}}
sub ping {#{{{
    return 'pong';
}#}}}
sub planet_available_excavators {           # 2 RPC per planet in empire#{{{
    my $self   = shift;
    my $planet = shift;

$self->log->critical("This method should be totally dead");

    ### Allow us to be called with either the name or the ID as the first arg.
    my($planet_name, $planet_id) = ($planet =~ /^\d+$/)
        ? ($self->planets->{$planet}, $planet)
        : ($planet, $self->planets->{$planet});
=pod

Returns a hashref of available (Docked) excavators for $planet.  The hashref is 
of the format:

 $rv = { 
  12345 => {
   space_port => Object for space port ID 12345,
   excavators => {
    98765 => {
       name => 'some excavator name',
       id => 98765,
       ...
    },
    98764 => {
       name => 'some other excavator name',
       id => 98764,
       ...
    },
   }
  },
  12346 => {
   space_port => Object for space port ID 12346,
   excavators => {
    ...more or less the same as above
   },
  },
 }

Returning the Space Port object as well as the excavators will save us from 
having to re-create those space port objects later.

Example of a full excavator hashref:

 '9295572' => {
  'can_recall' => 0,
  'fleet_speed' => '0',
  'name' => 'Excavator 13',
  'task' => 'Building',
  'date_available' => '29 09 2011 21:40:03 +0000',
  'stealth' => '0',
  'combat' => '0',
  'max_occupants' => 0,
  'can_scuttle' => 0,
  'speed' => '3060',
  'hold_size' => '0',
  'payload' => [],
  'type' => 'excavator',
  'id' => '9295572',
  'type_human' => 'Excavator',
  'date_started' => '29 09 2011 17:06:44 +0000'
 }

=cut

    my $rv = {};
    my $sp = $self->get_buildings($planet_name, 'Space Port')->[0] or return $rv;;
    unless(ref $sp eq 'Games::Lacuna::Client::Buildings::SpacePort') {
        $self->log->error("Got non-SpacePorty Space Port: $sp");
        return 0;
    }
    $rv->{ $sp->{'building_id'} }{'space_port'} = $sp;
    my $docked_excavators = $self->get_ships($sp, 'excavator', ['Docked']);
    while(my($id, $hr) = each %$docked_excavators) {
        $rv->{ $sp->{'building_id'} }{'excavators'}{$id} = $hr;
    }
    return $rv;
}#}}}
sub planets_ids {#{{{
    my $self = shift;    

=pod

Returns a hashref of your empire's planets with only the ids as the keys.  
Simply filters the name keys out of $self->planets.


DO NOT ATTEMPT TO ITERATE THROUGH THIS:

 while(my($id,$name) = each(%{$self->planets_ids})) {
    ...
 }

This is a subroutine; doing that will call this sub and dereference the retval, 
then just do that again, turning the block above into an infinite loop.  
Instead, call this once and iterate through its retval:

 my $ids = $self->planets_ids;
 while(my($id,$name) = each(%{$ids})) {
    ...
 }

=cut

    my $ret = {};
    my %planets = %{$self->planets};
    PLANET:
    while( my($n,$v) = each %planets ) {
        next PLANET unless $n =~ /^\d+$/;
        $ret->{$n} = $v;
    }
    return $ret;
}#}}}
sub planets_names {#{{{
    my $self = shift;    

=pod

Returns a hashref of your empire's planets with only the names as the keys.  
Simply filters the ID keys out of $self->planets.

=cut

    my $ret = {};
    PLANET:
    while(my($n,$v) = each(%{$self->planets})) {
        next PLANET if $n =~ /^\d+$/;
        $ret->{$n} = $v;
    }
    return $ret;
}#}}}
sub record_map_square {                     # 1 RPC {{{
    my $self = shift;
    my($x1, $y1, $x2, $y2) = @_;

=pod


Pulls data from a box on the starmap.  The square is defined by ($x1, $y1) as 
the upper left corner and ($x2, $y2) as the lower right corner of the box.

If you want to target a single specific star, you can simply send that star's
coords as both pairs:

 my $rv = $lt->record_map_square(
  -175, 163,    # Glee Atiogg
  -175, 163,    # Glee Atiogg
 );

Maximum size for the box (limited by the game, not by this module) is 900 
units, so a 30x30 square would be common, but you could grab a 10x90 rectangle 
if you wanted.

Every star in the requested area that has been probed by either you or another 
member of your alliance will cause records to be created and updated for every 
body orbiting that star.  This includes entries for any inhabiting empires and 
any alliances of which they may be members.

=cut

    my $map   = $self->call($self, 'map');
    my $stars = $self->call($map, 'get_stars', [ $x1, $y1, $x2, $y2 ])->{'stars'};

    unless( scalar @$stars ) { 
        $self->log->log_and_croak(level => 'debug', 
            message => q{No stars found in your box; we're likely off the map.} );
    }

    my $cnt = 0;
    STAR:
    foreach my $star(@$stars) {
        $self->log->debug("STAR $star->{'name'}");
        unless(defined $star->{'bodies'}) {
            $self->log->debug("$star->{'name'} does not have known orbiting bodies.");
            next STAR;
        }
        $self->log->debug("$star->{'name'} has known orbiting bodies.");

        BODY:
        foreach my $body(@{$star->{'bodies'}}) {
            $self->log->debug("$body->{'name'}");
            $body->{'current'} = 1;
            if($self->insert_or_update_body_schema($body)) {
                $self->log->debug("Record updated for body '$body->{'name'}'.");
                $cnt++;
            }
            else {
                $self->log->error("Record update FAILED for body '$body->{'name'}'.");
            }
        }
    }

    return $cnt;
}#}}}
sub rpc_count {#{{{
    my $self = shift;    

=pod

Returns the integer number of RPCs your empire has used today (max 10_000).

This call, itself, uses 1 RPC.

=cut

    my $emp_key  = join ':', ('empire', $self->{name}, 'object');
    my $stat_key = join ':', ('empire', $self->{name}, 'status');

    my $emp = $self->no_cache
        ? $self->call($self, 'empire')
        : $self->chi->compute( $emp_key, {}, sub{ $self->call($self, 'empire') });
    $emp or return;

    ### Don't use cached status here, or we'll end up with identical RPC 
    ### counts.  But since we've got the status, we can add it to the cache 
    ### for anything else that wants it.
    my $s = $self->call($emp, 'get_status');
    unless( $self->no_cache ) {
        $self->chi->set($stat_key, $s);
    }

    return $s->{empire}{rpc_count};
}#}}}
sub rpc_elapsed {#{{{
    my $self        = shift;    
    my $incremental = shift or 0;

=pod

Returns RPCs used by the current GLCT object, either incremental or full.  By 
default it returns the full number used since object creation.  If a single true 
argument is sent, only the count of RPCs since the last call to rpc_elapsed will 
be returned.

Note that "the full number used since object creation" means the number of RPCs
used /by your account/, not necessarily by this object.

ie if you have the web client open in your browser and perform several actions 
there at the same time you have a script running, the script's rpc_elapsed() 
count will include the RPCs used by your actions in the browser.


Keep in mind that this call itself uses an RPC and that used RPC will be 
included in the count returned.  If you want to display the number of RPCs used 
by a specific method, remember to subtract 1 from the integer returned by this:

 say $lt->rpc_count;    # 10 (for eg)

 $lt->method_that_uses_one_rpc();
 say $lt->rpc_elapsed(1) . " RPCs used";    # 2

 $lt->method_that_uses_one_rpc();
 say $lt->rpc_elapsed(1) . " RPCs used";    # 2

 say $lt->rpc_elapsed . " RPCs used";       # 15 (10 + 2 + 2 + 1)


 $lt->rpc_elapsed();    # called to set a checkpoint
 $lt->some_method();
 say "some_method used exactly " $lt->rpc_elapsed(1) - 1 . " RPCs";

=cut

    my $current = $self->rpc_count;
    my $prev    = ($incremental) ? $self->rpc_last : $self->rpc_start;
    
    ### If $prev is greater than $current, we've had an RPC reset during this 
    ### run.
    my $rv = ( $prev > $current ) ? 10_000 - $prev + $current : $current - $prev;

    $self->rpc_last( $current );
    return $rv;
}#}}}
sub set_logger {#{{{
    my( $self, $args ) = @_;
    my $me = $self->users_schema->resultset('Login')->find({ username => $self->name });


    ### DEPRECATED
    ###
    ### After this creates its log object, it immediately warns that it's been 
    ### called.


=pod

Creates and returns a general Log::Dispatch logger object that can be used by 
anything that wants a logging facility.

This is called automatically when you create you GLCT object; you never need 
to explicitly call this method.  However, you're welcome to call it any time 
you wish to modify the logger's settings.

Log to a file
 $lt->log_file('/path/to/my/logfile.log');
 $lt->set_logger();

Log just to the screen, turn off file logging.
 $lt->log_file('');
 $lt->log_screen(1);
 $lt->set_logger();


Change the file's minimum logging level down to 'debug'
 $lt->set_logger({ file_min_level => 'debug' });

Change the screens's minimum logging level up to 'info' - this can be quite 
useful, as the default screen level is 'debug' and I can be a little heavy-
handed with the debug-level logging events sometimes.
 $lt->set_logger({ screen_min_level => 'info' });

By default, the file's log level will be set at 'info', and the screen's log 
level will be set to 'debug'.


Calling this with no outputs defined will not produce an error.  It will produce 
a Log::Dispatch object with NO OUTPUT STREAMS DEFINED.  This means that any 
logging you do will simply be tossed into /dev/null.

 $lt->log_file('');
 $lt->log_file(0);
 $lt->set_logger();
 $lt->log->emergency("Computer on fire!");   # nobody will ever see this.


Available logging levels in order:
 debug
 info
 notice
 warning
 error
 critical
 alert
 emergency

=cut

    my $file_output = [ 'FileRotate',
                            name      => 'file',
                            binmode   => $args->{'binmode'}        // ':utf8',
                            min_level => $args->{'file_min_level'} // 'info',
                            filename  => $self->log_file           // q{},
                            newline   => 1,
                            size      => 1 * 512 * 1024,  # 512k
                            max       => 3,               # no. of old files to keep
                            mode      => 'append',
                            callbacks => sub{ my %h = @_; 
                                return sprintf "[%s] - %s - %s", DateTime->now( time_zone => $me->game_prefs->time_zone ), uc $h{'level'}, $h{'message'}; 
                            }
                        ];
    my $screen_output = [ 'Screen', 
                            name      => 'screen',
                            newline   => 1,
                            min_level => $args->{'screen_min_level'} // 'debug',
                            callbacks => sub{ my %h = @_; return sprintf "%s: %s", uc $h{'level'}, $h{'message'}; }
                        ];
    ### Inserts all notice and higher level events to Users.ScheduleLog
    ### New users won't have empire_name or time_zone set yet.
    my $dbi_output;
    if( $me->game_prefs->empire_name and $me->game_prefs->time_zone ) {
        $dbi_output = [ 'LacunaSchedulerDBI', 
                            name        => 'dbi',
                            dbh         => $self->users_schema->storage->dbh,     # works
                            table       => 'ScheduleLog',
                            min_level   => 'notice',
                            empire      => ($me->game_prefs->empire_name),
                            time_zone   => ($me->game_prefs->time_zone || 'UTC'),
                            callbacks   => sub{ my %h = @_; return sprintf "%s", $h{'message'}; }
                        ];
    }

    my %output_opts = ();
    if( $self->log_file ) {
        if( -w $self->log_file and not -d _ ) {
            ### -w implies -e
            push @{ $output_opts{'outputs'} }, $file_output;
        }
        elsif( not -e $self->log_file ) {
            ### touch it if it doesn't exist already
            open my $fh, '>', $self->log_file or die $!;
            close $fh;
            push @{ $output_opts{'outputs'} }, $file_output;
        }
        else {
            ### It's a directory, the path is wrong, whatever.
            die "Unable to use log file ${\$self->log_file} - check paths and spelling.";
        }
    }
    if( $self->log_screen ) {
        push @{ $output_opts{'outputs'} }, $screen_output;
    }

    push @{ $output_opts{'outputs'} }, $dbi_output if $dbi_output;

    $self->log( Log::Dispatch->new( %output_opts ) );
    $self->log->warn("set_logger called!");
}#}}}
sub star_for_planet {#{{{
    my $self   = shift;
    my $planet = shift;

    ### Allow us to be called with either the name or the ID as the first arg.
    my($planet_name, $planet_id) = ($planet =~ /^\d+$/)
        ? ($self->planets->{$planet}, $planet)
        : ($planet, $self->planets->{$planet});

=pod

Given a planet name or ID, returns the ID of that planet's star.

Requires an exhaustive Stars table.  Also requires the requested planet exist 
in the Planets table.

If the planet or star cannot be found, returns undef.

=cut

    my $rec =
           $self->schema->resultset('Planet')->find({ name => $planet })
        || $self->schema->resultset('Planet')->find({ id   => $planet })
        or die "No such planet found: $planet";
    return $rec->star->id;
}#}}}
sub star_distance {#{{{
    my $self = shift;
    my($ident1, $ident2) = @_;

=pod

Returns the cartesian distance between two stars, given either the name or ID of
each.  

 say $lt->star_distance('Waessuj', 'Xa Bogi');    # 63.6003144646314

Note this does _not_ work for arbitrary bodies, just stars.

=cut

    my $star1 =
           $self->schema->resultset('Star')->find({ name => $ident1 })
        || $self->schema->resultset('Star')->find({ id   => $ident1 })
        or die "No such star found: $ident1";
    my $star2 =
           $self->schema->resultset('Star')->find({ name => $ident2 })
        || $self->schema->resultset('Star')->find({ id   => $ident2 })
        or die "No such star found: $ident2";

    unless( defined $star1->x and defined $star1->y ) {
        $self->log->log_and_croak( level => 'critical', message => "Can't find x,y coords for $ident1" );
    }
    unless( defined $star2->x and defined $star2->y ) {
        $self->log->log_and_croak( level => 'critical', message => "Can't find x,y coords for $ident2" );
    }

    return $self->ute->cartesian_distance( $star1->x, $star1->y, $star2->x, $star2->y );
}#}}}
sub update_excavator_log {#{{{
    my $self     = shift;
    my $body     = shift;
    my $timespec = shift;

    my $me   = $self->users_schema->resultset('Login')->find({ username => $self->name });

=pod

Records in the log the fact that an excavator has just been sent to a remote 
body.

 $recordset = $lt->update_excavator_log( $body_record [,$timespec] );

$body_record must be a L<Games::Lacuna::Schema::Result::Planet>.
my Empires table)

If you which to specify the date and time the excavator was sent, you may pass 
$timespec as epoch seconds (no other format is allowed).  This is generally 
unnecessary; leaving $timespec out results in the log being updated with the 
current time.

=cut

    ### TBD
    ### $self->name is the name you logged in with (from client.yml).  AFAIK 
    ### that name _must_ be the name of your empire, which is convenient.  
    ### However, if it's possible to rename your empire without changing your 
    ### login name or vice-versa, this will cause problems.  Where "cause 
    ### problems" means "it won't work".
    my $sending_empire = $self->schema->resultset('Empire')->find({ name => $self->name });

    my $iso = ($timespec)
        ? $self->ute->iso_datestring( DateTime->from_epoch( epoch => $timespec->{'epoch'}), time_zone => $me->game_prefs->time_zone || 'America/New_York' )
        : $self->ute->iso_datestring();

    my $excav = $self->schema->resultset('ExcavatorLog')->update_or_create(
        {
            date        => $iso,
            empire_id   => $sending_empire->id,
            to_x        => $body->x,
            to_y        => $body->y,
        },
        { key => 'coords' }
    );
    return $excav;
}#}}}

__PACKAGE__->meta->make_immutable;

1;

