use v5.14;
package Games::Lacuna::Client::Task::Planet;

use CHI;
use Data::Dumper;  $Data::Dumper::Indent = 1;
use DateTime;
use DateTime::Duration;
use Encode;
use List::Util;
use Moose;
use Try::Tiny;
use utf8;
with 'Games::Lacuna::Client::Task';

BEGIN {
    ### $Id: Planet.pm 14 2012-12-10 23:19:27Z jon $
    ### $URL: https://tmtowtdi.gotdns.com:15000/svn/LacunaWaX/trunk/lib/Games/Lacuna/Client/Task/Planet.pm $
    my $revision = '$Rev: 14 $';
    $Games::Lacuna::CLient::Task::Planet::VERSION = '0.2.' . join '', $revision =~ m/(\d+)/;
}

has 'id'    => ( isa => 'Int', is => 'rw', documentation => q{This is the game's ID, not my Planets.id} );
has 'name'  => ( isa => 'Str', is => 'rw' );
has 'chi'   => (
    is  => 'rw',
    isa => 'Object',
    lazy_build => 1,
    documentation => q{
        This is a direct reference to App.pm's chi.
        The key for every cache node accessed from within this file begins with 
        "Planet:" as a pseudo-namespace.
    },
);


### These attributes require a call to get_status, which is expensive.  A 
### single get_status call gets data for all of these attributes at once.
###
### So on the first accessor call to any of these, we'll call get_status, set 
### all of these attributes, and then update server_data_age to now(), which 
### will keep us from re-calling get_status again.
has 'server_data_age'   => (is => 'rw', isa => 'DateTime', lazy => 1, default => sub{ DateTime->new(year => 1970) } );
has 'body' => ( isa => 'Games::Lacuna::Client::Body', is => 'rw' );
has [
    'type', 'population', 'x', 'y', 'zone', 'size', 'star_id', 'happiness',
    'food_capacity', 'food_stored', 'food_hour', 'ore_capacity', 'ore_stored', 'ore_hour',
    'water_capacity', 'water_stored', 'water_hour', 'waste_capacity', 'waste_stored', 'waste_hour',
    'energy_capacity', 'energy_stored', 'energy_hour',
] => ( isa => 'Str', is => 'rw' );
has 'needs_surface_refresh' => (
    isa => 'Int', is => 'rw', default => sub{0},
    documentation => q{
        This is a boolean meant to indicate that I (the client) should re-call get_buildings 
        because something on the surface has changed.  It's pretty useless for the way I'm 
        doing stuff at this point.
    }
);
before [
    'body', 
    'type', 'population', 'x', 'y', 'zone', 'size', 'star_id', 'happiness',
    'food_capacity', 'food_stored', 'food_hour', 'ore_capacity', 'ore_stored', 'ore_hour',
    'water_capacity', 'water_stored', 'water_hour', 'waste_capacity', 'waste_stored', 'waste_hour',
    'energy_capacity', 'energy_stored', 'energy_hour',
    'needs_surface_refresh',
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
    my $c = $self->client;

    my $id = q{};
    if( defined $params->{'id'} ) {
        $id = $params->{id};
    }
    elsif( defined $params->{'name'} ) {
        $id = $c->planets->{ $params->{'name'} };
    }
    else {
        die "At least one of (id, name) is required.";
    }
    my $body_obj    = $c->call( $c, 'body', [id => $id] );
    my $body_status = $c->call( $body_obj, 'get_status' );
    $self->id  ( $body_status->{'body'}{'id'}   );
    $self->name( $body_status->{'body'}{'name'} );

    __PACKAGE__->meta->make_immutable;
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
sub _get_empire {#{{{
    my $self = shift;

### This needs to go away; a Planet is child to Empire (logically, at least).  
### So a Planet object should have no notion of its Empire.  
###
### This is currently not being used by anything in this file.  

    my $empire = ($self->client->no_cache)
        ? Games::Lacuna::Client::Task::Empire->new({ client => $self->client })
        : $self->chi->compute( (join ':', ('Planet', 'empire', $self->client->name)), {}, sub{ Games::Lacuna::Client::Task::Empire->new({ client => $self->client }) });

    $self->empire($empire);
    return $empire;

}#}}}

sub build_halls {#{{{
    my $self = shift;

=head2 build_halls

Creates as many Halls of Vrbansk as it can, up to a maximum of 50 halls per 
recipe.  If you have enough glyphs to make more than 50 of any given recipe, 
you'll need to call this multiple times.

 my $num_halls_built = $planet->build_halls;

=cut

    my $c = $self->client;
    my $arch_min = $self->get_buildings('Archaeology Ministry')->[0]; 

    my $glyphs = $self->enumerate_glyphs($arch_min);
    my $halls_built = 0;

    RECIPE:
    foreach my $recipe(@{$c->ute->hall_recipes}) {
        my $ingredient_count = 0;

        my $num_to_make = 5000;
        for my $ore(@$recipe) {
            next RECIPE unless $glyphs->{$ore}{'quantity'};
            $num_to_make = ($glyphs->{$ore}{'quantity'} < $num_to_make) ? $glyphs->{$ore}{'quantity'} : $num_to_make;
        }

        next RECIPE unless $num_to_make;
        my $rv = $c->call( $arch_min, 'assemble_glyphs', [$recipe, $num_to_make] );
        $c->log->debug("Built $num_to_make $rv->{'item_name'}.");
        $halls_built += $num_to_make;
    }

    return $halls_built;
}#}}}
sub build_ships {#{{{
    my $self = shift;

=head2 build_ships

Checks the Shipyard queue and Space Port.  If there's room in the SP and the 
Shipyard queue is under 3 jobs, and if a default ship has been assigned to this
planet in the client prefs, this will add job(s) to the queue.

Returns the number of ships added to the build queue.

Note the 'queue' does include the current working job.

Variable RPC
This is expensive.  And keep in mind that the numbers I'm giving here are for 
a planet with one shipyard and one space port; there can be multiples of each 
on a planet, and that will run the RPC count up higher.

Because this is expensive but loads up the queue a bit, it doesn't need to be 
run more often than once per hour, and probably less than that.

This is per planet:
    - This is probably no longer totally accurate but it once was so either 
      update or use the numbers here as a rule of thumb.
    - 3 RPC if the space port is full
    - 5 RPC if the job queue is full
    - 1 more for each ship added to the job queue

=cut

    my $c            = $self->client;
    my $me           = $c->users_schema->resultset('Login')->find({ username => $c->name });
    my $planet_prefs = $me->planet_prefs->find({ planet_name => $self->name }) or return 0;    # will happen on space stations
    my $all_prefs    = $me->planet_prefs->find({ planet_name => 'all' });

    my $requested_ship_type = $planet_prefs->shipyard || $all_prefs->shipyard;
    unless( $requested_ship_type ) {
        ### Don't use RPCs checking on existence of shipyards if there's no 
        ### default ship set.
        $c->log->debug($self->name . " does not have a default ship type set; skipping.");
        return 0;
    }

    my $space_ports = $self->get_buildings('Space Port'); 
    my $shipyards   = $self->get_buildings('Shipyard');

    $c->log->info("Checking shipyards on " . $self->name);
    unless( scalar @$space_ports and scalar @$shipyards ) {
        $c->log->debug($self->name . " is missing a space port or shipyard (or both)");
        return 0;
    }
    
    my $sp_slot_count = 0;
    SPACE_PORT:
    foreach my $sp( @$space_ports ) {
        my $sp_view = $c->no_cache
            ? $c->call($sp, 'view')
            : $self->chi->compute( "Planet:planet:" . $self->id . ":bldg:$sp->{'building_id'}:view", {}, sub{ $c->call($sp, 'view') });
        $sp_view or return 0;

        my $sp_level = $sp_view->{'building'}{'level'};
        if( $sp_level >= 1 ) {
            $sp_slot_count = $sp_view->{'docks_available'};
            last SPACE_PORT;
        }
    }
    unless( $sp_slot_count ) {
        $c->log->debug($self->name . " has no docks available.");
        return 0;
    }
    $c->log->debug($self->name . " has $sp_slot_count docks available.");

    ### If this many ships are already in the queue, we do nothing.
    my $min_ships_in_queue = 5;
    ### Otherwise, we add ships till the queue is this size.
    my $max_ships_in_queue = 10;

    my $added_to_queue = 0;
    SHIPYARD:
    foreach my $sy( @$shipyards ) {
        my $bq = $c->call($sy, 'view_build_queue');
        $bq->{'number_of_ships_building'} //= 0;
        if( $bq->{'number_of_ships_building'} >= $min_ships_in_queue ) {
            $c->log->debug("Multiple jobs already in queue; skipping.");
            next SHIPYARD;
        }

        ### If you've got a shipyard somewhere you want to skip adding ships 
        ### to for some reason (eg you plan to demolish it), uncomment the 
        ### following and update the x, y, and level appropriately.  Otherwise 
        ### leave the whole block commented; we don't need the $sy_view for 
        ### anything else and it's another server call.
        my $sy_view = $c->call($sy, 'view');
        if( 
            $self->name eq 'bmots6' 
            and $sy_view->{building}{x} == 3
            and $sy_view->{building}{y} == 2
            and $sy_view->{building}{level} == 13
        ) {
            $c->log->notice("SKIPPING SHIPYARD UPON REQUEST.  REMOVE THIS CODE WHEN THE SHIPYARD HAS BEEN DEALT WITH.");
            next SHIPYARD;
        }

        for( $bq->{'number_of_ships_building'} .. $max_ships_in_queue ) {
            $c->log->debug("Attempting to build a '$requested_ship_type'.");
            my $rv = eval{ $c->call($sy, 'build_ship', [$requested_ship_type]) };
            if($@) { return $added_to_queue; }
            $c->log->debug("Added $requested_ship_type to the shipyard build queue on " . $self->name);
            $added_to_queue++;
            if( --$sp_slot_count < 1 ) {
                return $added_to_queue;
            }
        }
    }
    return $added_to_queue;
}#}}}
sub change_layout {#{{{
    my $self   = shift;
    my $layout = shift;

=head2 change_layout

This should never be called from a scheduled task or from the web; it looks like
it's guaranteed (in its current form, at least) to always hit the RPC limit, so 
it'll need a sleep to do its work.

The GLC rearrange_buildings() requires its $layout to be like this:

 my $layout = [
  {
   id => INT,
   x => INT,
   y => INT,
  },
 ];

$layout for this sub (change_layout) is a hashref of the form:
 my $layout = [
  {
   old_x => INT,
   old_y => INT,
   new_x => INT,
   new_y => INT,
  },
 ];

...this saves you having to dig up the ID of the building you want to move; you just need 
to send this sub the x,y of the current building (old_x, old_y) and your desired new location 
(new_x, new_y).

The new_x, new_y coords must be available; you can't overlap buildings.

If you attempt multiple moves, all must be valid; this means:
    - The source coords must point to a movable building (not a planet's PCC, 
      or space station's CC, which both must stay at 0,0 )
    - The destination coords must be currently empty.

$layout is an arrayref, so it's processed in order.  So this would be valid (tested):
    { move bldg FROM 1,1 to $somewhere_else },
    { move bldg FROM $somewhere_other to 1,1 },

If any attempted move fails, _all_ moves fail.

=cut

    my $c    = $self->client;
    my $me   = $c->users_schema->resultset('Login')->find({ username => $c->name });
    my $body = $c->no_cache
        ? $c->call($c, 'body', [id => $self->id])
        : $self->chi->compute( "Planet:body:" . $self->id, {}, sub{ $c->call($c, 'body', [id => $self->id]) });

    my $num_moves = scalar @$layout;
    my $cnt       = 0;

    my $bldgs = $self->get_buildings();
    BUILDING:
    for my $b(@$bldgs) {
        my $hr = $c->call($b, 'view');
        for my $l(@$layout) {
            if( $l->{'old_x'} == $hr->{'building'}{'x'} and $l->{'old_y'} == $hr->{'building'}{'y'} ) {
                $l->{'id'} = $hr->{'building'}{'id'};
                $l->{'x'} = $l->{'new_x'};
                $l->{'y'} = $l->{'new_y'};
                $cnt++;
            }
        }
        last BUILDING if $cnt == $num_moves;
    }

    $c->log->info("Checking layout on " . $self->name);
    my $rv = $c->call( $body, 'rearrange_buildings', [$layout] );
    if( defined $rv->{'moved'} ) {
        my $ttl =  scalar @{$rv->{'moved'}};
        say "Moved $ttl buildings; be sure to refresh your browser to see the changes.";
        unless( $ttl == $num_moves ) {
            warn "Something did not move correctly; you likely overlapped a destination.";
        }
    }
    else {
        say "all moves failed";
    }
}#}}}
sub clear_cache {#{{{
    my $self = shift;
    $self->chi->clear() unless $self->client->no_cache;
}#}}}
sub dump_probes {#{{{
    my $self  = shift;
    my $stars = shift;

=pod

Abandons probes from a passed-in list of stars.  This should never be scheduled.

 my $stars = ['Sol', 'Sirius', 'Rao'];
 $planet->dump_probes( $stars );

Unfortunately, the Observatory's abandon_probe method does not return any 
indication of success or failure.  This means that every star passed in must be 
passed to the observatory on every planet in your empire to be sure that it has 
been abandoned.  This makes this method fairly RPC-intensive.

Calling this with a star list of 35 stars and six planets with Observatories 
used 215 RPCs.  So using it when needed isn't prohibitive.

Best bet is to keep up on it.  Fairly frequently, build up a list of 10 or 20 
stars whose probes can be abandoned and call this from a temporary script, 
hopefully doing this fairly close to the RPC reset time of midnight GMT.

This does have an empire component, so

 $empire->dump_probes( $stars );

will work as expected.  However, since no success or failure is indicated, the 
planet version cannot return a count of how many probes were abandoned.  It 
therefore always returns zero.  So the empire version will also return zero.

=cut

    my $c = $self->client;
    my $obs = $self->get_buildings('Observatory')->[0];
    unless(ref $obs eq 'Games::Lacuna::Client::Buildings::Observatory') {
        return 0;
    }

    $c->log->debug("Removing old probes from Observatory on " . $self->name);

    STAR:
    foreach my $s(@$stars) {
        my $star = $c->schema->resultset('Star')->find({ name => $s }) or next STAR;
        $c->log->debug("Attempting to abandon probe at star $s.");
        ### This just returns a status (of the current planet) hashref.  It's 
        ### identical whether the star in question had a probe that was 
        ### abandoned or not.
        my $rv = $c->call($obs, 'abandon_probe', [$star->id]);
    }
    return 0;
}#}}}
sub empty_trash {#{{{
    my $self = shift;
    my $c    = $self->client;

=head2 empty_trash

Takes out a planet's trash by sending a fleet of scows to the planet's star. 
Maximum number of ships in any fleet is 20.  Even if you have enough scows and 
enough trash to fill more than one complete fleet, this will only ever send
a single fleet.  

The planet's trash will generally not be reduced to zero; the "trash_run_at" 
preference indicates what percentage of the planet's maximum waste the user 
wishes to remain on-planet (a trash_run_at value of 5 means "leave 5% of the
total max").  

B<VARIABLE RPC>
Since switching this to send a fleet of scows rather than one-scow-at-a-time, 
I have not checked RPC usage.  

=cut

    unless( 
           $self->type eq 'habitable planet' 
        or $self->type eq 'gas giant' 
    ) {
        $c->log->info($self->name . " is not a habitable planet or gas giant; no trash to take out.");
        return 0;
    }
    $c->log->info("Checking waste situation on " . $self->name);

    my $me                = $c->users_schema->resultset('Login')->find({ username => $c->name });
    my $planet_prefs = $me->planet_prefs->find_or_create({ 
        planet_name => $self->name,
        Logins_id => $me->id
    });

    my $all_prefs      = $me->planet_prefs->find({ planet_name => 'all' });
    my $star_id        = $self->star_id;
    my $waste_stored   = $self->waste_stored;
    my $waste_capacity = $self->waste_capacity;
    my $remove_at_int  = $planet_prefs->trash_run_at || $all_prefs->trash_run_at || 0;
    my $remove_to_int  = $planet_prefs->trash_run_to || $all_prefs->trash_run_to || 0;

    unless( $remove_at_int and $remove_to_int ) {
        $c->log->info("User has not set trash removal preferences for this planet; skipping.");
        return 0;
    }

    my $remove_at_percent = int( $waste_capacity * ($remove_at_int/100) );
    my $remove_to_percent = int( $waste_capacity * ($remove_to_int/100) );

    if( $waste_stored < $remove_at_percent ) {
        $c->log->debug("Trash storage is under minimum capacity ($remove_at_percent); leaving it.");
       return 0;
    }
    $c->log->debug("Trash storage is over minimum capacity; taking it out if scows are available.");

    my $space_port     = $self->get_buildings('Space Port')->[0] or return 0;
    my $scows          = $self->get_ships('scow', ['Docked']);
    my $scows_large    = $self->get_ships('scow_large', ['Docked']);
    my $scows_mega     = $self->get_ships('scow_mega', ['Docked']);
    my $waste_in_holds = 0;
    my $max_waste_to_remove = $waste_stored - $remove_to_percent;
    my @fleet_ids = ();
    SCOW:
    foreach my $scow_id (keys %$scows_mega, keys %$scows_large, keys %$scows) {
        my $scow = $scows->{$scow_id};
        $waste_in_holds += $scow->{'hold_size'};
        if( $waste_in_holds < $waste_stored and $waste_in_holds <= $max_waste_to_remove ) {
            push @fleet_ids, $scow_id;
        }
        else {
            $waste_in_holds -= $scow->{'hold_size'};
            last SCOW;
        }
        last SCOW if scalar @fleet_ids == 20;
    }
    my $target = {'star_id' => $star_id};
    try {
        $c->call( $space_port, 'send_fleet', [\@fleet_ids, $target, 0])
    }
    catch {
        $c->log->error("Unable to send scow fleet from " . $self->name . " for unknown reason; skipping this planet entirely: $_");
        return scalar @fleet_ids;
    };
    $c->log->debug("Took out $waste_in_holds waste.");
    return scalar @fleet_ids;
}#}}}
sub enumerate_glyphs {#{{{
    my $self     = shift;
    my $c        = $self->client;

    my $arch_min = shift || $self->get_buildings('Archaeology Ministry')->[0];
    my $glyph_hr = shift;
    unless( $glyph_hr ) {
        $glyph_hr = $c->no_cache
            ? $c->call($arch_min, 'get_glyphs')
            : $self->chi->compute( (join ':', ('Planet', 'planet', $self->id, 'glyphs_hr')), {}, sub{ $c->call($arch_min, 'get_glyphs') });
    }

=pod

Glyphs come back from the server's get_glyphs as:

{
 'glyphs' => [
  {
    name => 'anthracite',
    quantity => '80',
    id => '8124',
    type => 'anthracite'
  },
  etc...
 ]
}

Any glyph type that the current colony has zero of will not appear in that 
structure at all, and the structure is not keyed by type.  Both of those are 
inconvenient.

This groups them up and returns them as:

 {
  anthracite => {
    quantity => '80',
    id => '8124'
  },
  sulfur => {
    quantity => '0',
    id => ''
  },
  etc...
 }

Note that the 'id' for sulfur, which for eg our planet currently has none of, is 
an empty string.  But the quantity has been forced to 0, which is accurate.  So 
check quantity for truth on any glyph type returned by this before attempting to 
use its 'id' key.


This will get the arch min and the glyphs for you, so you don't need to pass 
them in.  But if you've already got them, you may send them.  So these three 
all return the same value:

 my $enumerate_glyphs = $c->enumerate_glyphs();
 my $enumerate_glyphs = $c->enumerate_glyphs( $arch_min_object );
 my $enumerate_glyphs = $c->enumerate_glyphs( $arch_min_object, $arch_min_obj->get_glyphs );

=cut

    my $counts = {};
    map{ $counts->{$_} = {id => '', quantity => 0} }( $c->ute->ore_types() );
    foreach my $g( @{$glyph_hr->{'glyphs'}} ) {
        $counts->{$g->{'name'}} = { id => $g->{'id'}, quantity => $g->{'quantity'} };
    }

    return $counts;
}#}}}
sub fetch_spies {#{{{
    my $self            = shift;
    my $spies_by_planet = shift;
    my $space_port      = shift;
    my $ships           = shift;
    my $c               = $self->client;
    my $me              = $c->users_schema->resultset('Login')->find({ username => $c->name });

=head2 fetch_spies

Fetches (pulls) spies from other planets.  Returns the integer count of how 
many spies were fetched.

=head3 Arguments

B<spies_by_planet> - hashref: { planet_id => [spy_id, spy_id] } to indicate 
what planet contains what spies to be fetched.

B<space_port> - A single space port object as returned by get_buildings.  This 
is pseudo-optional; you can send undef and the space_port will be derived for 
you.  However I can't imagine how yo'd get the next required argument without 
a spaceport, so you may as well send it.

B<ships> - Arrayref of ship_ids to be used to fetch the spies.

=cut

    unless( $space_port ) {
        my $sp_arr = $self->get_buildings('Space Port');
        unless(scalar @$sp_arr) {
            $c->log->debug("Could not find a Space Port on " . $self->name);
            return 0;
        }
        $space_port = $sp_arr->[0];
    }

    my $cnt = 0;
    foreach my $pid( keys %$spies_by_planet ) {
        my $spy_ids = $spies_by_planet->{$pid};
        foreach my $id( @$spy_ids ) {
            my $ship_id = shift $ships;
            my $rv = $c->call( $space_port, 'fetch_spies', [$pid, $self->id, $ship_id, $spy_ids] );
            $cnt += @$spy_ids;
        }
    }
    return $cnt;

}#}}}
sub get_buildings {#{{{
    my $self          = shift;
    my $building_type = shift;
    my $c             = $self->client;

=pod

Gets buildings on this planet.

 $all = $planet->get_buildings();

...or...

 $just_mines = $planet->get_buildings('Mine');

...or, if you want an individual building...

 my $space_port = $planet->get_buildings('Space Port')->[0];

When you request a building type, you may request either by the user-friendly 
name ("Food Reserve"), or the internal shortname ("foodreserve").  In either 
case, the match is a case-insensitive regex, so you could search for "foo" to 
get Food Reserve buildings.

Don't shorten your search string too much, and be aware of duplicate 
possibilities.  If you search for "Training" you _will_ get all spy training 
facilities, but you'll also get the Pilot Training facility as well.  Caveat 
programmator.

If a building type is requested, but no matching buildings are found, returns 
an empty arrayref.  So if you're going for a single building, you can safely FAD 
the call as in the example:

 my $space_port = $planet->get_buildings('Space Port')->[0] or die "no SP";

$space_port will be undef if the planet has no space ports, but the FAD call 
won't explode on you.

=cut

    my $body = $c->no_cache
        ? $c->call($c, 'body', [id => $self->id, foo => 'bar'])
        : $self->chi->compute( (join ':',('Planet', "body", $self->id)), {}, sub{ $c->call($c, 'body', [id => $self->id, foo => 'bar']) });
    my $buildings = $c->no_cache
        ? $c->call($body, 'get_buildings', [foo => 'bar'])->{'buildings'}
        : $self->chi->compute( (join ':', ('Planet', "bldgs_hr",$self->id)), {}, sub{ $c->call($body, 'get_buildings', [foo => 'bar'])->{'buildings'} });
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
                    : $self->chi->compute( (join ':', ('Planet', "bldgs_obj", $self->id, $bldg_id)), {}, sub{ $c->call($c, 'building', [id => $bldg_id, type => $type_arg]) });
                $b or return [];
                push @$bldg_objs, $b;
            }
        }
        else {
            ### List all buildings on this body
            my $b = $c->no_cache
                ? $c->call($c, 'building', [id => $bldg_id, type => $type_arg])
                : $self->chi->compute( (join ':', ('Planet', "bldgs_obj", $self->id, $bldg_id)), {}, sub{ $c->call($c, 'building', [id => $bldg_id, type => $type_arg]) });
            $b or return [];
            push @$bldg_objs, $b;
        }
    }
    return $bldg_objs;

}#}}}
sub get_server_data {#{{{
    my $self = shift;
    my $c    = $self->client;

    my $body = $c->no_cache
        ? $c->call($c, 'body', [id => $self->id])
        : $self->chi->compute( (join ':', ('Planet', 'body', $self->id)), {}, sub{ $c->call($c, 'body', [id => $self->id]) });
    my $status = $c->no_cache
        ? $c->call($body, 'get_status')
        : $self->chi->compute( (join ':', ('Planet', 'body_status', $self->id)), {}, sub{ $c->call($body, 'get_status') });
    ($body and $status) or return;

    $self->{'body'} = $body;

    foreach my $k(qw(
        type population x y zone size star_id happiness 
        energy_capacity energy_stored energy_hour
        food_capacity food_stored food_hour
        ore_capacity ore_stored ore_hour
        waste_capacity waste_stored waste_hour
        water_capacity water_stored water_hour
        needs_surface_refresh
    )) {
        if( defined $status->{'body'}{$k} ) {
            $self->$k( $status->{'body'}{$k} );
        }
        else {
            $self->$k( 0 );
        }
    }
    return 1;
}#}}}
sub get_ships {#{{{
    my $self = shift;
    my( $ship_type, $tasks, $tags ) = @_;

=pod

Gets ships currently assigned to this planet.

 my $all_ships = $planet->get_ships();

 my $only_scows = $planet->get_ships('scow');

 my $only_docked_or_travelling_scows = $planet->get_ships( 'scow', ['docked', 'travelling'] );

 my $all_docked_ships = $planet->get_ships( '', ['docked'] );

 my $trade_ships = $planet->get_ships( undef, undef, 'trade' );

 my $trade_and_int_ships = $planet->get_ships( undef, undef, ['Intelligence', Trade'] );

=head2 Arguments

=head3 ship_type (optional, string)

Checked against both the internal ship type ("smuggler_ship") and the human type 
("Smuggler Ship").  In both cases the check is case-INsensitive.  So the 
following all return the same things:

 my $smugglers = $planet->get_ships('smuggler_ship');
 my $smugglers = $planet->get_ships('Smuggler Ship');
 my $smugglers = $planet->get_ships('muggle');   <- Retarded, but will work.

=head3 tasks (optional, arrayref)

Tasks you want the returned ships to be currently assigned to.  The tasks are 
also case-INsensitive, but partial spellings won't fly.

Legal tasks are: Docked, Travelling, Building, Mining, Defend.

=head3 tags (optional, string OR arrayref)

Tags describe the category of ship.  Legal values are 'Colonization', 
'Exploration', 'Trade', 'Intelligence', 'War', 'Mining'.

This argument is unique here in that it can be either a string or an arrayref.  
But (also unlike the other args), the tags arg is case-SENSITIVE.  This kind of 
php-like inconsistency is starting to piss me off.

=head2 Returns

Returns a hashref of ships.  Hashref is keyed on the ship_id, value is the full 
hashref describing the ship.  Each ship-describing hashref contains the keys:

=over 

=item* can_recall
=item* fleet_speed
=item* name
=item* task
=item* date_available
=item* stealth
=item* combat
=item* max_occupants
=item* can_scuttle
=item* speed
=item* hold_size
=item* payload
=item* type
=item* id
=item* type_human
=item* date_started

=back

=cut

### Internal Note
### view_all_ships() will also accept a 'tag' argument.  It's similar to 
### 'tasks'.  'tag' would let you specify 'Colonization', 'Exploration', 
### 'Trade', 'Intelligence', 'War', 'Mining'.  I'm not using that here because 
### I haven't found the need, but it's available if you want it in the future, 
### I expect as a third optional arrayref argument.

    my $c           = $self->client;
    my $space_ports = $self->get_buildings('Space Port') or return;
    my $space_port  = $space_ports->[0];
    my $paging      = {no_paging => 1};
    my $filter      = {};
    my $sp_id       = $space_port->{'building_id'};

    if( $tags ) {
        $filter = {tag => $tags};
    }

    my $ships = $c->no_cache
        ? $c->call( $space_port, 'view_all_ships', [$paging, $filter])->{'ships'}
        : $self->chi->compute( (join ':', ('Planet', "ships_hr",$sp_id)), {}, sub{ 
                my $hr = $c->call( $space_port, 'view_all_ships', [$paging, $filter]);
                ref $hr eq 'HASH' or return;
                return $hr->{'ships'};
            });
    ref $ships eq 'ARRAY' or do {
        $c->log->info("Space port view returned something other than an AoH.");
        return;
    };

    my $ret_ships = {};
    SHIP:
    foreach my $s(@$ships) {
        ### $ships is a LoH  right now; I want my retval to be a hr keyed on 
        ### ship ID.
        if( ref $tasks eq 'ARRAY' and @$tasks ) {
            next SHIP unless( /$s->{'task'}/i ~~ $tasks );
        }

        if( $ship_type ) {
            if( 
                   $s->{'type'} =~ /$ship_type/ 
                or $s->{'type_human'} =~ /$ship_type/ 
            ) {
                $ret_ships->{ $s->{'id'} } = $s;
            }
        }
        else {
            ### No specific type requested; return all.
            $ret_ships->{ $s->{'id'} } = $s;
        }
    }
    return $ret_ships;
}#}}}
sub get_spies {#{{{
    my $self    = shift;
    my $int_min = shift;
    my $fresh   = shift;
    my $c       = $self->client;
    my $me      = $c->users_schema->resultset('Login')->find({ username => $c->name });

=pod

Returns hashref of spies on this planet.

 my $spies = $planet->get_spies();

Getting spies requires querying the planet's Intelligence Ministry; if you've 
already done so in your calling code, you may pass that in to get_spies() to
save having to re-query the thing.

 my $int_min = $planet->get_buildings($body_id, 'Intelligence Ministry')->[0];
 my $spies   = $planet->get_spies( $int_min );

If you need to ensure that the spies returned are from a fresh call to the 
server and not from our cache, set the client's no_cache toggle to true, then 
unset it again afterwards to ensure the rest of your codes goes back to using 
the cache.

 $c->no_cache(1);
 my $spies = $planet->get_spies( $int_min );
 $c->no_cache(0);

Example return structure
 $VAR1 = {
    '91298' => {
        'pref_record' => Games::Lacuna::Webtools::Schema::Result::SpyPrefs object for this spy, or undef if no record exists.
        ...from here, the rest of the hashref is a standard Spy hashref; see object_dumps.txt.
    }
 };

B<Benchmark>

Spies are listed on multiple pages, 25 spies per page.  I'd previously been 
getting pages on an infinite loop until I got a page with no spies.  I've just 
found that the int min does return a current spy count if you view() it.  Using 
that count you can determine how many pages there are.

Testing this way against the old way resulted in either both methods taking 
about the same amount of time, or this method being about twice as fast.

=cut

    unless( ref $int_min and ref $int_min eq 'Games::Lacuna::Client::Buildings::Intelligence' ) {
        ### User didn't pass an $int_min so grab it
        my $int_arr = $self->get_buildings('Intelligence Ministry');
        return {} unless scalar @$int_arr;
        $int_min = $int_arr->[0];
        ref $int_min eq 'Games::Lacuna::Client::Buildings::Intelligence' or return {};
    }

    my $view = $c->no_cache
        ? $c->call($int_min, 'view')
        : $self->chi->compute( (join ':', ('Planet', 'planet', $self->id, 'building', $int_min->{'building_id'}, 'view')), {}, sub{ $c->call($int_min, 'view') } );
    $view or return {};

    my $spy_cnt = $view->{'spies'}{'current'};
    return {} unless $spy_cnt;
    my $pages = int($spy_cnt / 25) + 1;

    ### Caching the spies here is OK; we haven't added their SpyPrefs record 
    ### yet, and that's the part we can't cache.
    my $spies = $c->no_cache
        ? do {
            my $spies_call = $c->call( $int_min, 'view_all_spies' );
            if( ref $spies_call eq 'HASH' and defined $spies_call->{spies} ) {
                $spies_call->{spies};
            }
            else { [] }
        }
        : $self->chi->compute( (join ':', ('Planet', 'planet', $self->id, 'spies_ar')), {}, sub {
            my $spies_call = $c->call( $int_min, 'view_all_spies' );
            if( ref $spies_call eq 'HASH' and defined $spies_call->{spies} ) {
                $spies_call->{spies};
            }
            else { [] }
        });
    $spies or return {};

    my $ret_spies = {};
    foreach my $spy_hr(@$spies) {
        my $spy;
        unless( $spy = $me->spy_prefs->find({spy_id => $spy_hr->{'id'}}) ) {
            ### This spy was created in-game but my app has never seen him 
            ### before so there's no record of either him or his task.  Create 
            ### both.
            $spy = $me->spy_prefs->create({ spy_id => $spy_hr->{'id'} });
            my $task_none = $c->users_schema->resultset('Enum_SpyTasks')->find({ name => 'none' });
            $spy->task( $task_none );
            $spy->update;
        }
        $spy_hr->{'pref_record'} = $spy;

        ### Change $spies from LoH to hr keyed on ID.
        $ret_spies->{ $spy_hr->{'id'} } = $spy_hr;
    }
    return $ret_spies;
}#}}}
sub orig_get_spies {#{{{
    my $self    = shift;
    my $int_min = shift;
    my $fresh   = shift;
    my $c       = $self->client;
    my $me      = $c->users_schema->resultset('Login')->find({ username => $c->name });

=pod

Returns hashref of spies on this planet.

 my $spies = $planet->get_spies();

Getting spies requires querying the planet's Intelligence Ministry; if you've 
already done so in your calling code, you may pass that in to get_spies() to
save having to re-query the thing.

 my $int_min = $planet->get_buildings($body_id, 'Intelligence Ministry')->[0];
 my $spies   = $planet->get_spies( $int_min );

If you need to ensure that the spies returned are from a fresh call to the 
server and not from our cache, set the client's no_cache toggle to true, then 
unset it again afterwards to ensure the rest of your codes goes back to using 
the cache.

 $c->no_cache(1);
 my $spies = $planet->get_spies( $int_min );
 $c->no_cache(0);

Example return structure
 $VAR1 = {
    '91298' => {
        'pref_record' => Games::Lacuna::Webtools::Schema::Result::SpyPrefs object for this spy, or undef if no record exists.
        ...from here, the rest of the hashref is a standard Spy hashref; see object_dumps.txt.
    }
 };

B<Benchmark>

Spies are listed on multiple pages, 25 spies per page.  I'd previously been 
getting pages on an infinite loop until I got a page with no spies.  I've just 
found that the int min does return a current spy count if you view() it.  Using 
that count you can determine how many pages there are.

Testing this way against the old way resulted in either both methods taking 
about the same amount of time, or this method being about twice as fast.

=cut

    unless( ref $int_min and ref $int_min eq 'Games::Lacuna::Client::Buildings::Intelligence' ) {
        ### User didn't pass an $int_min so grab it
        my $int_arr = $self->get_buildings('Intelligence Ministry');
        return {} unless scalar @$int_arr;
        $int_min = $int_arr->[0];
        ref $int_min eq 'Games::Lacuna::Client::Buildings::Intelligence' or return {};
    }

    my $view = $c->no_cache
        ? $c->call($int_min, 'view')
        : $self->chi->compute( (join ':', ('Planet', 'planet', $self->id, 'building', $int_min->{'building_id'}, 'view')), {}, sub{ $c->call($int_min, 'view') } );
    $view or return {};

    my $spy_cnt = $view->{'spies'}{'current'};
    return {} unless $spy_cnt;
    my $pages = int($spy_cnt / 25) + 1;

    ### Caching the spies here is OK; we haven't added their SpyPrefs record 
    ### yet, and that's the part we can't cache.
    my $spies = $c->no_cache
        ? do {
            my $all_spies = [];
            for my $page (1..$pages) {
                my $spies_call = $c->call( $int_min, 'view_spies', [$page] );
                my $temp_spies = $spies_call->{'spies'};
                if(scalar @$temp_spies) {
                    push @$all_spies, @$temp_spies;
                }
            }
            $all_spies;
        }
        : $self->chi->compute( (join ':', ('Planet', 'planet', $self->id, 'spies_ar')), {}, sub {
                my $all_spies = [];
                for my $page (1..$pages) {
                    my $spies_call = $c->call( $int_min, 'view_spies', [$page] );
                    my $temp_spies = $spies_call->{'spies'};
                    if(scalar @$temp_spies) {
                        push @$all_spies, @$temp_spies;
                    }
                }
                $all_spies;
            });
    $spies or return {};

    my $ret_spies = {};
    foreach my $spy_hr(@$spies) {
        my $spy;
        unless( $spy = $me->spy_prefs->find({spy_id => $spy_hr->{'id'}}) ) {
            ### This spy was created in-game but my app has never seen him 
            ### before so there's no record of either him or his task.  Create 
            ### both.
            $spy = $me->spy_prefs->create({ spy_id => $spy_hr->{'id'} });
            my $task_none = $c->users_schema->resultset('Enum_SpyTasks')->find({ name => 'none' });
            $spy->task( $task_none );
            $spy->update;
        }
        $spy_hr->{'pref_record'} = $spy;

        ### Change $spies from LoH to hr keyed on ID.
        $ret_spies->{ $spy_hr->{'id'} } = $spy_hr;
    }
    return $ret_spies;
}#}}}
sub push_glyphs {#{{{
    my $self = shift;

=pod

Sends any glyphs currently on-planet to the planet assigned as your 
glyph_home, using the ship defined as your glyph_transport.  If no glyph_home 
or glyph_transport is assigned, nothing will be sent.

Returns the number of glyphs transported.

=cut

    my $c = $self->client;
    $c->log->info("Checking on pushing glyphs home from " . $self->name . ".");

    ### Check for Prefs table entry
    my $me   = $c->users_schema->resultset('Login')->find({ username => $c->name });
    my $planet_prefs = $me->planet_prefs->find_or_create({ 
        planet_name => $self->name,
        Logins_id   => $me->id
    });
    unless($planet_prefs) {
        $c->log->info("No prefs record found for " . $self->name . "; likely a Space Station.  Skipping.");
        return 0;
    }

    ### Check for valid glyph_home and glyph_transport settings in Prefs 
    ### table.
    my $all_prefs  = $me->planet_prefs->find({ planet_name => 'all' });
    my $glyph_home = $planet_prefs->glyph_home;
    unless( $glyph_home ) {
        $c->log->info("No glyph_home defined for this planet.");
        return 0;
    }
    if( $glyph_home eq '1' ) {
        if( $all_prefs->glyph_home ) {
            $glyph_home = $all_prefs->glyph_home;
            $c->log->info("Using the glyph home defined for all planets ($glyph_home).");
        }
        else {
            $c->log->info("User wants to use 'all' planet glyph_home, but has not defined one.  Skipping.");
            return 0;
        }
    }
    if( $self->name eq $glyph_home ) {
        $c->log->info("This planet _is_ our glyph home; skipping.");
        return 0;
    }
    unless( $planet_prefs->glyph_transport ) {
        $c->log->info("This planet has no glyph_transport defined; skipping.");
        return 0;
    }
    my $to = $self->new( client => $c, name => $glyph_home );
    unless( $to and ref $to eq 'Games::Lacuna::Client::Task::Planet' ) {
        $c->log->error("I was unable to get a valid planet to send glyphs to.");
        return 0;
    }
    $c->log->info("Attempting to push glyphs to $glyph_home.");

    ### Grab Trade Min to push from
    my $tm = $self->get_buildings('Trade Ministry')->[0];
    unless(ref $tm eq 'Games::Lacuna::Client::Buildings::Trade') {
        $c->log->info("Trade Ministry is bad or nonexistent: " . ref $tm . ".");
        return 0;
    }

    ### Get glyphs and ships lists
    ### "get_glyph_summary" below used to be "get_glyphs".
    ### As I write this, get_glyphs is still documented, but it doesn't work.  
    ### I have seen Icy make reference to this in chat.  Basically what he 
    ### said was "Yeah, use get_glyph_summary instead".
    my $glyphs = $c->no_cache
        ? $c->call($tm, 'get_glyph_summary')->{'glyphs'}
        : $self->chi->compute( (join ':', ('Planet', 'planet', $self->id, 'glyphs_hr')), {}, sub{ 
            $c->call($tm, 'get_glyph_summary')->{'glyphs'} 
          });
    my $ships = $c->no_cache
        ? $c->call($tm, 'get_trade_ships', [ $to->id ])
        : $self->chi->compute( (join ':', ('Planet', 'planet', $self->id, 'trade_ships_to' , $to->id)), {}, sub{ 
            $c->call($tm, 'get_trade_ships', [ $to->id ]) 
        });
    unless(@$glyphs and %$ships) {
        $c->log->debug("There were either no glyphs or no transport ships found on this body.");
        return 0;
    }

    ### Pull the right ship out of the list
    my $transport_ship = q{};
    SHIP:
    foreach my $ship( @{$ships->{'ships'}} ) {
        if( lc $planet_prefs->glyph_transport eq 'any' or lc $planet_prefs->glyph_transport eq 'all' ) {
            ### User doesn't care which ship we use, so just use the first.
            $transport_ship = $ship;
            last SHIP;
        }
        next SHIP unless lc $ship->{'name'} eq lc $planet_prefs->glyph_transport;
        $c->log->debug("Not using the 'all' meta-ship on this body; found ship by name.");
        $transport_ship = $ship;
    }
    unless( $transport_ship ) {
        $c->log->info("No appropriate transport ship was found for " . $self->name . "; no glyphs can be sent.");
        return 0;
    }

    ### Re-organize the glyphs list and make sure we don't have too many.
    my $quantity    = 0;
    my $send_glyphs = [];
    GLYPH:
    foreach my $g(@{ $glyphs }) {
        ### $glyphs, as returned from get_glyph_summary, is a AoH as:
        ###     { type => 'anthracite', quantity => 2 },
        ###     { type => 'gypsum', quantity => 5 }
        ###
        ### but push_items needs it to look like:
        ###     { type => 'glyph', name => 'anthracite', quantity => 2 }
        ###     { type => 'glyph', name => 'gypsum', quantity => 5 }
        $g->{'name'} = $g->{'type'};
        $g->{'type'} = 'glyph';
        $quantity   += $g->{'quantity'};

        if( $quantity * 100 > $transport_ship->{'hold_size'} ) {
            ### This will only happen rarely; each glyph takes up 100 hold 
            ### spaces, which is not much.  However, if the user has this 
            ### function turned off for a while, or they've accidentally 
            ### deleted their assigned glyph transport ship, or whatever, it's 
            ### possible to have more glyphs than the transport ship can hold.  
            ### If you try sending too many, the ship simply won't be sent at 
            ### all and glyphs will continue to silently build up.  So just 
            ### send the bunch we've already got loaded onto the ship, and the 
            ### next bunch will be sent on the next run.
            $quantity -= $g->{'quantity'};
            last GLYPH;
        }
        push @$send_glyphs, $g;
    }

    ### Should be good to go - send.
    my $rv = try {
        $c->call($tm, 'push_items', [ $to->id, $send_glyphs, {ship_id => $transport_ship->{'id'}} ]);
    }
    catch {
        $c->log->error("push_items failed.  To_id: " . $to->id . ", Ship ID: $transport_ship->{'id'}.");
        $c->log->error("---" . (Dumper $send_glyphs) . "---" );
        return {};
    };

    if( defined $rv->{'ship'} ) {
        my $ship_name = $rv->{'ship'}->{'name'}         || "ship name unknown";
        my $dest_name = $rv->{'ship'}->{'to'}{'name'}   || "dest name unknown";
        my $date_arrv = $rv->{'ship'}->{'date_arrives'} || "arrv date unknown";
        $c->log->debug("$ship_name sent to $dest_name carrying $quantity glyphs, will arrive at $date_arrv.");
    }
    else {
        $quantity = 0;
        last SHIP;
    }

    $c->log->info("Pushed home $quantity glyphs.");
    return $quantity;
}#}}}
sub recycle {#{{{
    my $self = shift;

=head2 recycle


I removed this from the scheduler somewhere in early 02/2012.  The code 
worked fine for a good while, I just removed it because it was using time and 
RPCs and wasn't accomplishing much.

Though it worked when I removed the call, it likely hasn't been updated much 
in the time since (adding cache etc).  Give it some love before attempting to 
use it again.




Checks all of a planet's recycling centers.  Each one that's not currently in 
use will begin recycling up to one hour's worth of waste (or all the waste 
that's left, if that will take under an hour) into whatever resource is 
currently at its lowest.

Returns the number of recyclers it started.  Usually 1 or 0, but it is possible 
to have > 1 recycler on a planet.

TBD
Add checks for Waste Exchanger to this once I level up enough to build one.

VARIABLE RPC
- Takes least 1 RPC
- Additionally, for each recycling center:
    - If the center is busy, 1 more RPC
    - If the center is not busy and this sub gets it running, 2 more RPCs

So: 
    - for a planet with 1 treatment center that's already busy, this takes 2 RPCs.
    - for a planet with 1 treatment center that's not already busy, this takes 3 RPCs.

=cut

    my $c            = $self->client;
    my $me           = $c->users_schema->resultset('Login')->find({ username => $c->name });
    my $planet_prefs = $me->planet_prefs->find_or_create({
        planet_name => $self->name,
        Logins_id => $me->id
    });
    my $all_prefs    = $me->planet_prefs->find({ planet_name => 'all' });

    $c->log->info("Checking recycling centers on " . $self->name);
    $c->log->debug("    Getting recycling center objects...");
    my $wrcs = $self->get_buildings('Waste Recycling Center');
    $c->log->debug("    ...done");

    my $rec_for = $planet_prefs->recycle_for || $all_prefs->recycle_for || 0;
    unless( $rec_for ) {
        $c->log->debug("No recycling requested; exiting.");
        return 0;
    }

    my $recyclers_started = 0;
    CENTER:
    foreach my $wrc(@{$wrcs}) {
        $c->log->debug("    Getting recycling center view...");
        my $view     = $c->call($wrc, 'view');
        $c->log->debug("    ...done");
        my $recycler = $view->{'recycle'};

        ### Always leave a little for waste management blgs to chew on
        ### TBD is this really necessary?
        next CENTER if $view->{'status'}{'body'}{'waste_stored'} < 5000;

        unless($recycler->{'can'}) {
            $c->log->debug("Recycling center is busy.");
            next CENTER;
        }

        ### Recycle to the resource we have least of in storage
        my $lowest = {
            type          => 'ore', # ore here is arbitrary; must init $lowest to some resource.
            count         => $view->{'status'}{'body'}{'ore_stored'},
            capacity_left => $view->{'status'}{'body'}{'ore_capacity'} - $view->{'status'}{'body'}{'ore_stored'},
        };
        foreach my $resource_type( qw(ore water energy) ) { # cannot recycle to food.
            if($view->{'status'}{'body'}{"${resource_type}_stored"} < $lowest->{'count'}) {
                @{$lowest}{qw(type count capacity_left)} 
                = (
                    $resource_type, 
                    $view->{'status'}{'body'}{"${resource_type}_stored"},
                    $view->{'status'}{'body'}{"${resource_type}_capacity"} - $view->{'status'}{'body'}{"${resource_type}_stored"},
                );
            }
        }
        my $amt_to_recycle = 0;
        if( $recycler->{'seconds_per_resource'} ) {
            my $rec_per_hour = int( 3600 / $recycler->{'seconds_per_resource'} );

            my $rec_requested = $rec_per_hour * $rec_for - (2 * 60);
            next CENTER unless $rec_requested > 0;

            $amt_to_recycle = ($view->{'status'}{'body'}{'waste_stored'} > $rec_requested)
                ? $rec_requested : $view->{'status'}{'body'}{'waste_stored'};
        }
        else { die "Unable to get recycler data: unknown error."; }

        ### Don't run recycler if storage is maxed.
        if( $amt_to_recycle > $lowest->{'capacity_left'} ) {
            $c->log->debug("Not enough $lowest->{'type'} storage left to bother recycling.");
            next CENTER;
        }

        ### Args to recycle() are hokey; see
        ### https://us1.lacunaexpanse.com/api/WasteRecycling.html
        my $args = [];
        given( $lowest->{'type'} ) {
            when('water')  { $args = [$amt_to_recycle, undef,           undef] }
            when('ore')    { $args = [undef,           $amt_to_recycle, undef] }
            when('energy') { $args = [undef,           undef,           $amt_to_recycle] }
            default        { die "Lowest resource type unknown"; }
        }
        $c->log->debug("Recycling $amt_to_recycle $lowest->{'type'} on " . $self->name);
        $c->call($wrc, 'recycle', $args);
        $recyclers_started++;
    }
    return $recyclers_started;
}#}}}
sub res_push {#{{{
    my $self = shift;

=pod

bmots: 157231
bmots6: 184926

Pushes resources to a target.

=cut

    my $c      = $self->client;
    my $me     = $c->users_schema->resultset('Login')->find({ username => $c->name });
    my $rp_rs  = $me->res_pushes->search({from => $self->id });
    my $pushed = 0;

    my $tz = $me->game_prefs->time_zone or do {
        $c->log->error("No player time zone set for " . $me->username . "; I don't know when I'm supposed to push resources.");
        return $pushed;
    };
    my $now = DateTime->now( time_zone => $tz );

    RES_PUSH:
    while( my $rp = $rp_rs->next ) {
        $c->log->debug("Time now is " . $now->hour . " -- current res_push wants to go at " . $rp->hour . ".");
        next RES_PUSH unless $now->hour == $rp->hour;
        $c->log->debug("Time to push " . $rp->res . " from " . $rp->from_planet->name . " to " . $rp->to_planet->name . ".");
        
        my $tm = $self->get_buildings('Trade Ministry')->[0];
        ref $tm eq 'Games::Lacuna::Client::Buildings::Trade' or do {
            $c->log->error("No Trade Ministry found on " . $self->name . " - unable to push resources.");
            return $pushed;
        };

        my $ships = $c->call($tm, 'get_trade_ships', [ $rp->to_planet->game_id ]);
        SHIP:
        foreach my $ship( @{$ships->{'ships'}} ) {#{{{
            next SHIP unless lc $ship->{'name'} eq lc $rp->ship;

            my $items = [{
                type     => lc $rp->res,    # Res name apparently _must_ be all lc.
                quantity => $ship->{'hold_size'},
            }];
            
            my $rv = try {
                $c->log->debug("Sending ship right now.");
                $c->log->debug("to_planet id: " . $rp->to_planet->game_id . "(" . $rp->to_planet->name . ")");
                $c->log->debug("ship id: $ship->{'id'}");
                return $c->call($tm, 'push_items', [ $rp->to_planet->game_id, $items, {ship_id => $ship->{'id'}} ]);
            }
            catch {
                $c->log->error("Error pushing to " . $rp->to_planet->name . "; likely insufficient resources.");
                next RES_PUSH;
            };
            if( defined $rv->{ship} ) {
                $pushed++;
                $c->log->debug("$rv->{ship}{name} sent to $rv->{ship}{to}{name} with $rv->{ship}{payload}[0]; arrives at $rv->{ship}{date_arrives}.");
            }
            else {
                ### If, for example, you attempt to send "Milk" instead of 
                ### "milk", you'll end up here.  No error is given.
                $c->log->error("Res push did not generate an error, but didn't push any res either.  No explanation why.");
            }
            ### So if there are multiple ships with the same name, we'll still 
            ### only push one ship per $rp.
            next RES_PUSH;
        }#}}}
    }

    return $pushed;
}#}}}
sub search_for_glyphs {#{{{
    my $self = shift;
    my $c    = $self->client;
    my $me   = $c->users_schema->resultset('Login')->find({ username => $c->name });

    $c->log->info("Checking Archaeology Ministry on " . $self->name);

=head2 search_for_glyphs

Checks the planet's Archaeology Ministry to see if it's currently searching 
for a glyph.  If it isn't, a search is begun.

Returns the number of new searches begun.  Since a planet can only have one 
Archaeology Ministry, which can only be searching for one glyph at a time, 
this will return either 1 or 0.

=cut

    unless($self->type eq 'habitable planet' or $self->type eq 'gas giant') {
        ### Skip SS
        $c->log->info($self->name . " is not a habitable planet so it can't have an Arch Min.  Skipping.");
        return 0;
    }

    my $planet_prefs = $me->planet_prefs->find({planet_name => $self->name }) or do {
            ### This will happen for space stations, brand-new users who 
            ### haven't submitted a profile page yet (and thereby created 
            ### planet pref records), and existing users who've created new 
            ### planets but, again, haven't hit the profile page since then.
            $c->log->info("No prefs record for '" . $self->name . ".");
            return 0;
        };
    unless( $planet_prefs->search_archmin ) {
        $c->log->info("User specifically does not want this arch min searched.  Skipping.");
        return 0;
    }

    my $ore_to_search = q{};
    if( $planet_prefs->search_archmin =~ /^[a-z]+$/ ) {
        $ore_to_search = $planet_prefs->search_archmin;
        $c->log->info("User has requested we search for '$ore_to_search' glyphs.");
    }

    my $arch_min = $self->get_buildings('Archaeology Ministry')->[0] or do{ $c->log->info("Could not find an Arch Min."); return 0;};
    my $view = $c->no_cache
        ? $c->call($arch_min, 'view')
        : $self->chi->compute( 
            (join ':', ('Planet', 'planet', $self->id, 'building', $arch_min->{'building_id'}, 'view')), 
            {}, 
            sub{ $c->call($arch_min, 'view') }
        );
    $view or do {
            $c->log->info("Could not get view of arch min");
            return 0;
        };

    $c->log->debug($self->name . " does have an Archaeology Ministry (level $view->{'building'}{'level'}).");
    if( my $work = $view->{'building'}{'work'} ) {
        $c->log->debug("It's searching for a $work->{'searching'} glyph right now.");
        $c->log->debug(" >>> That search will complete in $work->{'seconds_remaining'} seconds.");
        return 0;
    }

    $c->log->debug("Arch Min is available to search for a new glyph.");

    my $ores = $c->call($arch_min, 'get_ores_available_for_processing');
    unless( defined $ores->{'ore'} and %{$ores->{'ore'}} ) {
        $c->log->debug("Not enough of any type of ore to perform an Arch Min search on here.");
        return 0;
    }
    $ores = $ores->{'ore'};
    if( $ore_to_search and not defined $ores->{$ore_to_search} ) {
        $c->log->info("Not enough $ore_to_search to perform a glyph search.");
        $ore_to_search = q{};
    }

    unless( $ore_to_search ) {
        ### Either the user didn't specify an ore type, or they did and 
        ### there's not enough of it here to perform a search.  Pick an ore 
        ### type at random and search that.
        $ore_to_search = each $ores;
        keys %$ores;    # Reset $ores after each.
        $c->log->debug("No available ore specified; 'randomly' searching for $ore_to_search.");
    }

    if( $ore_to_search ) {
        $c->log->debug("Now searching for a $ore_to_search glyph, as requested.");
        try {
            my $rv = $c->call( $arch_min, 'search_for_glyph', [$ore_to_search] );
            ### $rv will be undef if this failed to perform a search.  Docs 
            ### say it'll be an $arch_min->view on success, but all my AMs are 
            ### searching right now so I can't confirm.
            ###
            ### Either way, the catch block will only trigger on a true error, 
            ### not just on a failure to perform a search.
        }
        catch {
            $c->log->warning("Unable to search $ore_to_search for a glyph because '$_'");
            return 0;
        };
        return 1;
    }

    $c->log->debug("We shouldn't ever be able to reach this point.");
    return 0;

}#}}}
sub get_my_spy_trades {#{{{
    my $self = shift;
    my $c    = $self->client;
    my $me   = $c->users_schema->resultset('Login')->find({ username => $c->name });

=pod

Returns a list (not a ref) of all spy trades posted by the current empire.  
Note that while view_my_market() in the official API only returns trades 
posted by the current Body, this method does return all of this Empire's 
trades.

The array returned contains hashrefs describing each individual trade; these 
hashrefs are described in object_dumps.txt; see "Merc Guild Trades".

=cut

    my @my_trades = ();

    my $mg = $self->get_buildings('Mercenaries Guild')->[0] or do {
        $c->log->debug("No mercs guild on " . $self->name);
        return @my_trades;
    };

    my $page = 0;
    my $last_page = 0;
    TRADE_PAGE:
    while(1) {
        $page++;

        my $all_trades = $c->no_cache
            ?  $c->call( $mg, 'view_market', [$page] )
            : $self->chi->compute( (join ':', ('Planet', 'spy_trades', $page)), {}, sub{ $c->call($mg, 'view_market', [$page]) });

        foreach my $trade( @{$all_trades->{'trades'}} ) {
            if( $trade->{'empire'}{'name'} eq $c->name ) {
                push @my_trades, $trade;
            }
        }
        unless( $last_page ) {
            $last_page = int($all_trades->{'trade_count'} / 25);
            $last_page++ if $all_trades->{'trade_count'} % 25;
        }
        last TRADE_PAGE if( $page >= $last_page );
        if($page > 10) {
            $c->log->debug("Giving up after looking at 10 pages of Merc trades; cowardly avoiding an infinite loop.");
            last TRADE_PAGE;
        }
    }

    return @my_trades;
}#}}}
sub train_spies {#{{{
    my $self  = shift;
    my $c     = $self->client;
    my $me    = $c->users_schema->resultset('Login')->find({ username => $c->name });
    my $spies = $me->spy_prefs;
    my $cnt   = 0;

    $c->log->info("Checking on spy training for planet " . $self->name);

    my $planet_prefs = $me->planet_prefs->find_or_create({ 
        planet_name => $self->name,
        Logins_id => $me->id
    });
    unless( $planet_prefs->train_spies ) {
        $c->log->info("User has requested not to train spies on this planet.");
        return 0;
    }

    my $training_bldgs = $self->get_buildings('training');
    ### $training_bldgs will contain all buildings with 'training' in their 
    ### names (including Pilot Training Facility), so we do still need to 
    ### filter it.
    my @spy_trainers = qw(intel politics mayhem theft);

    BLDG:
    foreach my $b( @$training_bldgs ) {
        my $type = $b->{'uri'} =~ s{.*/(\w+)training}{$1}r;
        next BLDG unless grep{ /^$type$/ }@spy_trainers;
        $c->log->info("Got a $type building.");

        ### $avail_spies are spies available according to the training building 
        ### (not my database).  It's an AoH, one H per spy, with the keys 'time' 
        ### (seconds that will be taken by training) and 'spy_id'
        #my $avail_spies = $c->call( $b, 'view' )->{'spies'}{'training_costs'}{'time'};

        ### It's unlikely we'll ever pull this out of the cache again, but what 
        ### the hell.
        my $view = $c->no_cache
            ? $c->call($b, 'view')
            : $self->chi->compute( (join ':', ('Planet', 'planet', $self->id, 'building', $b->{'building_id'}, 'view')), {}, sub{ $c->call($b, 'view') });
        $view or return;
        my $avail_spies = $view->{'spies'}{'training_costs'}{'time'};
        $c->log->info(scalar @$avail_spies . " spies available to this building.");

        SPY:
        foreach my $s(@$avail_spies) {
            my $spy_prefs = $me->spy_prefs->find({ spy_id => $s->{'spy_id'} }) or next SPY;

            $c->log->debug("Spy $s->{'spy_id'} wants to do task " . $spy_prefs->task->name);
            if( $spy_prefs->task->name =~ /$type/ ) {
                my $rv = $c->call( $b, 'train_spy', [$s->{'spy_id'}] );
                if( $rv->{'trained'} ) {
                    $c->log->debug("Started $type training for spy " . $spy_prefs->spy_id);
                    $cnt++;
                }
            }
        }
    }

    return $cnt;
}#}}}
sub update_observatory {#{{{
    my $self = shift;

=head2 update_observatory

If the planet has an observatory, this reads its current probe data and records 
it in the Planets table.

Returns the combined count of inserts and updates performed.

=cut

    my $c = $self->client;

    $c->log->info("Checking for Observatory on " . $self->name);
    my $obs = $self->get_buildings('Observatory')->[0];   # 2 RPC
    unless($obs and ref $obs eq 'Games::Lacuna::Client::Buildings::Observatory') {
        $c->log->debug($self->name . " appears not to have an observatory.");
        return 0;
    }

    my $cnt  = 0;
    my $page = 0;

    ### The infinite loop here is necessary.  The Int Min will tell you how 
    ### many spies you've got built, so for that we can derive the number of 
    ### pages and not need to do the infinite page-turning loop.  But the 
    ### Observatory does not (as of 12/14) tell you how many probes you've got 
    ### out, so you can't calculate the number of pages you need to hit based 
    ### on the number of probes.  So we have to turn pages till we get either 
    ### a non-full page or a blank.

    PAGE:
    while(1) {
        $page++;
        my $s = $c->call($obs, 'get_probed_stars', [$page]); # 1 RPC
        last PAGE unless $s and ref $s eq 'HASH';
        last PAGE unless scalar @{$s->{'stars'}}; # Requested a page with no data, ie we're done.
        foreach my $probed_star( @{$s->{'stars'}} ) {
            foreach my $body( @{$probed_star->{'bodies'}} ) {
                $body->{'current'} = 1;
                $cnt += $c->insert_or_update_body_schema($body);
            }
        }
        $c->log->debug( scalar @{ $s->{'stars'} } . " on page $page at " . $self->name );
        last PAGE if( scalar @{$s->{'stars'}} < 25 );
    }
    $c->log->debug("$cnt Planet table updates for " . $self->name);
    return ($cnt);
}#}}}

sub serialize {#{{{
    my $self = shift;

=head2 serialize

Returns the data describing the current planet object as a hashref.  Objects 
normally embedded in the planet object (eg the $client object) are removed or 
themselves serialized.

Returns a plain, unblessed hashref which can be cached or otherwise stored, 
and rehydrated later by sending it to deserialize.

What makes creation of a planet object slow is the call to get_server_data(), 
which is needed to (among other things) determine whether the given body is 
actually a planet or a space station.  Serializing a planet object that has 
not yet called get_server_data() is silly, pointless, and even dangerous, 
because we won't know when re-serializing the thing whether we should return a 
Planet object or a Station object.

So, before the planet object is serialized, this method will ensure 
get_server_data has been called on the planet, and will call it for you if you 
haven't done it yourself.

=cut

    ### Need massaging:
    ###
    ###     $self->client   Games::Lacuna::Client::App
    ###         This points at $self->body->{client}, below
    ###
    ###     $self->body     Games::Lacuna::Client::Body
    ###         ->{client}  Games::Lacuna::Client::App
    ###
    ###     $self->server_data_age   DateTime

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

=head2 deserialize

Given a hashref as returned by serialize and a Games::Lacuna::Client::App 
($client) object, transmogrifies that hashref into I<either> a 
Games::Lacuna::Client::Task::Planet  or Games::Lacuna::Client::Task::Station 
object.

 my $hashref = $planet->serialize();

 ...time passes...

 my $reconstituted_planet_object = Games::Lacuna::Client::Task::Planet->deserialize(
    $hashref, $client
 );

This is a static method only, but can be invoked via an empire object, which 
you've probably already got lying around:

 my $reconstituted_planet_object = $empire->deserialize_planet( $hashref );

After deserializing a planet object, be careful about using any attributes 
that may be time-sensitive.  You can check the age of the planet object, just 
as with any planet object, and refresh the server data if needed:

 if( $reconstituted_planet_object->server_data_is_old() ) {
  $reconstituted_planet_object->get_server_data();
 }

=cut

    if( $proto and ref $proto eq 'Games::Lacuna::Client::Task::Planet' ) {
        $client = $proto->client;
    }

    unless( ref $client eq 'Games::Lacuna::Client::App' ) {
        die "Second arg to deserialize must be client object -" . (ref $client) . '-';
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
    return $ser;
}#}}}
sub server_data_is_old {#{{{
    my $self  = shift;
    my $limit = shift;
    return 1 unless( defined $self->{'server_data_age'} and ref $self->{'server_data_age'} eq 'DateTime' );

=head2 server_data_is_old 

Indicates whether the current planet's server data is getting old.

By default, 'old' means 'more than 8 hours':

 if( $planet->server_data_is_old ) {
  # Server data was last grabbed more than 8 hours ago; it may be time for
  # a refresh.
  $planet->get_server_data;
 }

You can define 'old' as you wish by passing a DateTime::Duration object:

 my $limit = DateTime::Duration->new( hours => 2 );
 if( $planet->server_data_is_old($limit) ) {
  say "Your planet's data is over 2 hours old.";
 }

=cut

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

### POD {#{{{

=head1 NAME

Games::Lacuna::Client::Task::Planet - Manage tasks specific to a particular 
planet in your empire

=head1 SYNOPSIS

Old docs are old.

 my $client = Games::Lacuna::Client::App->new({ cfg_file => $client_file });
 my $planet = Games::Lacuna::Client::Task::Planet->new({
     client => $client,
     name => 'my_planet_name',
 });

 $seconds_remaining = $planet->search_for_glyphs;
 say "$seconds_remaining seconds left on the current search.";

 $records_changed = $planet->update_observatory;
 say "$records_changed records updated/inserted.";

 $scows_sent = $planet->empty_trash;
 say $scows_sent;

 $ships_added_to_queue = $planet->build_ships;
 say $ships_added_to_queue;

 $recyclers_started = $planet->recycle;
 say $recyclers_started;

=head1 DESCRIPTION

Performs a number of common, often tedious tasks specific to a given planet.  
Most users won't use this module at all, but will prefer 
L<Games::Lacuna::Client::Task::Empire>, which will perform all of these 
planet-specific tasks once for each planet in their empire, as well as a few 
other empire-specific tasks.

=head1 HISTORY

=head2 0.2.rev

Removed the sort-by-distances nonsense that send_excavators was doing.  API 
remains unchanged.

*sigh* I'm really being bad about keeping track of the history.  Refer to SVN 
notes instead of this; it's wildly out of date.

=head2 0.1.rev

First version

=head1 Attributes

=head2 cfg_file

Path to the client config file containing your login, password, etc.  Must be 
passed to the constructor.

=head2 id, name

At least one of these must be passed to the constructor.  If both are passed, 
the id, being more specific, is assumed to be authoritative.

=head1 Methods

=cut

### }#}}}

=head1 AUTHOR

Jonathan D. Barton, E<lt>jdbarton@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Jonathan D. Barton

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut

