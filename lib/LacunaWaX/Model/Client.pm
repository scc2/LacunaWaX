
=head1 NAME 

LacunaWaX::Model::Client - Game server client

=head1 SYNOPSIS

 my $game_client = LacunaWaX::Model::Client->new (
  app         => C<LacunaWaX object>,
  bb          => C<LacunaWaX::Model::Container object>,
  wxbb        => C<LacunaWaX::Model::WxContainer object>,
  server_id   => C<Integer ID (in local Servers table) of server to connect to>
  allow_sleep => 0,
 );

 if( $game_client->ping ) {
  ...connected OK...
 }
 else {
  ...connected NOK...
 }

=head1 DESCRIPTION

Does not technically extend Games::Lacuna::Client, but uses AUTOLOAD to allow 
treating objects of this class as GLC objects.

So to get a GLC map object, instead of having to do

 $game_client->client->map()

Which just feels hackneyed, you can skip the separate call to client:

 $game_client->map()

=head1 CONSTRUCTION

The user's default empire name and password are saved in the database, so those 
creds do not generally need to be sent.

Database connection is passed in the LacunaWaX::Model::Container (bb attribute), and 
the integer server_id allows Client to find the actual game connection creds.

If you need to create a client using credentials other than what are stored as 
the current LacunaWaX user's default creds, you may also pass empire_name and 
empire_pass:

 my $other_client = LacunaWaX::Model::Client->new (
  app         => C<LacunaWaX object>,
  bb          => C<LacunaWaX::Model::Container object>,
  wxbb        => C<LacunaWaX::Model::WxContainer object>,
  server_id   => C<ID of server>
  allow_sleep => 0,

  empire_name => 'some other empire',
  empire_pass => 'some other pass',
 );

=head1 PASSABLE ATTRIBUTES

=head2 app (Required)

A LacunaWaX object

=head2 bb (Required)

A LacunaWaX::Model::Container object

=head2 server_id (Required)

The integer ID of the server, in the local Servers table, to which to connect.  
This must currently be either 1 (US1) or 2 (PT).

=head2 wxbb

A LacunaWaX::Model::WxContainer object

Contains services pertaining to the GUI.  Clients that should not attempt to 
interact with the GUI (such as clients created during a scheduled task) should 
not include a wxbb upon construction.

=head2 allow_sleep

Defaults to false.  If true, the client will sleep for 61 seconds after 
receiving the "More than 60 RPCs used per minute" error from the server.  This 
should generally I<only> be used by non-GUI clients.

=head2 rpc_sleep

Integer number of seconds to pause between each request passed to the game 
server to avoid soaking up the 60 allowed RPCs per minute.  Defaults to 0, but a 
value of at least 1 is encouraged.  Scheduled tasks should probably use a value 
of 2 or 3.

=head1 PROVIDED ATTRIBUTES

=head2 server_rec, account_rec

The Servers and ServerAccounts table records representing the current LacunaWaX 
user.

Note that these will continue to represent the I<current LacunaWaX user> even if 
another user's empire_name and empire_pass are being used.

=head2 url, protocol, empire_name, empire_pass

Connection information pertaining to the current client.

=head2 client

This is the actual Games::Lacuna::Client object.  You shouldn't ever need to 
touch this.

=head2 ore_types, glyph_types

Alphabetically-sorted arrayref of all possible types of ore in the game.  The 
two methods are identical; both are provided as convenience.  The types are 
returned as lower-cased strings.

This list is hard-coded, but since it's exhaustive, it's not likely to change.

=head2 warships

Alphabetically-sorted arrayref of all warships in the game.  The names are those 
recognized by the game, not the human-readable names (so 'placebo4', not 
'Placebo IV').

This list is hard-coded, and I<not> exhaustive.  I listed the ships that I think 
look like "war" ships.

=head2 glyph_recipes

HoA keyed off the final product name:

 'Interdimensional Rift' => [qw(methane zircon fluorite)],
 'Kalavian Ruins'        => [qw(galena gold)],
 'Library of Jith'       => [qw(anthracite bauxite beryl chalcopyrite)],
 ...

=head2 planets

Hashref of the current empire's planets: C<name =E<gt> ID>

=head1 METHODS

=head2 EXCEPTIONAL METHODS

Many of the methods need to hit the game server, and as such, might encounter 
various server errors.  These methods will all throw exceptions in that case, 
and should therefore have their calls wrapped in try/catch blocks.

All methods whose name begins with C<get_>, along with the C<cook_glyphs> and 
C<rearrange> methods fall into this category, as well as any methods that are 
actually Games::Lacuna::Client methods.

=cut

