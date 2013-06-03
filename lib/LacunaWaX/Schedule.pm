use v5.14;

=pod

The Lottery and Autovote functions have both been cleaned up, and live in 
their own classes under the LacunaWaX::Schedule:: namespace now.

The other scheduled functions need to be moved under there too.  See those two 
already-fixed classes for inspiration.

=cut

package LacunaWaX::Schedule {
    use Carp;
    use Data::Dumper;
    use LacunaWaX::Model::Container;
    use LacunaWaX::Model::Mutex;
    use LacunaWaX::Model::Client;
    use List::Util qw(first);
    use LWP::UserAgent;
    use Memoize;
    use Moose;
    use Try::Tiny;

    use LacunaWaX::Model::Lottery::Links;       # this should go away.
    use LacunaWaX::Schedule::Autovote;
    use LacunaWaX::Schedule::Lottery;

    has 'bb'            => (is => 'rw', isa => 'LacunaWaX::Model::Container',   required    => 1);
    has 'schedule'      => (is => 'rw', isa => 'Str',                           required    => 1);
    has 'mutex'         => (is => 'rw', isa => 'LacunaWaX::Model::Mutex',       lazy_build  => 1);
    has 'game_client'   => (is => 'rw', isa => 'LacunaWaX::Model::Client',
        documentation =>q{
            Not a lazy_build, but still auto-generated (in connect()).  No need to pass this in.
        }
    );

    ### CONSTANTS
    sub GLYPH_CARGO_SIZE()  { 100 }                                 ## no critic qw(ProhibitSubroutinePrototypes RequireFinalReturn)
    sub TRAINING_TYPES()    { qw(Intel Mayhem Politics Theft) }     ## no critic qw(ProhibitSubroutinePrototypes RequireFinalReturn)

    sub BUILD {
        my $self = shift;

        my $logger = $self->bb->resolve( service => '/Log/logger' );
        $logger->component('Schedule');
        $logger->info("# -=-=-=-=-=-=- #"); # easier to visually find the start of a run in the Log Viewer
        $logger->info("Scheduler beginning with task '" . $self->schedule .  q{'.});

        ### ex lock for the entire run might seem a little heavy-handed.  But 
        ### I'm not just trying to limit database collisions; I'm also 
        ### limiting simultaneous RPCs; multiple schedulers firing at the same 
        ### time could be seen as a low-level DOS.
        $logger->info($self->schedule . " attempting to obtain exclusive lock.");
        unless( $self->mutex->lock_exnb ) {
            $logger->info($self->schedule . " found existing scheduler lock; this run will pause until the lock releases.");
            $self->mutex->lock_ex;
        }
        $logger->info($self->schedule . " succesfully obtained exclusive lock.");

        given( $self->schedule ) {
            when('archmin') {
                $self->archmin;
            }
            when('autovote') {
                $self->autovote;
            }
            when('lottery') {
                $self->lottery;
            }
            when('train_spies') {
                $self->train_spies;
            }
            when('test') {
                $self->test;
            }
            default {
                $logger->error("Requested scheduled task $_, but I don't know what that is.");
            }
        }

        $self->mutex->lock_un;

        $logger->info("Scheduler run of task " . $self->schedule . " complete.");
        return $self;
    }
    sub _build_mutex {#{{{
        my $self = shift;
        return LacunaWaX::Model::Mutex->new( bb => $self->bb, name => 'schedule' );
    }#}}}
    sub game_connect {#{{{
        my $self      = shift;
        my $server_id = shift;

        ### This will fail if the user hasn't filled out their creds yet, which 
        ### includes if they haven't got a PT account.
        my $client = try {
            LacunaWaX::Model::Client->new (
                bb          => $self->bb,
                server_id   => $server_id,
                interactive => 0,
                allow_sleep => 1,   # allow to sleep 60 seconds on RPC Limit error
                rpc_sleep   => 2,   # time to sleep between each request
            )
        }
        catch {
            return;
        };

        return unless $client;

        $self->game_client( $client );
        return $self->game_client->ping;
    }#}}}

    sub archmin {#{{{
        my $self = shift;

        my $logger = $self->bb->resolve( service => '/Log/logger' );
        $logger->component('Archmin');

        my $schema      = $self->bb->resolve( service => '/Database/schema' );
        my @server_recs = $schema->resultset('Servers')->search()->all;

        SERVER:
        foreach my $server_rec( @server_recs ) {#{{{
            my $server_searches         = 0;
            my $server_glyphs_pushed    = 0;

            $logger->info("Checking Arch Mins on server " . $server_rec->id);
            if( my $server = $schema->resultset('Servers')->find({id => $server_rec->id}) ) {
                unless( $self->game_connect($server->id) ) {
                    $logger->info("Failed to connect to " . $server->name . " - check your credentials!");
                    next SERVER;
                }
            }
            else {
                next SERVER;
            }

            my @am_recs = $schema->resultset('ArchMinPrefs')->search({server_id => $server_rec->id})->all;
            $logger->info("User has Arch Min pref records on " . @am_recs . " planets.");

            BODY:
            foreach my $am_rec(@am_recs) {
                my $body_name = $self->game_client->planet_name($am_rec->body_id);

                unless($body_name) {
                    $logger->info("Scheduler found prefs for a planet that you've since abandoned; skipping.");
### CHECK
### I can't continue to just leave these old prefs here.  Along with skipping, I 
### need to be deleting those old prefs.
                    next BODY;
                }
                $logger->info("- Dealing with the Arch Min on $body_name.");

                unless( ($am_rec->glyph_home_id and $am_rec->pusher_ship_name) or $am_rec->auto_search_for ) {
                    $logger->info("Arch Min pref record exists but is empty; skipping $body_name.");
                    next BODY;
                }

                $server_glyphs_pushed   += $self->_archmin_push($am_rec, $logger)   || 0;
                $server_searches        += $self->_archmin_search($am_rec, $logger) || 0;
            }

            $logger->info("- Pushed $server_glyphs_pushed glyphs to their homes.");
            $logger->info("- Started $server_searches glyph searches.");
        }#}}}

        $logger->info("--- Arch Min Manager Complete ---");
        return;
    }#}}}
    sub _archmin_push {#{{{
        my $self    = shift;
        my $am_rec  = shift;    # ArchMinPrefs record
        my $logger  = shift;

        my $this_body_name = $self->game_client->planet_name($am_rec->body_id) or return;

        unless( $am_rec->glyph_home_id and $am_rec->pusher_ship_name ) {
            $logger->info("No glyph push requested.");
            return;
        }

        my $glyph_home_name;
        unless( $glyph_home_name = $self->_planet_exists($am_rec->glyph_home_id) ) {
            $logger->info("Specified glyph home is invalid; perhaps it was abandoned?");
        }
        $logger->info("Planning to push to $glyph_home_name.");

        my $pusher_ship = $self->_ship_exists($am_rec->pusher_ship_name, $am_rec->body_id);
        unless($pusher_ship) {
            $logger->info("Requested pusher ship " . $am_rec->pusher_ship_name . " either does not exist or is not currently available.");
            return;
        }
        my $hold_size = $pusher_ship->{'hold_size'} || 0;
        $logger->info("Pushing with ship " . $am_rec->pusher_ship_name . q{.});

        my $glyphs;
        unless( $glyphs = $self->_glyphs_available($am_rec->body_id) ) {
            $logger->info("No glyphs are on $this_body_name right now.");
            return;
        }
        $logger->debug( scalar @{$glyphs} . " glyphs onsite about to be pushed.");

        my $cargo = $self->_load_glyphs_in_cargo($glyphs, $hold_size);
        my $count = scalar @{$cargo};
        unless( $count ) { # Don't attempt the push with zero glyphs
            $logger->info("Cargo is empty, so nothing is going to be pushed home.");
            return;
        }

        my $trademin = $self->_trademin($am_rec->body_id);
        my $rv = try {
            $trademin->push_items($am_rec->glyph_home_id, $cargo, {ship_id => $pusher_ship->{'id'}});
        }
        catch {
            $logger->error("Attempt to push glyphs failed with: $_");
            return;
        };
        $rv or return;

        $logger->info("Pushed $count glyphs to $glyph_home_name.");

        return $count;
    }#}}}
    sub _archmin_search {#{{{
        my $self    = shift;
        my $am_rec  = shift;
        my $logger  = shift;

        my $body_name      = $self->game_client->planet_name($am_rec->body_id) or return;   # no body name == no arch min
        my $ore_types      = $self->game_client->ore_types;
        my $total_searches = 0;

        unless( $am_rec->auto_search_for ~~ $ore_types ) {
            $logger->error("Somehow you're attempting to search for an invalid ore type.");
            return;
        }

        my $archmin = try {
            $self->game_client->get_building($am_rec->body_id, 'Archaeology');
        }
        catch {
            $logger->error("Attempt to get archmin failed with: $_");
            return;
        };
        unless($archmin) {
            ### The last time we mentioned $body_name, we should have gotten 
            ### out if it was undef.  But Newpyre says he's still getting 
            ### undefined errors on $body_name on this next line.  I cannot 
            ### see how that can possibly be happening, but this will fix his 
            ### leetle red wagon:
            $body_name ||= q{};
            ### If he's still getting undefined errors on line 216, then he 
            ### hasn't updated, as the following is no longer line 216:
            $logger->info("No Arch Min exists on $body_name.");
            return;
        }

        ### Arch Min is currently idle?
        my $view = $archmin->view;
        if( my $work = $view->{'building'}{'work'} ) {
            my $glyph     = $work->{'searching'};
            my $secs_left = $work->{'seconds_remaining'};
            $logger->info("Already searching for a $glyph glyph; complete in $secs_left seconds.");
            return;
        }

        ### Get ores available to this arch min
        my $ores_onsite = $archmin->get_ores_available_for_processing;
        unless( defined $ores_onsite->{'ore'} and %{$ores_onsite->{'ore'}} ) {
            $logger->info("Not enough of any type of ore to search.");
            return;
        }

        ### If the type requested by the user is not available, chose another 
        ### type to search for at 'random'.
        my $ore_to_search = q{};
        if( defined $ores_onsite->{'ore'}{$am_rec->auto_search_for} ) {
            $ore_to_search = $am_rec->auto_search_for;
        }
        else {
            $ore_to_search = each %{$ores_onsite->{'ore'}};
            keys %{$ores_onsite->{'ore'}};    # Reset hash after each.
            $logger->info("There's not enough " . $am_rec->auto_search_for . " ore to perform a search.");
        }
        unless($ore_to_search) {
            $logger->error("I can't figure out what to search for; we should never get here.");
            return;
        }

        ### Perform the search
        my $rv = try {
            my $rv = $archmin->search_for_glyph($ore_to_search);
            $logger->info("Arch Min is now searching for one $ore_to_search glyph.");
            return 1;
        }
        catch {
            $logger->error("Arch Min ore search failed because: $_");
            return 0;
        };

        return $rv;
    }#}}}
    sub _glyphs_available {#{{{
        my $self    = shift;
        my $pid     = shift;

        my $trademin = $self->_trademin($pid);
        my $glyphs_rv = try {
            $trademin->get_glyph_summary;
        };

        unless( ref $glyphs_rv eq 'HASH' and defined $glyphs_rv->{'glyphs'} and @{$glyphs_rv->{'glyphs'}} ) {
            return;
        }

        return $glyphs_rv->{'glyphs'};
    }#}}}
    sub _load_glyphs_in_cargo {#{{{
        my $self        = shift;
        my $glyphs      = shift;
        my $hold_size   = shift;

=head2 _load_glyphs_in_cargo

Accepts an arrayref of glyphs, as returned by get_glyph_summary, and an integer 
hold size.

Adds the glyphs as cargo up to the limit defined by the hold size, and returns 
the cargo as an arrayref.

If any glyphs are left over (they would have exceeded hold size), it's assumed 
they'll simply be picked up on the next run.

=cut

        my $cargo = [];
        my $count = 0;
        ADD_GLYPHS:
        foreach my $g( @{$glyphs} ) {
            $count += $g->{'quantity'};
            if( $count * GLYPH_CARGO_SIZE > $hold_size ) { # Whoops
                $count -= $g->{'quantity'};
                last ADD_GLYPHS;
            }
            push @{$cargo}, {type => 'glyph', name => $g->{'name'}, quantity => $g->{'quantity'}};
        }
        return $cargo;
    }#}}}
    sub _planet_exists {#{{{
        my $self = shift;
        my $pid  = shift;
        my $glyph_home_name = $self->game_client->planet_name($pid);
        return $glyph_home_name;    # undef if the pid wasn't found
    }#}}}
    sub _ship_exists {#{{{
        my $self        = shift;
        my $ship_name   = shift;
        my $pid         = shift;

        my $ships = $self->game_client->get_available_ships($pid);
        my($ship) = first{ $_->{'name'} eq $ship_name }@{$ships};
        return $ship;
    }#}}}
    sub _trademin {#{{{
        my $self        = shift;
        my $pid         = shift;

        my $trademin = try {
            $self->game_client->get_building($pid, 'Trade');
        };

        return $trademin;
    }#}}}

    sub autovote {#{{{
        my $self = shift;

        my $logger = $self->bb->resolve( service => '/Log/logger' );
        my $schedule_av = LacunaWaX::Schedule::Autovote->new(
            bb      => $self->bb,
            logger  => $logger,
            schema  => $self->bb->resolve( service => '/Database/schema' ),
        );
        my $cnt = $schedule_av->vote_all_servers;
        $logger->info("--- Autovote Run Complete ---");

        return $cnt;
    }#}}}
    sub lottery {#{{{
        my $self = shift;

        my $logger = $self->bb->resolve( service => '/Log/logger' );
        my $schedule_lottery = LacunaWaX::Schedule::Lottery->new(
            bb      => $self->bb,
            logger  => $logger,
            schema  => $self->bb->resolve( service => '/Database/schema' ),
        );
        my $cnt = $schedule_lottery->play_all_servers;
        $logger->info("--- LLottery Run Complete ---");

        return $cnt;
    }#}}}

    sub train_spies {#{{{
        my $self = shift;

        my $schema = $self->bb->resolve( service => '/Database/schema' );
        my $logger = $self->bb->resolve( service => '/Log/logger' );
        $logger->component('TrainSpies');

        my $servers = [];
        my $servers_rs = $schema->resultset('Servers');
        while(my $server_rec = $servers_rs->next) {
            push @{$servers}, $server_rec;
        }

        $self->set_memoize();

        SERVER:
        foreach my $server_rec(@{$servers}) {
            $logger->info("--- Attempting to train spies on server " . $server_rec->name . ' ---');

            unless( $self->game_connect($server_rec->id) ) {
                $logger->info("Failed to connect to " . $server_rec->name . " - check your credentials!");
                next SERVER;
            }

            my $trained = 0;
            foreach my $pid( values %{$self->game_client->planets} ) {
                $trained += $self->_train_spies_on_planet($pid, $server_rec->id, $logger);
            }
            $logger->info("$trained spies trained on " . $server_rec->name . q{.});
        }
        $logger->info("--- Spy Training Run Complete ---");
        return;
    }#}}}
    sub _training_buildings_available {#{{{
        my $self = shift;
        my $pid  = shift;

=head2 _training_buildings_available

Returns a hashref of spy training buildings existing on $planet_id.

The hashref is { type => building_obj }, eg:

 {
    Intel  => intel_bldg_obj,
    Mayhem => mayhem_bldg_obj,
    ...etc...
 }

If no training buildings exist on the planet, returns undef.
  
=cut

        my $training_bldgs = {};
        my $got_one = 0;
        foreach my $type( TRAINING_TYPES ) {
            my $name = $type . 'Training'; 
            my $bldg = try   { $self->game_client->get_building($pid, $name); }
                       catch { return; };
            if( $bldg and ref $bldg eq "Games::Lacuna::Client::Buildings::$name" ) {
                $training_bldgs->{$type} = $bldg;
                $got_one++;
            }
        }
        return $training_bldgs if $got_one;
        return;
    }#}}}
    sub _train_spies_on_planet {#{{{
        my $self    = shift;
        my $pid     = shift;
        my $sid     = shift;
        my $logger  = shift;

        my $pname   = $self->game_client->planet_name($pid);
        my $schema  = $self->bb->resolve( service => '/Database/schema' );

        ### Skip known stations
        if( my $rec = $schema->resultset('BodyTypes')->search({ body_id => $pid, server_id => $sid, type_general => 'space station'})->single ) {
            $logger->info("$pname is an SS - no spy training possible.");
            return 0;
        }
        $logger->info("Attempting to train spies on $pname.");

        my $training_bldgs;
        unless( $training_bldgs = $self->_training_buildings_available($pid) ) {
            $logger->info("$pname has no spy training buildings; skipping.");
            return 0;
        }

        my $total_cnt = 0;
        foreach my $type(keys %{$training_bldgs}) {   # 'Intel', 'Mayhem', etc
            $logger->info("$pname has a $type training building.");
            my $train_cnt = $self->_train_spies_at_building($type, $training_bldgs->{$type}, $logger) // 0;
            $total_cnt += $train_cnt;
            $logger->info("$train_cnt spies trained at this building.");
        }

        return $total_cnt;
    }#}}}
    sub _train_spies_at_building {#{{{
        my $self    = shift;
        my $type    = shift;
        my $bldg    = shift;
        my $logger  = shift;

        my $view = try   { $bldg->view; }
                   catch { return };
        $view and ref $view eq 'HASH' or return;

        my $schema = $self->bb->resolve( service => '/Database/schema' );
        my $spies = [];
        ### $view->{'spies'}{'training_costs'}{'time'} is an AoH
        ### https://us1.lacunaexpanse.com/api/IntelTraining.html
        if( defined $view->{'spies'}{'training_costs'}{'time'} and ref $view->{'spies'}{'training_costs'}{'time'} eq 'ARRAY' ) {
            $spies = $view->{'spies'}{'training_costs'}{'time'};
        }

        $logger->info(@{$spies} . " spies are available to train at this building.");
        my $trained = 0;
        SPY:
        foreach my $spy(@{$spies}) {
            if( my $rec = $schema->resultset('SpyTrainPrefs')->search({spy_id => $spy->{'spy_id'}, train => (lc $type)})->single ) {
                $trained++;
                unless( $self->is_idle($spy) ) {
                    $logger->info("Spy $spy->{'name'} is available for training, but is set to Counter, so we won't train him.");
                    next SPY;
                }
                my $rv = try {
                    $bldg->train_spy($rec->spy_id);
                }
                catch {
                    my $err = (ref $_ eq 'LacunaRPCException') ? $_->{'text'} : $_;
                    $logger->error("Attempt to train spy returned '$err'.  Skipping spy.");
                    return;
                };
                $rv or next SPY;
                if( $rv->{'trained'} ) {
                    $logger->info("Spy $spy->{'name'} was trained in $type.");
                }
                else {
                    $logger->error("Spy$spy->{'name'} was not trained.");
                    return;
                }
            }
        }

        return $trained;
    }#}}}

    sub test {#{{{
        my $self = shift;

        my $logger = $self->bb->resolve( service => '/Log/logger' );
        $logger->component('ScheduleTest');
        $logger->info("ScheduleTest has been called.");

        return 1;
    }#}}}

=head2 Memoizing Spies

$spy_training_building->view->{'spies'}{'training_costs'}{'time'} returns a list 
of spies who are available to be trained by that $spy_training_building.

This list excludes spies who are on cooldown from a mission, and spies who are 
already being trained.

The list includes spies who are Idle (good), but it also includes spies who are 
on Counter Espionage (what?!?  why?)

Now, I don't want to train spies who've been set to Counter - if the user set a 
defensive spy on Counter, he's supposed to stay that way, protecting the planet, 
not heading off to training.


The problem here is that $spy_training_building->view does not tell you what the 
spy is currently assigned to - you can't tell if he's idle or on counter from 
that data (what?!? why not?)


SO, to determine whether a given 'available to train' spy is actually Idle or on 
Counter, we have to:
    - Get that spy's home Int Min (the $spy_training_building->view does include 
      the spy's home planet ID, which makes getting the Int Min a little easier)
    - Get a list of all of that Int Min's spies
        - This list contains much more info on the spies, including their 
          current assignement.
    - Dig the current spy out of that list, and look at his assignment.  It'll 
      be either 'Idle' or 'Counter Espionage'.
    - If that spy is not listed as 'Idle', do not try to train him.


The first two steps of that are going to be expensive server calls.  Since we're 
currently in a scheduled task, the Bread::Board container does not have a CHI 
object in it.

So, rather than using CHI, I'm memoizing the get_int_min() and get_spies() subs 
(not methods!) below.  The first call to those two subs takes about 8 seconds; 
subsequent calls with the same args are about instantaneous.

=cut

    sub set_memoize {#{{{
        my $self = shift;
        memoize('get_int_min');
        memoize('get_spies');
        return;
    }#}}}
    sub is_idle {#{{{
        my $self = shift;
        my $spy  = shift;

        my $int_min     = get_int_min($self->game_client, $spy->{'based_from'}{'body_id'}) or return;
        my $home_spies  = get_spies($int_min) or return;

        my $full_spy_info = first{ $_->{'name'} eq $spy->{'name'} }@{$home_spies};
        return( $full_spy_info->{'assignment'} eq 'Idle' ? 1 : 0 );
    }#}}}
    ### Subs, not methods - these get memoized.
    sub get_int_min {#{{{
        my $client = shift;
        my $pid = shift;
        my $int_min = try   { $client->get_building($pid, 'Intelligence'); }
                      catch { return; };
        return $int_min;
    }#}}}
    sub get_spies {#{{{
        my $int_min = shift;
        my $spies = try   { $int_min->view_all_spies(); }
                    catch { return };
        return $spies->{'spies'} // undef;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;
