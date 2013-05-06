package Games::Lacuna::Client::Task::Station;
use v5.14;
use CHI;
use Data::Dumper;  $Data::Dumper::Indent = 1;
use DateTime;
use DateTime::Duration;
use List::Util;
use Moose;
use Try::Tiny;
use utf8;
with 'Games::Lacuna::Client::Task';

BEGIN {
    ### $Id: Station.pm 14 2012-12-10 23:19:27Z jon $
    ### $URL: https://tmtowtdi.gotdns.com:15000/svn/LacunaWaX/trunk/lib/Games/Lacuna/Client/Task/Station.pm $
    my $revision = '$Rev: 14 $';
    $Games::Lacuna::CLient::Task::Station::VERSION = '0.3.' . join '', $revision =~ m/(\d+)/;
}

### POD {#{{{

=head1 NAME

Games::Lacuna::Client::Task::Station - Manage tasks specific to a particular 
space station.  Usable by either the station owner or anyone in the alliance.

=head1 SYNOPSIS

 my $client  = Games::Lacuna::Client::App->new({ cfg_file => $client_file });
 my $station = Games::Lacuna::Client::Task::Station->new({
  client => $client,
  name => 'My Station Name'
 });

 # get_buildings works just like Planet.pm's version
 $parl = $station->get_buildings('Parliament')->[0]
   or die "No Parliament built yet.";

 # Get all propositions currently up for vote
 $props = $station->get_props($parl);

 # Vote yes on all propositions
 foreach my $prop( @$props ) {
  $station->agree_prop($prop);
 }

 # Or just vote yes on props submitted by...

 # ...the station owner...
 $station->agree_owner_props();

 # ...the alliance leader...
 $station->agree_leader_props();

 # ...anyone - this is identical to the foreach block above
 # to vote on all props.
 $station->agree_all_props();


=head1 DESCRIPTION

Performs a number of common, often tedious tasks specific to a given planet.  
Most users won't use this module at all, but will prefer 
L<Games::Lacuna::Client::Task::Empire>, which will perform all of these 
planet-specific tasks once for each planet in their empire, as well as a few 
other empire-specific tasks.

=head1 HISTORY

No notes exist before version 0.3.x.  This module was originally copied from 
Planet.pm and brought the 0.2.x version number with it.  0.3.x is the first 
actual version upgrade since the beginning.

=head2 0.3.rev, 07/2012

- get_server_data now just does what it says.  It's now called conditionally 
  based on how old the existing server data is.

- Instead of looking up the station owner's empire by name, get_server_data is 
  now looking it up by ID.  Looking it up by name was causing explosions when a 
  player changed his empire's name, which doesn't automatically get reflected in
  my database.

- Much cleanup (mainly grouping) of similar attributes.

=head1 Methods

=cut

### }#}}}