package LacunaWaX::Model::Client {
    use v5.14;
    use Carp;
    use Data::Dumper;   # used for actual output, not just debugging.  Don't remove.
    use DateTime;
    use Games::Lacuna::Client;
    use List::Util qw(first);
    use Math::BigFloat;
    use Moose;
    use Try::Tiny;

    use LacunaWaX::Model::Client::Spy;

    our $AUTOLOAD;

    has 'app'           => (is => 'rw', isa => 'LacunaWaX',                     weak_ref => 1   ); 
    has 'bb'            => (is => 'rw', isa => 'LacunaWaX::Model::Container',   required => 1   );
    has 'server_id'     => (is => 'rw', isa => 'Int',                           required => 1   );

    has 'wxbb' => (is => 'rw', isa => 'LacunaWaX::Model::WxContainer',
        documentation => q{
            This should be passed in on construction if you've got one, meaning that you're creating 
            this client in the context of a GUI app.
            If this client is being created by a non-GUI, eg one of the scheduled tools, this will 
            be undef.
        }
    );

    has 'empire_status'   => (is => 'rw', isa => 'HashRef');

    has 'allow_sleep'   => (is => 'rw', isa => 'Int', lazy => 1,  default => 0,
        trigger => \&_change_allow_sleep,
        documentation => q{
            If set true, when the server returns a "over RPC limit" error, the 
            call that produced that error will sleep 61 seconds and then try 
            itself again, up to three times (at which point some sort of 
            recursion error is assumed, and death occurs).

            Meant to be sent on batch/scheduled/non-interactive clients.

            When this is false, the "over RPC limit" error will be returned like 
            any other server error that the caller must deal with.

        }
    );
    has 'rpc_sleep'   => (is => 'rw', isa => 'Int', lazy => 1, default => 0,
        trigger => \&_change_rpc_sleep,
        documentation => q{
            This is the number of seconds to sleep after every request, to avoid 
            the "over RPC limit" error.
        }
    );
    has 'debug' => (is => 'rw', isa => 'Int', lazy => 1, default => 0,
        documentation => q{
            Turn this on to spit out some debugging messages to STDOUT.  Mainly 
            for testing how we respond to server errors.
            Much less useful now than it used to be, since a Dialog::Status can be 
            more conveniently used for debugging.
        }
    );

    has 'server_rec'  => (is => 'rw', isa => 'LacunaWaX::Model::Schema::Servers',          lazy_build => 1 );
    has 'account_rec' => (is => 'rw', isa => 'LacunaWaX::Model::Schema::ServerAccounts',   lazy_build => 1, clearer => 'clear_account_rec' );

    has 'url'           => (is => 'rw', isa => 'Str',                   lazy_build => 1 );
    has 'protocol'      => (is => 'rw', isa => 'Str',                   lazy_build => 1 );
    has 'empire_name'   => (is => 'rw', isa => 'Str',                   lazy_build => 1 );
    has 'empire_pass'   => (is => 'rw', isa => 'Str',                   lazy_build => 1 );
    has 'client'        => (is => 'rw', isa => 'Games::Lacuna::Client', lazy_build => 1 );
    has 'pingtime'      => (is => 'rw', isa => 'DateTime'                               );
    has 'ore_types'     => (is => 'rw', isa => 'ArrayRef',              lazy_build => 1 );
    has 'glyphs'        => (is => 'rw', isa => 'ArrayRef[Str]',         lazy_build => 1 );
    has 'warships'      => (is => 'rw', isa => 'ArrayRef[Str]',         lazy_build => 1 );
    has 'glyph_recipes' => (is => 'rw', isa => 'HashRef',               lazy_build => 1 );

    has 'planets' => ( is => 'rw', isa => 'HashRef', lazy => 1, default => sub {{}},
        documentation => q{ name => id },
    );

    has 'sitter_clients' => ( is => 'rw', isa => 'HashRef', lazy => 1, default => sub {{}},
        documentation => q{
            name => client
            Clients created for accounts we have recorded in the SitterManager get stashed 
            here upon creation so they don't have to be re-created each time.
        },
    );

    sub BUILD {
        my $self = shift;
        return $self;
    }
    sub AUTOLOAD {## no critic qw(RequireArgUnpacking ProhibitAutoloading) {{{
        my $self = shift;
        my @args = @_;

        ### This is meant as a convenience.  Calls to the game server client 
        ### that occur from within this module _are_ explicitly calling 
        ### $self->client - no need to pass through autoload if we know damn 
        ### well that's what we're going to be doing.

        ### So a call to
        ###     $self->app->game_client->flurble
        ### results in
        ###     $meth       == 'flurble';
        ###     $AUTOLOAD   == 'LacunaWaX::Model::Client::flurble'
        my $meth = $AUTOLOAD =~ s/.*?([^:]+)$/$1/r;

        ### No try block; up to the caller to manage that.
        my $rv = $self->client->$meth(@args);
        return $rv;
    }#}}}

    sub _build_account_rec {#{{{
        my $self = shift;

        my $schema = $self->bb->resolve( service => '/Database/schema' );
        my $rec = $schema->resultset('ServerAccounts')->search({
            server_id           => $self->server_id,
            default_for_server  => '1'
        })->single or croak "Could not find default account for server " . $self->server_rec->name;

        ### The user may have switched up his password from sitter to full and 
        ### attempted to reconnect.
        ### In that case, account_rec has been cleared, so this builder will be 
        ### re-called, but the whole client still exists, and its builder will 
        ### not be re-called.
        ### So reset the info on the current client.
        $self->empire_name($rec->username);
        $self->empire_pass($rec->password);

        return $rec;
    }#}}}
    sub _build_client {#{{{
        my $self = shift;

        my $c = Games::Lacuna::Client->new(
            uri         => $self->protocol . '://' . $self->url,
            allow_sleep => $self->allow_sleep,
            rpc_sleep   => $self->rpc_sleep,
            name        => $self->empire_name, 
            password    => $self->empire_pass,
            api_key     => '02484d96-804d-43e9-a6c4-e8e80f239573',
        );

        return $c;
    }#}}}
    sub _build_empire_name {#{{{
        my $self = shift;
        return $self->account_rec->username;
    }#}}}
    sub _build_empire_pass {#{{{
        my $self = shift;
        return $self->account_rec->password;
    }#}}}
    sub _build_glyphs {#{{{
        my $self = shift;
        return $self->_build_ore_types;
    }#}}}
    sub _build_glyph_recipes {#{{{
        my $self = shift;
        return {
            'Halls of Vrbansk (all)'        => [qw(various)],                           # Not a real recipe!
            'Halls of Vrbansk (1)'          => [qw(goethite halite gypsum trona)],
            'Halls of Vrbansk (2)'          => [qw(gold anthracite uraninite bauxite)],
            'Halls of Vrbansk (3)'          => [qw(kerogen methane sulfur zircon)],
            'Halls of Vrbansk (4)'          => [qw(monazite fluorite beryl magnetite)],
            'Halls of Vrbansk (5)'          => [qw(rutile chromite chalcopyrite galena)],
            'Black Hole Generator'          => [qw(kerogen beryl anthracite monazite)],
            'Citadel of Knope'              => [qw(beryl sulfur monazite galena)],
            'Crashed Ship Site'             => [qw(monazite trona gold bauxite)],
            'Gas Giant Settlement Platform' => [qw(sulfur methane galena anthracite)],
            q{Gratch's Gauntlet}            => [qw(chromite bauxite gold kerogen)],
            'Interdimensional Rift'         => [qw(methane zircon fluorite)],
            'Kalavian Ruins'                => [qw(galena gold)],
            'Library of Jith'               => [qw(anthracite bauxite beryl chalcopyrite)],
            'Oracle of Anid'                => [qw(gold uraninite bauxite goethite)],
            'Pantheon of Hagness'           => [qw(gypsum trona beryl anthracite)],
            'Temple of the Drajilites'      => [qw(kerogen rutile chromite chalcopyrite)],
            'Terraforming Platform'         => [qw(gypsum sulfur monazite)],
        };
    }#}}}
    sub _build_ore_types {#{{{
        my $self = shift;
        return [ sort qw(
            anthracite
            bauxite
            beryl
            chalcopyrite
            chromite
            fluorite
            galena
            goethite
            gold
            gypsum
            halite
            kerogen
            magnetite
            methane
            monazite
            rutile
            sulfur
            trona
            uraninite
            zircon
        ) ];
    }#}}}
    sub _build_protocol {#{{{
        my $self = shift;
        return $self->server_rec->protocol;
    }#}}}
    sub _build_server_rec {#{{{
        my $self = shift;

        my $schema = $self->bb->resolve( service => '/Database/schema' );
        my $rec = $schema->resultset('Servers')->find({
            id => $self->server_id
        }) or croak "Could not find server with id '" . $self->server_id . q{'.};

        return $rec;
    }#}}}
    sub _build_url {#{{{
        my $self = shift;
        return $self->server_rec->url;
    }#}}}
    sub _build_warships {#{{{
        my $self = shift;
        return [sort qw(
            bleeder
            detonator
            fighter
            placebo
            placebo2
            placebo3
            placebo4
            placebo5
            placebo6
            scow
            scow_large
            scow_fast
            scow_mega
            security_ministry_seeker
            snark
            snark2
            snark3
            spaceport_seeker
            sweeper
            thud
        )];
    }#}}}
    sub _change_allow_sleep {#{{{
        my $self      = shift;
        my $new_sleep = shift;
        my $old_sleep = shift;
        $self->client->allow_sleep( $new_sleep );
        return 1;
    }#}}}
    sub _change_rpc_sleep {#{{{
        my $self      = shift;
        my $new_sleep = shift;
        my $old_sleep = shift;
        $self->client->rpc_sleep( $new_sleep );
        return 1;
    }#}}}

    sub make_key {## no critic qw(RequireArgUnpacking) {{{
        my $self = shift;
        return join q{:}, @_;
    }#}}}
    sub ping {#{{{
        my $self = shift;

=head2 ping

Pings the game server to ensure a connection is possible with the current 
credentials.  Returns true or false.

Ping results are cached for 15 minutes, so subsequent calls to ping() don't 
re-query the server until the cache has expired.  Although the results are being 
cached, CHI is not being used, so ping can safely be called from a non-GUI where 
CHI is not available.

The Lacuna API doesn't provide any sort of plain 'ping', so what's happening 
here is that we're calling get_empire_status and handing back its retval.  This 
means that a successful ping will also store the current empire's planet listing 
(in $self->planets).

Although ping does need to hit the server, you don't need to wrap it in a 
try/catch; ping is doing that itself to ensure it can return only either true or 
false and never die.

=cut

        my $logger = $self->bb->resolve( service => '/Log/logger' );
        $logger->component('Client');
        $logger->debug('ping() called');
        $self->app->Yield if $self->app;
        if( $self->pingtime ) {
            $logger->debug('pingtime already set');
            my $now = DateTime->now();
            my $dur = $now - $self->pingtime;
            if( $dur->seconds < (15 * 60) ) {
                $logger->debug("pingtime indicates last ping call is still good.");
                return 1;
            }
            $logger->debug('pingtime has expired (' . $dur->seconds . ')');
        }
        else {
            $logger->debug("No pingtime set; this is this server's first ping.");
        }

        $self->app->Yield if $self->app;


        my $rv = try {
            $self->get_empire_status
        }
        catch {
            return;
        };
        return $rv;
    }#}}}
    sub planet_id {#{{{
        my $self  = shift;
        my $pname = shift;

=head2 planet_id

Given a planet name, returns its ID, provided that planet is owned by the 
current empire.

=cut

        return $self->planets->{$pname} // q{};
    }#}}}
    sub planet_name {#{{{
        my $self  = shift;
        my $pid   = shift || return;

=head2 planet_name

Given a planet id, returns its name.

If the given id is not found, returns undef.

=cut

        my %id_to_name = reverse %{$self->planets};
        return $id_to_name{$pid} // undef;
    }#}}}
    sub relog {#{{{
        my $self    = shift;
        my $name    = shift;
        my $pass    = shift;
        my $force   = shift || 0;

=head2 relog

Given an empire name and its sitter password, returns a new LacunaWaX::Model::Client 
object logged in as that user.  The rest of the attributes required by 
LacunaWaX::Model::Client are copied from the current client object.

Clients obtained this way are cached; subsequent calls to relog will return the 
cached client, unless the third arg, 'force', is passed as a true value.

You're encouraged to allow clients to be drawn from the cache wherever possible, 
doing so returns much more quickly than having to recreate them.

 $client = LacunaWaX::Model::Client->new( ... );

 ### These will have the same uri, api_key, allow_sleep, etc as $client.
 $new_client_1 = $client->relog('Some Empire One', 'drowssap_one');
 $new_client_2 = $client->relog('Some Empire Two', 'drowssap_two');

...Later, during the same LacunaWaX session...

 ### Draw this 'new' client from the cache instead of recreating it
 $new_client_1 = $client->relog('Some Empire One', 'drowssap_one');

 ### Not drawn from the cache - this one is brand new (for whatever reason).
 $new_client_2 = $client->relog('Some Empire Two', 'drowssap_two', 1);

=cut

        my $key = $self->make_key($name, $pass);
        unless($force) {
            if( defined $self->sitter_clients->{$key} ) {
                return $self->sitter_clients->{$key};
            }
        }

        my $glc = Games::Lacuna::Client->new(
            name        => $name,
            password    => $pass,
            uri         => $self->uri,
            api_key     => $self->api_key,
            allow_sleep => $self->allow_sleep,
            rpc_sleep   => $self->rpc_sleep,
        );

        my $lc = $self->new(
            name        => $name,
            password    => $pass,
            client      => $glc,
            uri         => $self->uri,
            server_id   => $self->server_id,
            api_key     => $self->api_key,
            bb          => $self->bb,
            allow_sleep => $self->allow_sleep,
            rpc_sleep   => $self->rpc_sleep,
        );
        $self->sitter_clients->{$key} = $lc;

        return $lc;
    }#}}}
    sub seconds_till {#{{{
        my $self = shift;

        my $target_time = shift;
        ref $target_time eq 'DateTime' or croak "target_time arg must be a DateTime object.";

        my $origin_time = shift || DateTime->now(time_zone => $target_time->time_zone);
        ref $origin_time eq 'DateTime' or croak "optional origin_time arg must be undef or a DateTime object.";

=head2 seconds_till

Returns the seconds difference between two times.  If no second (origin) time 
is given, now() is assumed.

 say $client->seconds_till( $plan_rec->datetime ) . " seconds between now and the planned arrival time.";
 say $client->seconds_till( $target_dt, $origin_dt ) . " seconds from the origin till the target.";

=cut

        my $dur         = $target_time - $origin_time;
        my $later       = $origin_time->clone->add_duration($dur);
        my $seconds_dur = $later->subtract_datetime_absolute($origin_time);
        return $seconds_dur->seconds;
    }#}}}
    sub spy_training_choices {#{{{
        return [qw(Intel Mayhem Politics Theft)];
    }#}}}
    sub travel_speed {#{{{
        my $self = shift;
        my $time = shift;
        my $dist = shift;

=head2 travel_speed

Returns the speed required to cover a given distance in a given amount of time 
(time must be provided in seconds).

 my $time_till_attack = 60 * 60 * 10; # 10 hours
 my $dist = $client->cartesian_distance(
    $origin_x, $origin_y,
    $target_x, $target_y,
 );

 my $speed_required = $client->travel_speed($time, $dist);

 if( $ship->{'speed'} < $speed_required ) {
  say "$ship->{'name'} can't make it in time.";
 }

=cut

        $time /= 360_000;
        $dist = Math::BigFloat->new($dist);
        $dist->bdiv($time);
        return sprintf "%.0f", $dist;
    }#}}}
    sub travel_time {#{{{
        my $self = shift;
        my $rate = shift;
        my $dist = shift;

=head2 travel_time

Returns the time (in seconds) to cover a given distance given a rate of speed, 
where rate is a ship's listed speed.

 my $dist = $client->cartesian_distance(
    $origin_x, $origin_y,
    $target_x, $target_y,
 );
 my $seconds_travelling = $client->travel_time($rate, $dist);

=cut

        my $secs = Math::BigFloat->new($dist);
        $secs->bdiv($rate);
        $secs->bmul(360_000);
        $secs = sprintf "%.0f", $secs;
        return $secs;
    }#}}}

### These require hitting the game server, so try/catch as needed.
    sub get_alliance_id {#{{{
        my $self = shift;

        ### Returns the ID of the current empire's alliance, or the empty string 
        ### if the user is not in an alliance.

        my $alliance_id;
        if( $self->wxbb ) {
            my $chi  = $self->wxbb->resolve( service => '/Cache/raw_memory' );
            my $key  = $self->make_key('ALLIANCE_ID');
            $alliance_id = $chi->compute($key, '1 hour', sub {
                my $emp = $self->client->empire;
                my $my_emp_id = $self->empire_status->{'empire'}{'id'};
                my $profile = $emp->view_public_profile($my_emp_id);
                my $alliance_id = (defined $profile->{'profile'}{'alliance'} and defined $profile->{'profile'}{'alliance'}{id})
                    ? $profile->{'profile'}{'alliance'}{'id'} : q{};

                return $alliance_id;
            });
        }
        else {
            my $emp = $self->client->empire;
            my $my_emp_id = $self->empire_status->{'empire'}{'id'};
            my $profile = $emp->view_public_profile($my_emp_id);
            $alliance_id = (defined $profile->{'profile'}{'alliance'} and defined $profile->{'profile'}{'alliance'}{id})
                ? $profile->{'profile'}{'alliance'}{'id'} : q{};
        }

        return $alliance_id;
    }#}}}
    sub get_alliance_profile {#{{{
        my $self = shift;

        ### Find the current user's alliance ID...
        my $alliance_id = $self->get_alliance_id();
        unless($alliance_id) {
            croak "You are not in an alliance.";
        }

        ### ...get the alliance object for that ID...
        my $alliance;
        my $alliance_profile;
        if( $self->wxbb ) {
            my $chi  = $self->wxbb->resolve( service => '/Cache/raw_memory' );
            my $a_key  = join q{:}, ('ALLIANCE', $alliance_id);
            $alliance = $chi->compute($a_key, '1 hour', sub {
                $self->app->game_client->alliance( id => $alliance_id );
            });

            my $ap_key = join q{:}, ('ALLIANCE_PROFILE', $alliance_id);
            $alliance_profile = $chi->compute($ap_key, '1 hour', sub {
                $alliance->view_profile($alliance_id);
            });
        }
        else {
            $alliance = $self->app->game_client->alliance( id => $alliance_id );
            $alliance_profile = $alliance->view_profile($alliance_id);
        }

        return $alliance_profile;
    }#}}}
    sub get_alliance_members {#{{{
        my $self        = shift;
        my $as_array    = shift;

=head2 get_alliance_members

Returns the members of $self->empire_name's alliance.

By default, returns a hashref of members:

 my $hr = $client->get_alliance_members();
 $hr == {
   id_1 => member_name_1,
   id_2 => member_name_2,
   ...
   id_N => member_name_N,
 }

But it can also return an arrayref, which more closely matches the server's 
return value.  Send a true value as the first arg to get this arrayref instead 
of the hashref:

 my $ar = $client->get_alliance_members('give me an array instead');
 $ar = [
  { id => "player 1's integer id", name => "player 1's name" },
  { id => "player 2's integer id", name => "player 2's name" },
  ...
  { id => "player N's integer id", name => "player N's name" },
 ]

=cut

        my $alliance_profile = $self->get_alliance_profile;
        my $alliance_members = $alliance_profile->{'profile'}{'members'};

        return $alliance_members if $as_array;

        ### Rework alliance_members arrayref into simply {id => 'name'}
        my $ally_hash = {};
        map{ $ally_hash->{$_->{'id'} } = $_->{'name'} }@{$alliance_members};
        return $ally_hash;
    }#}}}
    sub get_available_ships {#{{{
        my $self  = shift;
        my $pid   = shift;
        my $types = shift || [];

=head2 get_available_ships

Returns an arrayref of all ships docked on the planet:

 my $ships = $client->get_available_ships($planet_id);

If you want just a subset, send an arrayref of the types you're interested in:

 my $scows_and_sweepers = $client->get_available_ships(
  $planet_id,
  [qw( scow scow_large scow_mega sweeper )]
 );

=cut

        my $sp = $self->get_building($pid, 'Space Port');
        my $paging = {no_paging => 1};
        my $filter = {task => 'Docked'};

        my $ships;
        if( $self->wxbb ) {
            my $chi  = $self->wxbb->resolve( service => '/Cache/raw_memory' );
            my $key  = $self->make_key('BODIES', 'SHIPS', 'AVAILABLE', (sort @{$types}), $pid);
            $filter->{type} = $types;
            $self->app->Yield if $self->app;
            $ships = $chi->compute($key, '1 hour', sub {
                $self->get_ships( $sp, $pid, $filter );
            });
            $self->app->Yield if $self->app;
        }
        else {
            $ships = $self->get_ships( $sp, $pid, $filter );
        }

        return $ships;
    }#}}}
    sub get_body {#{{{
        my $self = shift;
        my $pid  = shift;

        my $body;
        if( $self->wxbb ) {
            my $chi  = $self->wxbb->resolve( service => '/Cache/raw_memory' );
            my $key  = $self->make_key('BODIES', $pid);
            $body = $chi->compute($key, '1 hour', sub {
                $self->client->body(id => $pid);
            });
        }
        else {
            $body = $self->client->body(id => $pid);
        }

        return $body;
    }#}}}
    sub get_body_status {#{{{
        my $self = shift;
        my $pid  = shift;

=head2 get_body_status

Queries the server for status of the body with ID $pid.  Returns just the body 
status (rather than including the extra junk that GLC's get_status returns.)

Also records in the BodyTypes table whether the body is a Space Station or a 
planet.

=cut

        my $body = $self->get_body($pid);

        my $code_to_cache = sub {
            $self->app->Yield if $self->app;
            my $cbs = $body->get_status;   # cached body status
            ref $cbs eq 'HASH' and defined $cbs->{'body'} or return;
            $cbs = $cbs->{'body'};

            if( defined $cbs->{'empire'} and $cbs->{'empire'}{'alignment'} eq 'self' ) { # this is my planet
                my $schema = $self->bb->resolve( service => '/Database/schema' );

                my $body_type_rec = $schema->resultset('BodyTypes')->find_or_create({ 
                    body_id   => $cbs->{'id'}, 
                    server_id => $self->server_id
                });
                if( $cbs->{'type'} eq 'space station' ) {
                    $body_type_rec->type_general('space station');
                }
                else {
                    $body_type_rec->type_general('planet');
                }
                $body_type_rec->update;
            }

            return $cbs;
        };

        my $bs;
        if( $self->wxbb ) {
            my $chi = $self->wxbb->resolve( service => '/Cache/raw_memory' );
            my $key = $self->make_key('BODIES', 'STATUS', $pid);
            $bs     = $chi->compute($key, '1 hour', $code_to_cache);
            ### Something failed; don't keep the failure in the cache.
            $bs or $chi->remove($key);
        }
        else {
            $bs = &{$code_to_cache};
        }

        return $bs || {};   # always return a hashref
    }#}}}
    sub get_building {#{{{
        my $self  = shift;
        my $pid   = shift;
        my $type  = shift;
        my $force = shift || 0;

=head2 get_building

Returns a single GLC building object for a unique building.  

$type is fairly liberal - either the machine name ("entertainment") or the 
human name ("Entertainment Ministry") can be passed.  Both are case insensitive.

Calling this on a building type that may have multiple instances onplanet will 
return a random instance of that type.  Which is probably fine if you just 
want a listing of ships from a Space Port.  It may not be fine if you want to 
begin building ships at a Shipyard - you might end up getting back the 
lower-level shipyard rather than the higher-level one you wanted.

Caveat progammor.

=cut

        ### No caching needed here; both get_buildings and get_building_object 
        ### are managing their own caches.
        my $bldgs_hr = $self->get_buildings( $pid, $type, $force );
        my($id, $bldg_hr) = each %{$bldgs_hr};
        return $self->get_building_object($pid, $bldg_hr);
    }#}}}
    sub get_buildings {#{{{
        my $self  = shift;
        my $pid   = shift;
        my $type  = shift;
        my $force = shift || 0;

=head2 get_buildings

Returns all buildings matching the requested type in a hashref keyed off the 
building ID:

 12345 => { hashref for bldg 12345 },
 98765 => { hashref for bldg 98765 },
 etc

You can specify a type of building:

 my $space_ports = $client->get_buildings($planet_id, 'Space Port');

Buildings get cached by default; you can force a fresh draw from the server by 
sending a true value as the third ('force') arg:
 my $fresh = $client->get_buildings($planet_id, undef, 1);

=cut

        $self->app->Yield if $self->app;
        my $pobj  = $self->get_body($pid);
        $self->app->Yield if $self->app;


        my $code_to_cache = sub {
            my $bldg = $pobj->get_buildings;
            ref $bldg eq 'HASH' and defined $bldg->{'buildings'} or return;
            $bldg = $bldg->{'buildings'};
        };


        my $all_bldgs;
        if( $self->wxbb ) {
            my $chi = $self->wxbb->resolve( service => '/Cache/raw_memory' );
            my $key = $self->make_key('BODIES', 'BULIDINGS', $pid);
            $chi->remove($key) if $force;
            $all_bldgs = $chi->compute($key, '1 hour', $code_to_cache);
            ### Something failed; don't keep failure in the cache.
            unless($all_bldgs) {
                $chi->remove($key);
                return {};
            }
        }
        else {
            $all_bldgs = &{$code_to_cache};
        }

        $self->app->Yield if $self->app;
        return $all_bldgs unless $type;

        my $type_bldgs = {};
        foreach my $id( keys %{$all_bldgs} ) {
            $self->app->Yield if $self->app;
            my $this_bldg = $all_bldgs->{$id};
            if( 
                $this_bldg->{'name'} =~ /$type/i    # "Apple Orchard"
                or
                $this_bldg->{'url'} =~ m{/$type}i   # "/apple"
            ) {
                $this_bldg->{'id'} = $id;   # add id to the hashref; save us a step elsewhere.
                $type_bldgs->{$id} = $this_bldg;
            }
        }
        return $type_bldgs;
    }#}}}
    sub get_building_object {#{{{
        my $self    = shift;
        my $pid     = shift;
        my $bldg_hr = shift;
        my $force   = shift || 0;


=head2 get_building_object

Given a single building hashref as returned by get_buildings, this returns a 
GLC building object.

=cut

        ### Will happen if the requested building doesn't exist.
        return unless ref $bldg_hr eq 'HASH';

        my $id   = $bldg_hr->{'id'}; 
        my $type = substr $bldg_hr->{'url'}, 1;   # remove the leading slash from the url
        
        my $obj;
        if( $self->wxbb ) {
            ### wxbb only present from the GUI; it's where the cache lives.
            my $chi = $self->wxbb->resolve( service => '/Cache/raw_memory' );
            my $key = $self->make_key('BODIES', 'BULIDINGS', 'OBJECTS', $pid, $id);
            $chi->remove($key) if $force;
            $obj = $chi->compute($key, '1 hour', sub {
                $self->client->building(id => $id, type => $type);
            });
        }
        else {
            $obj = $self->client->building(id => $id, type => $type);
        }

        return $obj;
    }#}}}
    sub get_building_view {#{{{
        my $self        = shift;
        my $pid         = shift;
        my $bldg_obj    = shift;

=head2 get_building_view

A building object (from get_building or get_building_object) can consist of just 
client, building_id, and uri keys.  If you need the building's level, coords, 
whatever, you need to view the building.

$pid increases clarity, but since bldg_obj ID values are unique across the 
expanse, and the $pid is only used in the cache key, you're safe in sending 
any numeric value in $pid that you want - don't spend extra time getting the $pid 
if you haven't already got it.

 my $bldg = $client->get_building($pid, $type);
 my $view = $client->get_building_view($pid, $bldg);

Returns a hashref containing 'status' (sigh) and 'building', which is what you want:

 {
  status => { ... },

  building => {
   'waste_hour' => '0',
   'efficiency' => '100',
   'food_capacity' => 0,
   'ore_capacity' => 0,
   'x' => '3',
   'y' => '4',

   ... etc - Dumper for the full hashref.
   }
 }

=cut

        my $bid = $bldg_obj->{'building_id'};

        my $view;
        if( $self->wxbb ) {
            ### wxbb only present from the GUI; it's where the cache lives.
            my $chi = $self->wxbb->resolve( service => '/Cache/raw_memory' );
            my $key = $self->make_key('BODIES', 'BULIDINGS', 'VIEWS', $pid, $bid);
            $view = $chi->compute($key, '1 hour', sub {
                $bldg_obj->view();
            });
        }
        else {
            $view = $bldg_obj->view();
        }

        return $view;
    }#}}}
    sub get_empire_status {#{{{
        my $self   = shift;

=head2 get_empire_status

Queries the server for status, and therefore planet listing, of the current 
empire.

This method I<always> re-queries the server.  To avoid that when not 
necessary, call ping() instead.

=cut

        $self->app->Yield if $self->app;
        my $empire = $self->client->empire;
        $self->app->Yield if $self->app;
        my $status = $empire->get_status;
        ref $status eq 'HASH' or return;
        $self->empire_status($status);

        $self->app->Yield if $self->app;
        $self->pingtime( DateTime->now );
        $self->app->Yield if $self->app;
        $self->planets({ reverse %{$status->{'empire'}{'planets'}} });
        $self->app->Yield if $self->app;
        return 1;
    }#}}}
    sub get_glyphs {#{{{
        my $self = shift;
        my $pid  = shift;

=head2 get_glyphs

Returns listing of all glyphs on a planet, sorted by glyph name.  Unlike the 
game, this returns all glyphs, including those we have zero of.

 my $rv = $client->get_glyphs( $planet_id );

 $rv = [
  {name => 'anthracite', quantity => 0},
  {name => 'bauxite',    quantity => 13},
  {name => 'beryl',      quantity => 50},
  ...
 ];

=cut

        $self->app->Yield if $self->app;
        my $am = $self->get_building($pid, 'Archaeology Ministry');
        $self->app->Yield if $self->app;
        unless( $am and $am->isa('Games::Lacuna::Client::Buildings::Archaeology') ) {
            croak "No Archaeology Ministry exists on this body, so you can't assemble glyphs here.";
        }

        my $code_to_cache = sub {
            #my $glyphs_on_planet = $self->call($am, 'get_glyph_summary')->{'glyphs'};
            my $glyphs_on_planet = $am->get_glyph_summary->{'glyphs'};

            ### List all possible ores, turn into hash   ( orename => 0 )
            my @ore_list = @{ $self->ore_types };
            my %all_ores;
            @all_ores{ @ore_list } = (0)x@ore_list;
            $self->app->Yield if $self->app;

            ### Get glyphs we've got nonzero of; remove those oretypes from 
            ### the ore hash.
            foreach my $glyphs_hr(@{$glyphs_on_planet}) {
                delete $all_ores{ $glyphs_hr->{'name'}  };
                $self->app->Yield if $self->app;
            }

            ### What's left are ores for which we have zero glyphs.
            foreach my $remaining_ore( keys %all_ores ) {
                my $hr = {
                    name     => $remaining_ore,
                    quantity => 0,
                };
                push @{$glyphs_on_planet}, $hr;
                $self->app->Yield if $self->app;
            }
            my $sorted_glyphs = [ sort{ $a->{'name'} cmp $b->{'name'} }@{$glyphs_on_planet} ];
            $self->app->Yield if $self->app;
            return $sorted_glyphs;
        };

        my $sorted_glyphs;
        if( $self->wxbb ) {
            my $chi = $self->wxbb->resolve( service => '/Cache/raw_memory' );
            my $key = $self->make_key('BODIES', 'GLYPHS', $pid);
            $sorted_glyphs = $chi->compute($key, '1 hour', $code_to_cache);
            $self->app->Yield if $self->app;
        }
        else {
            $sorted_glyphs = &{$code_to_cache};
        }

        return $sorted_glyphs;
    }#}}}
    sub get_lottery_links {#{{{
        my $self     = shift;
        my $pid      = shift || croak "planet_id required";
        my $ent_dist = shift || q{};

=head2 get_lottery_links

 my $links = get_lottery_links($planet_id [, $entertainment_district ]);

https://us1.lacunaexpanse.com/api/Entertainment.html

Returns an AoH of the current lottery voting options:
 
 [
  {name => 'Some Site 1', url => 'http:://www.example.com/1'},
  {name => 'Some Site 2', url => 'http:://www.example.com/2'},
  ...
 ]


B<BE VERY CAREFUL WITH THIS!>

The urls will contain a query string which includes building_id=123456 - that 
building_id is the ID of the Entertainment District building from which the 
links were first pulled before being cached.

Hitting the URLs as they are will play the lottery I<in the zone where that 
original Entertainment District existed>.  This may or may not be what you want.  

See LacunaWaX::Model::Links for methods to change the building id so you can 
play the lottery in a different zone.

Links will only be returned if they have not been clicked on today!  After 
voting, the links become unavailable until after the current day's lottery has 
been run.  There's no way of getting those links with some sort of "I already 
clicked these links today" indicator; they're simply unavailable.

So it's entirely likely that this will return zero links.  This is not a bug!

The ID of a planet with an entertainment district must be passed in.  If you've 
already got the entertainment district object in-hand, that may be passed in as 
well.  However, you're better off allowing this method to generate the 
entertainment district for you; if the links have already been cached, then 
actually getting the entertainment district is not necessary and will be 
skipped, saving some time.

The lottery links obtained from one colony apply to all colonies, not just to 
the planet ID passed in, but an entertainment district building is required to 
access those links in the first place; hence the need for the planet_id.

=cut


        my $chi;
        my $key = $self->make_key('LOTTERY', 'OPTIONS');
        if( $self->wxbb ) {
            $chi  = $self->wxbb->resolve( service => '/Cache/raw_memory' );
        }


        unless($ent_dist) {
            if( $chi ) {
                if( my $opts = $chi->get($key) ) {
                    ### We weren't given an entertainment district, but the links 
                    ### have already been cached so there's no need to go get this 
                    ### planet's ent dist; just return the cached links.
                    return $opts;
                }
            }
            $ent_dist = $self->get_building($pid, 'Entertainment')
        }
        ref $ent_dist eq 'Games::Lacuna::Client::Buildings::Entertainment'
            or croak "No entertainment district found.";

        my $opts;
        if( $chi ) {
            $opts = $chi->compute($key, '15 minutes', sub {
                my $o = $ent_dist->get_lottery_voting_options;
                return $o->{'options'};
            });
        }
        else {
            $opts = $ent_dist->get_lottery_voting_options->{'options'};
        }

        return $opts;
    }#}}}
    sub get_min_speed {#{{{
        my $self  = shift;
        my $ships = shift;

=head2 min_speed

Given an arrayref as returned by any of the get_*ships() methods, returns the 
speed of the slowest ship; this is the fastest speed a fleet containing this 
ship can attain.

 my $warships = $client->get_available_ships($pid);
 say "the fastest a fleet containing these ships can travel is "
  $client->get_min_speed($warships);

=cut

        my $min_speed = 9_999_999;
        foreach my $s( @{$ships} ) {
            $min_speed = $s->{'speed'} if $s->{'speed'} < $min_speed;
        }
        return $min_speed;
    }#}}}
    sub get_ships {#{{{
        my $self   = shift;
        my $sp     = shift;
        my $pid    = shift;
        my $filter = shift || {};

=head2 get_ships

Not meant to be called directly.  Instead, see get_available_ships() and its 
ilk.

This retrieves and caches _all_ ships on the planet.  What gets returned is i
controlled by the optional $filter arg:

 $filter = {
  type => ['sweeper'],
  task => 'Docked',
 }

This $filter arg is similar, but not not identical to, the $filter arg allowed 
by GLC's view_all_ships.  The filter for get_ships() differs in that:

 - it does not allow a 'tag' filter key
   - Well, it's allowed, but it will be ignored.
 - its 'type' key must be an arrayref.
   - GLC's can be an arrayref of multiple types or a scalar of a single type.
   - Too much hassle; just send an arrayref always. 

=cut

        ### Don't mess around with filtering the request to the server.  Just 
        ### get _all_ ships and cache the result.  We'll then filter out the 
        ### resultset ourselves.

        my $ships;
        if( $self->wxbb ) {
            my $chi  = $self->wxbb->resolve( service => '/Cache/raw_memory' );
            my $key  = $self->make_key('BODIES', 'SHIPS', $pid);
            $ships = $chi->compute($key, '1 hour', sub {
                $sp->view_all_ships({no_paging => 1})->{'ships'};
            });
            $self->app->Yield if $self->app;
        }
        else {
            #$ships = $self->call($sp, 'view_all_ships', [ {no_paging => 1} ])->{'ships'};
            $ships = $sp->view_all_ships({no_paging => 1})->{'ships'};
        }

        defined $filter->{type} and ref $filter->{type} eq 'ARRAY' or delete $filter->{type};

        my $ret_ships = [];
        if( keys %{$filter} ) {
            foreach my $s( @{$ships} ) {
                $self->app->Yield if $self->app;
                my $save = 1;
                if( defined $filter->{'task'} and lc $s->{'task'} ne lc $filter->{'task'} ) {
                    $save = 0;
                }
                if( $save and defined $filter->{'type'} and not first{$_ =~ /$s->{'type'}/i}@{$filter->{'type'}} ) {
                    $save = 0;
                }
                if($save) {
                    push @{$ret_ships}, $s if $save;
                }
                else {
                    $s->{'number_of_ships'}--;
                }
            }
        }
        else {
            $ret_ships = $ships;
        }

        $self->app->Yield if $self->app;
        return $ret_ships;
    }#}}}
    sub get_ship_counts {#{{{
        my $self  = shift;
        my $ships = shift;

=head2 get_ship_counts

Given an arrayref as returned by any of the get_*ships() methods, returns a 
hashref of the counts of each ship type.

 my $warships = $client->get_available_ships($pid);
 # $warships is an AoH with one element per individual ship, so there may 
 # be thousands of elements.

 my $counts = $client->get_ship_counts($warships);
 say "There are $counts->{'sweeper'} sweepers on planet $pid.";
 say "There are $counts->{'snarke'} snark IIIs on planet $pid.";

 ...etc...

=cut

        my $ship_counts = {};
        foreach my $s( @{$ships} ) {
            $ship_counts->{ $s->{'type'} }++;
            $self->app->Yield if $self->app;
        }
        return $ship_counts;
    }#}}}
    sub get_spies {#{{{
        my $self   = shift;
        my $pid    = shift;

=head2 get_spies

This retrieves and caches all spies native to this planet.

"Native to" means the spy was created at this planet's Int Min.  The spy's 
current geographical location is irrelevant.

Returns an AoH, one spy per H.

=cut

        my $im = $self->get_building($pid, 'Intelligence');
        $self->app->Yield if $self->app;
        return unless $im and ref $im eq 'Games::Lacuna::Client::Buildings::Intelligence';

        my $code_to_cache = sub {
            my $rv = $im->view_all_spies;
            defined $rv->{'spies'} and ref $rv->{'spies'} eq 'ARRAY' and return $rv->{'spies'};
            return [];
        };


        my $spies;
        if( $self->wxbb ) {
            my $chi  = $self->wxbb->resolve( service => '/Cache/raw_memory' );
            my $key  = $self->make_key('BODIES', 'SPIES', $pid);
            $spies = $chi->compute($key, '1 hour', $code_to_cache);
            $self->app->Yield if $self->app;
        }
        else {
            $spies = &{$code_to_cache};
        }

        return $spies;
    }#}}}
    sub cook_glyphs {#{{{
        my $self            = shift;
        my $planet_id       = shift;
        my $recipe          = shift;
        my $num_requested   = shift // 5000;
        my $exact           = shift || 0;

=head2 cook_glyphs

Combines glyphs into the requested plan recipe.

 my $rv = $client->cook_glyphs(
  $planet_id,
  $recipe,
  $num_to_build,
  $exact
 );

$recipe is an arrayref of the glyphs to combine, in the correct order.

$num_requested is the number of plans of this type to build.  Defaults 
to 5000, the maximum.

$exact is a boolean flag.  If true, we will build exactly $num_requested of the 
requested recipe or we'll fail.  So if you request to build 10 of a given 
recipe, but there are only enough glyphs onsite to build 8 of that recipe, a 
true value for $exact will cause the build to fail.  Normally not what you want.  
If false, we'll build I<up to> $num_requested of the requested recipe.  In our 
example, the 8 possible plans would have been built.  Defaults to false.

On success, returns a hashref including the standard status hashref, the 
name of the item built, and the quantity built:

 {
    status    => { standard status hashref you're likely not interested in },
    item_name => 'Volcano',     # or whatever
    quantity  => 13,            # or whatever
 }

On failure, the hashref returned will contain 'error', whose value will be an 
error string.  ALWAYS check for the existence of that key in the returned 
hashref.

=cut

        my $logger = $self->bb->resolve( service => '/Log/logger' );
        $logger->component('Client');

        my $am = $self->get_building($planet_id, 'Archaeology Ministry');
        my $rv = {};
        $rv = try {
            my $rv = $am->assemble_glyphs($recipe, $num_requested);
            $rv->{'quantity'} = $num_requested;
            return $rv;
        }
        catch {
            if($_ =~ /You don't have (\d+) glyphs of type (\w+) you only have (\d+)/ and not $exact) {
                my $type        = $2;
                my $num_built   = $3;
                $logger->debug("cook_glyphs asked to make $num_requested, only have $num_built $type glyphs.  Trying again.");
                return $self->cook_glyphs($planet_id, $recipe, $num_built);
            }
            else {
                return {error => 'Insufficient Glyphs!'};
            }
        };

        return $rv;
    }#}}}
    sub rearrange {#{{{
        my $self    = shift;
        my $pid     = shift;
        my $layout  = shift;

=head2 rearrange

Rearranges buildings on a planet according to a specified layout.

 my $layout = [
    {
        bldg_id => 'integer bldg ID 1',
        x => 'Desired X coord',
        y => 'Desired Y coord',
    },
    {
        bldg_id => 'integer bldg ID 2',
        x => 'Desired X coord',
        y => 'Desired Y coord',
    },
    {
        bldg_id => 'integer bldg ID 3',
        x => 'Desired X coord',
        y => 'Desired Y coord',
    },
 ];

 my $rv = $client->rearranged( $planet_id, $layout );

Returns a hashref which includes an arrayref of moved buildings keyed off 
'moved':

 if( $rv->{'moved'} ) {
    say ( scalar @{$rv->{'moved'}} ) . " buildings were moved.";
 }

=cut

        my $body = $self->get_body($pid);
        my $rv   = $body->rearrange_buildings($layout);
        return $rv;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

1;

