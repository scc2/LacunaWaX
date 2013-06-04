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
    use List::Util qw(first);   # CHECK should go away.
    use LWP::UserAgent;
    use Memoize;
    use Moose;
    use Try::Tiny;

    use LacunaWaX::Schedule::Archmin;
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

    ### CONSTANTS (should go away)
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

        my $am       = LacunaWaX::Schedule::Archmin->new( bb => $self->bb );
        my $pushes   = $am->push_all_servers;
        my $searches = $am->search_all_servers;
        $am->logger->info("--- Archmin Run Complete ---");

        return($searches, $pushes);
    }#}}}
    sub autovote {#{{{
        my $self = shift;

        my $av  = LacunaWaX::Schedule::Autovote->new( bb => $self->bb );
        my $cnt = $av->vote_all_servers;
        $av->logger->info("--- Autovote Run Complete ---");

        return $cnt;
    }#}}}
    sub lottery {#{{{
        my $self = shift;

        my $lottery = LacunaWaX::Schedule::Lottery->new( bb => $self->bb );
        my $cnt     = $lottery->play_all_servers;
        $lottery->logger->info("--- LLottery Run Complete ---");

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
