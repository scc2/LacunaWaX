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
    use LacunaWaX::CavaPreload;
    use LacunaWaX::Model::Container;
    use LacunaWaX::Model::Mutex;
    use LacunaWaX::Model::Client;
    use LWP::UserAgent;
    use Moose;
    use Try::Tiny;

    use LacunaWaX::Schedule::Archmin;
    use LacunaWaX::Schedule::Autovote;
    use LacunaWaX::Schedule::Lottery;
    use LacunaWaX::Schedule::Spies;

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
        return $self;
    }

    around 'lottery', 'archmin' => sub {
        my $orig = shift;
        my $self = shift;

        my $logger = $self->bb->resolve( service => '/Log/logger' );
        $logger->component('Schedule');
        $logger->info("# -=-=-=-=-=-=- #");
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

        $self->$orig();

        $self->mutex->lock_un;
        $logger->info("Scheduler run of task " . $self->schedule . " complete.");
        return $self;
    };



    sub BUILD_ORIG {#{{{
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
            when('spies') {
                $self->spies;
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
    }#}}}
    sub _build_mutex {#{{{
        my $self = shift;
        return LacunaWaX::Model::Mutex->new( bb => $self->bb, name => 'schedule' );
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
        $lottery->logger->info("--- Lottery Run Complete ---");

        return $cnt;
    }#}}}
    sub spies {#{{{
        my $self = shift;

        my $spies = LacunaWaX::Schedule::Spies->new( bb => $self->bb );
        my $cnt   = $spies->train_all_servers;
        $spies->logger->info("--- Spy Training Run Complete ---");

        return $cnt;
    }#}}}

    sub test {#{{{
        my $self = shift;

        my $logger = $self->bb->resolve( service => '/Log/logger' );
        $logger->component('ScheduleTest');
        $logger->info("ScheduleTest has been called.");

        return 1;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;