has 'client'    => ( isa => 'Games::Lacuna::Client', is => 'rw' );
has 'id'        => ( isa => 'Int', is => 'rw', documentation => q{This is the game's ID, not my Planets.id} );
has 'name'      => ( isa => 'Str', is => 'rw' );
has 'body'      => ( isa => 'Games::Lacuna::Client::Body', is => 'rw' );

has 'chi' => (
    is  => 'rw',
    isa => 'Object',
    lazy_build => 1,
    documentation => q{
        This is a direct reference to App.pm's chi.
        The key for every cache node accessed from within this file begins with 
        "Station:" as a pseudo-namespace.
    },
);
has 'influence'       => ( isa => 'HashRef', is => 'rw', lazy => 1, builder => 'get_server_data',
    documentation => q/
        Contains the keys 'total' and 'spent'.  The values of both are integers.
        An SS can seize as many stars as it has influence.
        So  $this->{total} - $this->{spent}  is the number of additional stars this station can seize.
    /
);

### These attributes require a call to get_status, which is expensive.  A 
### single get_status call gets data for all of these attributes at once.
###
### So on the first accessor call to any of these, we'll call get_status, set 
### all of these attributes, and then update server_data_age to now(), which 
### will keep us from re-calling get_status again.
has 'server_data_age'   => (is => 'rw', isa => 'DateTime', lazy => 1, default => sub{ DateTime->new(year => 1970) } );
has 'owner'             => ( isa => 'Games::Lacuna::Schema::Result::Empire',   is => 'rw' );
has 'leader'            => ( isa => 'Games::Lacuna::Schema::Result::Empire',   is => 'rw' );
has 'alliance'          => ( isa => 'Games::Lacuna::Schema::Result::Alliance', is => 'rw' );

has [
    'owner_name', 'alliance_name', 'leader_name', 'type', 'zone'
] => ( isa => 'Str', is => 'rw' );

has [
    'owner_id', 'alliance_id', 'leader_id', 'population', 'x', 'y', 'size', 'star_id',
    'needs_surface_refresh', 'food_capacity', 'food_stored', 'food_hour', 'ore_capacity', 'ore_stored', 
    'ore_hour', 'water_capacity', 'water_stored', 'water_hour', 'energy_capacity', 'energy_stored', 'energy_hour',
] => ( isa => 'Int', is => 'rw' );

before [
    'body', 
    'owner', 'leader', 'alliance', 'owner_name', 'owner_id', 'alliance_name', 'alliance_id', 'leader_id',
    'leader_name', 'type', 'population', 'x', 'y', 'zone', 'size', 'star_id', 'needs_surface_refresh', 
    'food_capacity', 'food_stored', 'food_hour', 'ore_capacity', 'ore_stored', 'ore_hour', 'water_capacity', 
    'water_stored', 'water_hour', 'energy_capacity', 'energy_stored', 'energy_hour',
] => sub {
    my $self = shift;
    my $now  = DateTime->now();
    my $dur  = $now - $self->server_data_age;

    if( $dur->years ) {
        ### First hit, since server_data_age was initialized to 1970
        $self->server_data_age( $now );
        $self->get_server_data;
    }
    elsif( $dur->minutes > 15 ) {
        ### Not the first hit, but the data's growing stale; re-grab.
        ### 15 minutes seems sensible but is otherwise arbitrary.
        $self->server_data_age( $now );
        $self->get_server_data;
    }
};

sub BUILD {#{{{
    my( $self, $params ) = @_;
    ### A space station is kept in client->planets; it's considered a sort of 
    ### planet by the game.  So 'planets' below is not a CnP error.
    if( defined $params->{'id'} ) {
        defined $params->{'client'}->planets->{  $params->{'id'}  }
            or die "Invalid station ID: $params->{'id'}";
        $self->name( $params->{'client'}->planets->{$params->{'id'}} );
    }
    elsif( defined $params->{'name'} ) {
        defined $params->{'client'}->planets->{  $params->{'name'}  }
            or die "Invalid station name: $params->{'name'}";
        $self->id( $params->{'client'}->planets->{$params->{'name'}} );
    }
    else {
        die "At least one of (id, name) is required.";
    }
}#}}}
sub _build_chi {#{{{
    my $self = shift;
    $self->client->chi;
#    CHI->new( 
#        driver     => 'RawMemory',
#        expires_in => '15 minutes',
#        global     => 1,
#        namespace  => __PACKAGE__,
#    );
}#}}}

sub agree_all_props {#{{{
    my $self = shift;
    my $parl = shift || $self->get_buildings('Parliament')->[0] || die "No parliament building found.";
    my $c    = $self->client;

=pod

Votes Yes on all propositions in Parliament, regardless of who proposed them 
or what they are.  Use this with caution.

'all' propositions does not include props to fire the BFG.  Any such props 
will simply be skipped, forcing each user to agree or disagree by hand.

 $station->agree_all_props()

...or, if you've already got a parliament object lying around...

 $station->agree_all_props( $parl )

=cut

    my $props = $self->get_props($parl);

    my $cnt = 0;
    PROP:
    foreach my $p(@$props) {
        next PROP if $p->{'name'} =~ /Fire BFG/;
        $cnt++ if $self->agree_prop($p, $parl);
    }
    $c->log->debug("Agreed to $cnt props on " . $self->name);
    return $cnt;
}#}}}
sub agree_owner_props {#{{{
    my $self = shift;
    my $parl = shift || $self->get_buildings('Parliament')->[0] || die "No parliament building found.";
    my $c    = $self->client;

=pod

Votes Yes on all propositions in Parliament which were proposed by the 
station's owner.

'all' propositions does not include props to fire the BFG.  Any such props 
will simply be skipped, forcing each user to agree or disagree by hand.

 $station->agree_all_props()

...or, if you've already got a parliament object lying around...

 $station->agree_all_props( $parl )

=cut

    my $props = $self->get_props($parl);
    my $cnt = 0;
    PROP:
    foreach my $p(@$props) {
        next PROP if $p->{'name'} =~ /Fire BFG/;
        $c->log->debug("proposed_by id: " . $p->{proposed_by}{id});
        unless($self->owner_id ) {
            $self->get_server_data;
        }
        if( $self->owner_id and $p->{'proposed_by'}{'id'} == $self->owner_id ) {
            $cnt++ if $self->agree_prop($p, $parl);
        }
    }
    $c->log->debug("Agreed to $cnt props on " . $self->name);
    return $cnt;
}#}}}
sub agree_leader_props {#{{{
    my $self = shift;
    my $parl = shift || $self->get_buildings('Parliament')->[0] || die "No parliament building found.";
    my $c    = $self->client;

=pod

Votes Yes on all propositions in Parliament which were proposed by the 
station's alliance's leader.

'all' propositions does not include props to fire the BFG.  Any such props 
will simply be skipped, forcing each user to agree or disagree by hand.

 $station->agree_leader_props()

...or, if you've already got a parliament object lying around...

 $station->agree_leader_props( $parl )

=cut

    my $props = $self->get_props($parl);
    my $cnt = 0;
    PROP:
    foreach my $p(@$props) {
        next PROP if $p->{'name'} =~ /Fire BFG/;
        unless($self->leader_id ) {
            $self->get_server_data;
        }
        if( $self->leader_id and $p->{'proposed_by'}{'id'} == $self->leader_id ) {
            $cnt++ if $self->agree_prop($p, $parl);
        }
    }
    $c->log->debug("Agreed to $cnt props on " . $self->name);
    return $cnt;
}#}}}
sub agree_prop {#{{{
    my $self = shift;
    my $prop = shift;
    my $parl = shift || $self->get_buildings('Parliament')->[0] || die "No parliament building found.";
    my $c    = $self->client;

=pod

Votes Yes on a given proposition in Parliament.

 $props = $station->get_props();
 foreach my $p( @$props ) {
    $station->agree_prop( $p ) if( $some_condition );
 }

...or, if you've already got a parliament object lying around...

 $station->agree_prop( $prop, $parl );

=cut

    ### Returns the prop object voted on.  Also, more usefully, true.
    return try {
        $c->call($parl, 'cast_vote', [$prop->{'id'}, '1']);
    }
    catch {
        if( $_ =~ /Proposition not found/ ) {
            $c->log->debug("Proposition ID '$prop->{'id'}' was not found.");
        }
        return 0;
    };
}#}}}
sub clear_cache {#{{{
    my $self = shift;
    $self->chi->clear() unless $self->client->no_cache;
}#}}}
sub get_buildings {#{{{
    my $self = shift;
    my $building_type = shift;

=pod

Gets buildings on this planet.

 $all = $planet->get_buildings();

..or..

 $just_mines = $planet->get_buildings('Mine');

When you request a building type, you may request either by the user-friendly 
name ("Food Reserve"), or the internal shortname ("foodreserve").  In either 
case, the match is a case-insensitive regex, so you could search for "foo" to 
get Food Reserve buildings.

Don't shorten your search string too much, and be aware of duplicate 
possibilities.  If you search for "Training" you _will_ get all spy training 
facilities, but you'll also get the Pilot Training facility as well.  Caveat 
programmator.

=cut


    my $c = $self->client;

    my $body = $c->no_cache
        ? $c->call($c, 'body', [id => $self->id, foo => 'bar'])
        : $self->chi->compute( (join ':',('Station', "body", $self->id)), {}, sub{ $c->call($c, 'body', [id => $self->id, foo => 'bar']) });
    my $buildings = $c->no_cache
        ? $c->call($body, 'get_buildings', [foo => 'bar'])->{'buildings'}
        : $self->chi->compute( (join ':', ('Station', "bldgs_hr",$self->id)), {}, sub{ $c->call($body, 'get_buildings', [foo => 'bar'])->{'buildings'} });
    ($body and $buildings) or return [];

    my $bldg_objs = [];
    while( my($bldg_id,$hr) = each %$buildings ) {
        my $type_arg = substr $hr->{'url'}, 1;  # remove the slash from eg '/command' or '/spaceport'

        if( $building_type ) {
            ### Just list buildings of this type
            if( 
                   $hr->{'name'} eq $building_type
                or $hr->{'url'} =~ /$building_type/i
            ) {
                my $b = $c->no_cache
                    ? $c->call($c, 'building', [id => $bldg_id, type => $type_arg])
                    : $self->chi->compute( (join ':', ('Station', "bldgs_obj", $self->id, $bldg_id)), {}, sub{ $c->call($c, 'building', [id => $bldg_id, type => $type_arg]) });
                $b or return [];
                push @$bldg_objs, $b;
            }
        }
        else {
            ### List all buildings on this body
            my $b = $c->no_cache
                ? $c->call($c, 'building', [id => $bldg_id, type => $type_arg])
                : $self->chi->compute( (join ':', ("bldgs_obj", $self->id, $bldg_id)), {}, sub{ $c->call($c, 'building', [id => $bldg_id, type => $type_arg]) });
            $b or return [];
            push @$bldg_objs, $b;
        }
    }
    return $bldg_objs;

}#}}}
sub get_props {#{{{
    my $self = shift;
    my $parl = shift || $self->get_buildings('Parliament')->[0] || die "No parliament building found.";
    my $c    = $self->client;

=pod

Returns an arrayref of current propositions at this station's Parliament building.

Each prop follows the format:

 {
 'status' => 'Pending',
 'name' => 'Upgrade Station Command Center',
 'description' => 'Upgrade Station Command Center (0,0) on {Planet 370819 Blai Iaplio 7} from level 1 to 2.',
 'votes_no' => '0',
 'votes_yes' => '3',
 'proposed_by' => {
  'name' => 'kc120976',
  'id' => '22581'
 },
 'id' => '27408',
 'date_ends' => '05 03 2012 18:07:31 +0000',
 'votes_needed' => 6
}

=cut

    my $props_view = $c->no_cache
        ? $c->call($parl, 'view_propositions')
        : $self->chi->compute( (join ':',('Station', "station", $self->id, 'propositions')), {}, sub{ 
                my $view = $c->call($parl, 'view_propositions');
                if( ref $view eq 'HASH' ) {
                    return $view;
                }
                return [];
            }
        );

    return [] unless ref $props_view eq 'HASH' and defined $props_view->{'propositions'};
    return $props_view->{'propositions'};
}#}}}
sub get_server_data {#{{{
    my $self = shift;
    my $c    = $self->client;

    my $body = $c->no_cache
        ? $c->call($c, 'body', [id => $self->id])
        : $self->chi->compute( "Station:body:$self->id", {}, sub{ $c->call($c, 'body', [id => $self->id]) });
    my $status = $c->no_cache
        ? $c->call($body, 'get_status')
        : $self->chi->compute( "Station:body_status:$self->id", {}, sub{ $c->call($body, 'get_status') } );
    ($body and $status) or return;

    foreach my $k(qw(
        type population x y zone size star_id 
        energy_capacity energy_stored energy_hour
        food_capacity food_stored food_hour
        influence
        ore_capacity ore_stored ore_hour
        water_capacity water_stored water_hour
        needs_surface_refresh
    )) {
        if( defined $status->{'body'}{$k} ) {
            $self->$k( $status->{'body'}{$k} );
        }
        else {
            if( $k eq 'influence' ) {
                $self->$k( {} );
            }
            else {
                $self->$k( 0 );
            }
        }
    }

    ### Use id, not name, as empires can change their own names whenever they 
    ### want, at which point I'll have their old name in the database, which 
    ### won't match up with their new actual name.
    my $emp = $c->schema->resultset('Empire')->find({ id => $status->{body}{empire}{id} });
    $emp or return;

    my $all = $emp->alliance()->next;
    my $leader;
    $leader = $all->leader()->next if $all;

    if( $emp and $emp->name and $emp->id ) {
        $self->owner     ( $emp );
        $self->owner_name( $emp->name );
        $self->owner_id  ( $emp->id );
    }

    if( $all and $all->name and $all->id ) {
        $self->alliance     ( $all );
        $self->alliance_name( $all->name );
        $self->alliance_id  ( $all->id );
    }

    if( $leader and $leader->name and $leader->id ) {
        $self->leader     ( $leader );
        $self->leader_name( $leader->name );
        $self->leader_id  ( $leader->id );
    }

    $self->server_data_age( DateTime->now() );

    return 1;
}#}}}


### These are copies of the same methods in Planet.pm with the comments 
### stripped out and the package name changed in only one place (in 
### deserialize).
sub serialize {#{{{
    my $self = shift;

    ### Forces a call to get_server data if it hasn't already been called.
    my $type = $self->type;

    my %ser = %{ $self };
    delete $ser{'client'};

    if( exists $ser{'body'} and ref $ser{'body'} eq 'Games::Lacuna::Client::Body' ) {
        delete $ser{'body'}->{'client'};
        $ser{'body'} = { %{$ser{'body'}} };
    }

    if( exists $ser{'server_data_age'} and ref $ser{'server_data_age'} eq 'DateTime' ) {
        $ser{'server_data_age'} = $ser{'server_data_age'}->epoch;
    }

    return \%ser;
}#}}}
sub deserialize {#{{{
    my $proto  = shift;
    my $ser    = shift;
    my $client = shift;

    ### Only change from Planet.pm right here
    if( $proto and ref $proto eq 'Games::Lacuna::Client::Task::Station' ) {
        $client = $proto->client;
    }

    unless( ref $client eq 'Games::Lacuna::Client::App' ) {
        die "Second arg to deserialize must be client object";
    }

    $ser->{'client'} = $client;

    if( exists $ser->{'body'} ) {
        $ser->{'body'}{'client'} = $client;
        bless $ser->{'body'}, 'Games::Lacuna::Client::Body';
    }

    if( exists $ser->{'server_data_age'} ) {
        $ser->{'server_data_age'} = DateTime->from_epoch( epoch => $ser->{'server_data_age'} );
    }

    given( $ser->{'type'} ) {
        when('space station') {
            bless $ser, 'Games::Lacuna::Client::Task::Station';
        }
        default {
            ### Handle both 'habitable planet' and 'gas giant'
            bless $ser, 'Games::Lacuna::Client::Task::Planet';
        }
    }
    bless $ser, __PACKAGE__;
    return $ser;
}#}}}
sub server_data_is_old {#{{{
    my $self  = shift;
    my $limit = shift;
    return 1 unless( defined $self->{'server_data_age'} and ref $self->{'server_data_age'} eq 'DateTime' );

    unless( $limit and ref $limit eq 'DateTime::Duration' ) {
        $limit = DateTime::Duration->new( hours => 8 );
    }

    my $now = DateTime->now();
    my $server_data_dur = $now->subtract_datetime( $self->{'server_data_age'} );
    return 1 if( DateTime::Duration->compare($server_data_dur, $limit, $now) > 0 );
    return 0;
}#}}}

1;
__END__

=head1 AUTHOR

Jonathan D. Barton, E<lt>jdbarton@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Jonathan D. Barton

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut

