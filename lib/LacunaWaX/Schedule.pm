
package LacunaWaX::Schedule {
    use v5.14;
    use Data::Dumper;
    use LacunaWaX::Model::Container;
    use LacunaWaX::Model::Mutex;
    use LacunaWaX::Model::Client;
    use List::Util qw(first);
    use LWP::UserAgent;
    use Memoize;
    use Moose;
    use Try::Tiny;

    use LacunaWaX::Model::Lottery::Links;

    has 'bb'            => (is => 'rw', isa => 'LacunaWaX::Model::Container',   required    => 1);
    has 'schedule'      => (is => 'rw', isa => 'Str',                           required    => 1);
    has 'mutex'         => (is => 'rw', isa => 'LacunaWaX::Model::Mutex',       lazy_build  => 1);
    has 'game_client'   => (is => 'rw', isa => 'LacunaWaX::Model::Client',
        documentation =>q{
            Not a lazy_build, but still auto-generated (in connect()).  No need to pass this in.
        }
    );

    sub BUILD {
        my $self = shift;

        my $logger = $self->bb->resolve( service => '/Log/logger' );
        $logger->component('Schedule');
        $logger->info("# -=-=-=-=-=-=- #"); # easier to visually find the start of a run in the Log Viewer
        $logger->info("Scheduler beginning with task '" . $self->schedule .  "'.");

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

    sub archmin_push {#{{{
        my $self    = shift;
        my $am_rec  = shift;
        my $logger  = shift;

        my $body_name    = $self->game_client->planet_name($am_rec->body_id) or return;
        my $total_pushed = 0;

        if( $am_rec->glyph_home_id and $am_rec->pusher_ship_name ) {
            ### ensure glyph_home_id is valid
            my $glyph_home_name;
            unless( $glyph_home_name = $self->game_client->planet_name($am_rec->glyph_home_id) ) {
                $logger->info("Specified glyph home is invalid; perhaps it was abandoned?");
                return;
            }
            $logger->info("Planning to push to $glyph_home_name.");

            ### check that pusher_ship_name exists, idle
            my $pusher_ship;
            my $ships = $self->game_client->get_available_ships($am_rec->body_id);
            foreach my $ship(@$ships) {
                if( $ship->{'name'} eq $am_rec->pusher_ship_name ) {
                    $pusher_ship = $ship;
                    last;
                }
            }
            unless($pusher_ship) {
                $logger->info("Requested pusher ship " . $am_rec->pusher_ship_name . " either does not exist or is not currently available.");
                return;
            }
            my $hold_size = $pusher_ship->{'hold_size'} || 0;
            $logger->info("Pushing with ship " . $am_rec->pusher_ship_name . ".");

            ### Get list of glyphs currently available
            my $trademin = try {
                $self->game_client->get_building($am_rec->body_id, 'Trade');
            }
            catch {
                $logger->error("Attempt to get trade min failed with: $_");
                return;
            };
            $body_name ||= q{};
            unless($trademin) {
                $logger->info("No Trade Min exists on $body_name.");
                return;
            }

            ### This is where I suspect IO's scheduler is blowing up, though I 
            ### don't know why.
            #my $glyphs_rv = $trademin->get_glyph_summary;
            my $glyphs_rv = try {
                $trademin->get_glyph_summary;
            }
            catch {
                my $msg = (ref $_) ? $_->text : $_;
                $logger->error("Could not get glyph summary: $msg");
                return;
            };
            unless($glyphs_rv and ref $glyphs_rv eq 'HASH') {
                $logger->info("No glyph summary means we're skipping this planet.");
                return;
            }

            unless( defined $glyphs_rv->{'glyphs'} and @{$glyphs_rv->{'glyphs'}} ) {
                $logger->info("No glyphs are on $body_name right now.");
                return;
            }
            my $glyphs = $glyphs_rv->{'glyphs'};
            $logger->debug( scalar @$glyphs . " glyphs onsite about to be pushed.");

        
            ### Add glyphs as cargo.  Make sure we don't add more than 
            ### we have cargo space for.
            my $cargo = [];
            my $count = 0;
            ADD_GLYPHS:
            foreach my $g( @$glyphs ) {
                $count += $g->{'quantity'};
                if( $count * 100 > $hold_size ) { # Whoops
                    $count -= $g->{'quantity'};
                    $logger->info("Too many glyphs onsite to push them all right now.  We'll get the rest later.");
                    last ADD_GLYPHS;
                }
                push @$cargo, {type => 'glyph', name => $g->{'name'}, quantity => $g->{'quantity'}};
            }
            if( scalar @$cargo ) { # Don't attempt the push with zero glyphs
                my $rv = try {
                    $trademin->push_items($am_rec->glyph_home_id, $cargo, {ship_id => $pusher_ship->{'id'}});
                }
                catch {
                    $logger->error("Attempt to push glyphs failed with: $_");
                    return;
                };
                $rv or return;
            }
            else {
                $logger->info("Cargo is empty, so nothing is going to be pushed home.");
                $logger->info("Pusher ship hold size is $hold_size.");
            }
            $logger->info("Pushed $count glyphs to $glyph_home_name.");
            $total_pushed += $count;
        }
        else {
            $logger->info("No glyph push requested.");
        }

        return $total_pushed;
    }#}}}
    sub archmin_search {#{{{
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

                $server_glyphs_pushed   += $self->archmin_push($am_rec, $logger)   || 0;
                $server_searches        += $self->archmin_search($am_rec, $logger) || 0;
            }

            $logger->info("- Pushed $server_glyphs_pushed glyphs to their homes.");
            $logger->info("- Started $server_searches glyph searches.");
        }#}}}

        $logger->info("--- Arch Min Manager Complete ---");
    }#}}}
    sub autovote {#{{{
        my $self = shift;

        my $logger = $self->bb->resolve( service => '/Log/logger' );
        $logger->component('Autovote');
        my $schema = $self->bb->resolve( service => '/Database/schema' );

        my @av_recs = $schema->resultset('ScheduleAutovote')->search()->all;
        my $plural = (@av_recs == 1) ? 'server' : 'servers';
        $logger->info("Autovote prefs are enabled on " . @av_recs . " $plural.");

        SERVER:
        foreach my $av_rec( @av_recs ) {#{{{
            $logger->info("Autovoting for props proposed by " . $av_rec->proposed_by . " on server " . $av_rec->server_id);
            my $server_votes = 0;

            if($av_rec->proposed_by eq 'none') {
                $logger->info("Specifically requested not to perform autovoting on this server.  Skipping.");
                next SERVER if $av_rec->proposed_by eq 'none';
            }

            if( my $server = $schema->resultset('Servers')->find({id => $av_rec->server_id}) ) {
                unless( $self->game_connect($server->id) ) {
                    $logger->info("Failed to connect to " . $server->name . " - check your credentials!");
                    next SERVER;
                }
            }
            else {
                next SERVER;
            }

            my $ss_rs = $schema->resultset('BodyTypes')->search({type_general => 'space station', server_id => $av_rec->server_id});
            my @ss_recs = $ss_rs->all;

            $logger->info("User has set up autovote on " . @ss_recs . " stations.");

            STATION:
            foreach my $ss_rec(@ss_recs) {#{{{

                my $ss_status = try {
                    $self->game_client->get_body_status($ss_rec->body_id);
                }
                catch {
                    $logger->error("Attempt to get status of body " . $ss_rec->body_id . " failed with: $_");
                    return;
                };
                $ss_status or next STATION;
                my $ss_name   = $ss_status->{'name'};
                my $ss_owner  = $ss_status->{'empire'}{'name'};

                my $parl = try {
                    $self->game_client->get_building($ss_rec->body_id, 'Parliament');
                }
                catch {
                    $logger->error("Attempt to get parl failed with: $_");
                    return;
                };
                unless($parl) {
                    $logger->info("Unable to find a Parliament on $ss_name.");
                    next STATION;
                }

                my $props = try {
                    $parl->view_propositions;
                }
                catch {
                    $logger->error("Attempt to view props failed with: $_");
                    return;
                };
                $props or next STATION;
                $logger->info("Checking props on $ss_name.");

                unless($props and ref $props eq 'HASH' and defined $props->{'propositions'}) {
                    $logger->info("No props active on $ss_name; skipping.");
                    next STATION;
                }
                $props = $props->{'propositions'};
                $logger->info(@$props . " props active on $ss_name.");

                PROP:
                foreach my $p(@$props) {#{{{
                    if( $p->{my_vote} ) {
                        $logger->info("$p->{name} - I've already voted on this prop; skipping.");
                        next PROP;
                    }

                    my $propper = $p->{'proposed_by'}{'name'};
                    if($av_rec->proposed_by eq 'owner' and $propper ne $ss_owner) {
                        $logger->info("Prop $p->{name} was proposed by $propper, who is not the SS owner - skipped.");
                        next PROP;
                    }

                    $logger->info("Agreeing to prop $p->{name} proposed by $propper.");
                    my $rv = try {
                        $parl->cast_vote($p->{'id'}, 1);
                    }
                    catch {
                        $logger->info("Attempt to vote failed with: $_");
                        return;
                    };
                    $rv or next PROP;

                    if( $rv->{proposition}{my_vote} ) {
                        $logger->info("Vote recorded successfully.");
                        $server_votes++;
                    }
                    else {
                        $logger->info("Vote attempt did not produce an error, but did not succeed either.");
                    }
                }#}}}
            }#}}}
            $logger->info("$server_votes votes recorded.");
            $logger->info("--- Autovote Run Complete ---");
        }#}}}
    }#}}}
    sub lottery {#{{{
        my $self = shift;

        my $logger = $self->bb->resolve( service => '/Log/logger' );
        $logger->component('Lottery');

        my $schema      = $self->bb->resolve( service => '/Database/schema' );
        my @server_recs = $schema->resultset('Servers')->search()->all;

        my $ua = LWP::UserAgent->new(
            agent                   => 'Mozilla/5.0 (Windows NT 5.1; rv:20.0) Gecko/20100101 Firefox/20.0',
            max_redirects           => 3,
            requests_redirectable   => ['GET'],
            timeout                 => 20,  # high, but the server's been awfully laggy lately.
        );

        SERVER:
        foreach my $server_rec( @server_recs ) {#{{{
            unless( $self->game_connect($server_rec->id) ) {
                $logger->info("Failed to connect to " . $server_rec->name . " - check your credentials!");
                next SERVER;
            }
            $logger->info("Playing lottery on server " . $server_rec->name);

            my @lottery_planet_recs = $schema->resultset('LotteryPrefs')->search({
                server_id => $server_rec->id
            })->all;

            my $links       = q{};
            my $total_plays = 0;

            PLANET:
            foreach my $lottery_rec(@lottery_planet_recs) {

                ### Don't muck up the logs if the user set the number of plays 
                ### on this planet to 0.
                next PLANET unless $lottery_rec->count;

                unless( $links ) {
                    ### Must only get $links once per server so the iterators 
                    ### work properly.
                    $links = try {
                        LacunaWaX::Model::Lottery::Links->new(
                            client      => $self->game_client,
                            planet_id   => $lottery_rec->body_id,
                        );
                    }
                    catch {
                        my $msg = (ref $_) ? $_->text : $_;
                        $logger->error("Unable to get lottery links: $msg");
                        ### Likely a server problem, maybe a planet problem.
                    } or next PLANET;
                }

                ### Make sure the lottery links are using the current planet's 
                ### ID so our plays will take place in the correct zone.
                unless( $lottery_rec->body_id eq $links->planet_id ) {
                    try {
                        $links->change_planet($lottery_rec->body_id);
                    }
                    catch {
                        my $msg = (ref $_) ? $_->text : $_;
                        $logger->error("Unable to change links' planet to " . $lottery_rec->body_id . " - $msg");
                        next PLANET;
                    }
                }

                my $pname = $self->game_client->planet_name($lottery_rec->body_id);
                $logger->info("Playing lottery " . $lottery_rec->count . " times on $pname ");
                my $planet_plays = 0;

                if( $links->remaining <= 0 ) {
                    $logger->info("You've already played out the lottery on this server today.");
                    next SERVER;
                }
                $logger->info("There are " . $links->remaining . " lottery links left to play.");

                PLAY:
                for( 1..$lottery_rec->count ) {
                    my $link = $links->next or do {
                        $logger->error("I ran out of links before playing all assigned slots; re-do your assignments!");
                        last PLANET;
                    };

                    $logger->info("Trying link for " . $link->name);
                    my $resp = $ua->get($link->url);
                    if( $resp->is_success ) {
                        $logger->info(" -- Success!");
                        $planet_plays++;
                    }
                    else {
                        $logger->error(" -- Failure! " . $resp->status_line);
                        $logger->error(" -- This /probably/ means that the voting site is down, but you /probably/ still got credit for this vote.");
                        ### connect() pinged the game server, so we're 
                        ### reasonably sure it's still up.
                        ###
                        ### Lottery links hit the game server, and from there 
                        ### get redirected to the voting site.
                        ###
                        ### But if the voting site is down or forbidding $ua 
                        ### hits or whatever, we were most likely still able to 
                        ### hit the game server's redirect, and that redirect is 
                        ### what recorded our lottery vote (which is all we 
                        ### really care about).
                        ###
                        ### So count it.
                        $planet_plays++;
                    }
                }

                $logger->info("The lottery has been played $planet_plays times on $pname.");
                $total_plays += $planet_plays;
            }
            $logger->info("The lottery has been played $total_plays times on server " . $server_rec->name);

        }#}}}

        $logger->info("--- Lottery Run Complete ---");
    }#}}}
    sub train_spies {#{{{
        my $self = shift;

        my $schema = $self->bb->resolve( service => '/Database/schema' );
        my $logger = $self->bb->resolve( service => '/Log/logger' );
        $logger->component('TrainSpies');

        my $servers = [];
        my $servers_rs = $schema->resultset('Servers');
        while(my $server_rec = $servers_rs->next) {
            push @$servers, $server_rec;
        }

        $self->set_memoize();

        SERVER:
        foreach my $server_rec(@$servers) {
            $logger->info("--- Attempting to train spies on server " . $server_rec->name . ' ---');

            unless( $self->game_connect($server_rec->id) ) {
                $logger->info("Failed to connect to " . $server_rec->name . " - check your credentials!");
                next SERVER;
            }

            PLANET:
            foreach my $pid( values %{$self->game_client->planets} ) {
                my $pname = $self->game_client->planet_name($pid);

                ### Skip known stations
                if( my $rec = $schema->resultset('BodyTypes')->search({ body_id => $pid, server_id => $server_rec->id, type_general => 'space station'})->single ) {
                    $logger->info("$pname is an SS - no spy training possible.");
                    next PLANET;
                }

                $logger->info("Attempting to train spies on $pname.");

                ### Marshal training buildings on this planet.
                my $training_bldgs = {};
                foreach my $type( qw(Intel Mayhem Politics Theft) ) {
                    my $name = $type . 'Training'; 

                    my $bldg = try   { $self->game_client->get_building($pid, $name); }
                               catch { return; };
                    if( $bldg and ref $bldg eq "Games::Lacuna::Client::Buildings::$name" ) {
                        $training_bldgs->{$type} = $bldg;
                    }
                }
                unless(keys %$training_bldgs) {
                    $logger->info("$pname has no spy training buildings; skipping.");
                    next PLANET;
                }

                BUILDING:
                foreach my $type(keys %$training_bldgs) {   # 'Intel', 'Mayhem', etc
                    $logger->info("$pname has a $type training building.");

                    my $bldg = $training_bldgs->{$type};
                    my $view = try   { $bldg->view; }
                               catch { return };
                    $view and ref $view eq 'HASH' or next BUILDING;

                    my $spies = [];
                    ### $view->{'spies'}{'training_costs'}{'time'} is an AoH of 
                    ### spies available to train.
                    ### https://us1.lacunaexpanse.com/api/IntelTraining.html
                    if( defined $view->{'spies'}{'training_costs'}{'time'} and ref $view->{'spies'}{'training_costs'}{'time'} eq 'ARRAY' ) {
                        $spies = $view->{'spies'}{'training_costs'}{'time'};
                    }

                    $logger->info(@$spies . " spies are available to train at this building.");
                    my $got_one = 0;
                    SPY:
                    foreach my $spy(@$spies) {

                        if( my $rec = $schema->resultset('SpyTrainPrefs')->search({spy_id => $spy->{'spy_id'}, train => (lc $type)})->single ) {
                            $got_one++;

                            ### See the whiny POD just above sub set_memoize for 
                            ### an explanation of this.
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
                                $logger->error("Spy$spy->{'name'} was NOT trained.  This can only happen if you don't have enough resources to train, so this planet is now going to be skipped.");
                                next PLANET;
                            }
                        }
                    }
                    unless($got_one) {
                        $logger->info("No available spies wanted to train at this building.");
                    }
                }
            }
        }
        $logger->info("--- Spy Training Run Complete ---");
    }#}}}

    sub test {#{{{
        my $self = shift;

        my $logger = $self->bb->resolve( service => '/Log/logger' );
        $logger->component('ScheduleTest');
        $logger->info("ScheduleTest has been called.");

        return 1;
    }#}}}

=pod

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
currently in a scheduled task, our Bread::Board container does not have our CHI 
object in it.

So, rather than using CHI, I'm memoizing the get_int_min() and get_spies() subs 
(not methods!) below.  The first call to those two subs takes about 8 seconds; 
subsequent calls with the same args are about instantaneous.

"But Dumbass", you cry, "why not just call view_empire_spies() on a single Int 
Min rather than trying to get each planet's Int Min individually?"  That would 
be because, though view_empire_spies() would be exactly what we want here, and 
though it's currently in the API documentation, it's also currently commented 
out of the server code with the text:
    # This call is too intensive for server at this time.  Disabled
...so it's documented, but it doesn't actually work, or even exist.

=cut

    sub set_memoize {#{{{
        my $self = shift;
        memoize('get_int_min');
        memoize('get_spies');
    }#}}}
    sub is_idle {#{{{
        my $self = shift;
        my $spy  = shift;

        my $int_min     = get_int_min($self->game_client, $spy->{'based_from'}{'body_id'}) or return;
        my $home_spies  = get_spies($int_min) or return;

        my $full_spy_info = first{ $_->{'name'} eq $spy->{'name'} }@$home_spies;
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
}

1;
