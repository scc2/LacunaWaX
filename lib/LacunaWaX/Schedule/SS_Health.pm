use v5.14;


### See CHECK


package LacunaWaX::Schedule::SS_Health {
    use Carp;
    use English qw( -no_match_vars );
    use Moose;
    use Try::Tiny;
    with 'LacunaWaX::Roles::ScheduledTask';

    use LacunaWaX::Model::SStation;
    use LacunaWaX::Model::SStation::Police;

    has 'station' => (
        is  => 'rw',
        isa => 'LacunaWaX::Model::SStation',
        handles => {
            subpar_res              => 'subpar_res',
            incoming_hostiles       => 'incoming_hostiles',
            has_hostile_spies       => 'has_hostile_spies',
            star_unseized           => 'star_unseized',
            star_seized_by_other    => 'star_seized_by_other',
        },
        documentation => q{
            This cannot be built until after a call to game_connect().
        }
    );

    has 'inbox' => (
        is          => 'rw',
        isa         => 'Object',
        lazy_build  => 1,
    );

    sub BUILD {
        my $self = shift;
        $self->logger->component('SS_Health');
        return $self;
    }
    sub _build_inbox {#{{{
        my $self = shift;
        return $self->game_client->inbox
    }#}}}

    sub alert {#{{{
        my $self = shift;
        my $msg = shift;

        $self->logger->info( "PROBLEM - $msg" );    # SS name has already been mentioned in the log
        $self->inbox->send_message(
            $self->game_client->empire_name,
            $self->station->name . " ALERT",
            "
While performing a routine checkup of your station, I 
found a problem that could be dangerous to its long 
term health and happiness.

Please look into this immediately.
            
The problem I found was:
--------------------------------------------------
$msg
--------------------------------------------------

Your humble station physician,
Dr. Flurble J. Notaqwak

",
        );

        return 1;
    }#}}}
    sub diagnose_all_servers {#{{{
        my $self        = shift;
        my @server_recs = $self->schema->resultset('Servers')->search()->all;   ## no critic qw(ProhibitLongChainsOfMethodCalls)

        foreach my $server_rec( @server_recs ) {
            my $server_count = try {
                $self->diagnose_server($server_rec);
            }
            catch {
                chomp(my $msg = $_);
                $self->logger->error($msg);
                return;
            } or return;
        }
        $self->logger->info("Stations have been checked on all servers.");
        return;
    }#}}}
    sub diagnose_server {#{{{
        my $self            = shift;
        my $server_rec      = shift;    # Servers table record
        my $server_checks   = 0;

        unless( $self->game_connect($server_rec->id) ) {
            $self->logger->info("Failed to connect to " . $server_rec->name . " - check your credentials!");
            return $server_checks;
        }
        $self->logger->info("Diagnosing stations on server " . $server_rec->name);

        my @ss_alert_recs = $self->schema->resultset('SSAlerts')->search({    ## no critic qw(ProhibitLongChainsOfMethodCalls)
            server_id => $server_rec->id
        })->all;

        STATION_RECORD:
        foreach my $ss_rec(@ss_alert_recs) {
            $self->make_station($ss_rec);
            try {
                $self->diagnose_station($ss_rec);
            }
            catch {
                $self->logger->error("Unable to diagnose station " . $self->station->name . ": $ARG");
            } or next STATION_RECORD;
        }

        return 1;
    }#}}}
    sub diagnose_station {#{{{
        my $self    = shift;
        my $ss_rec  = shift;    # SSAlerts table record

        return unless $ss_rec->enabled;
        $self->logger->info("Diagnosing " . $self->station->name);

        $self->logger->info("Checking we have sufficient resources");
        if( my $restype = $self->station->subpar_res($ss_rec->min_res) ) {
            $self->alert("$restype per hour has dropped too low!");
        }

        $self->logger->info("Looking for hostile inbound ships");
        if( my $shipcount = $self->incoming_hostiles() ) {
            $self->alert("There are hostile ships inbound!");
        }

        $self->logger->info("Looking for hostile spies onsite");
        if( $self->has_hostile_spies($ss_rec) ) {
            $self->alert("There are spies onsite who are not set to Counter Espionage.  These may be hostiles.")
        }

        $self->logger->info("Making sure our star is seized...");
        if( $self->star_unseized() ) {
            $self->alert("The station's star is unseized.")
        }

        $self->logger->info("...and making sure it's seized by us.");
        if( $self->star_seized_by_other() ) {
            $self->alert("Star has been seized by another SS")
        }

        return;
    }#}}}
    sub make_station {#{{{
        my $self    = shift;
        my $ss_rec  = shift;
        my $station = LacunaWaX::Model::SStation->new(
            id          => $ss_rec->station_id,
            game_client => $self->game_client,
        );
        $self->station( $station );
        return 1;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

1;
