use v5.14;

package LacunaWaX::Schedule::Autovote {
    use Carp;
    use Moose;
    use Try::Tiny;

    with 'LacunaWaX::Roles::ScheduledTask';

    sub BUILD {
        my $self = shift;
        $self->logger->component('Autovote');
        return $self;
    }

    sub vote_all_servers {#{{{
        my $self        = shift;
        my $all_votes   = 0;

        my @av_recs = $self->schema->resultset('ScheduleAutovote')->search()->all;  ## no critic qw(ProhibitLongChainsOfMethodCalls)
        $self->logger->info(
            "Autovote prefs are enabled on " 
            . @av_recs 
            . ( (@av_recs == 1) ? 'server' : 'servers' )
        );

        foreach my $av_rec( @av_recs ) {
            my $votes = $self->vote_server($av_rec);
            $self->logger->info("$votes votes recorded server-wide.");
            $all_votes += $votes;
        }
        $self->logger->info("$all_votes votes recorded on all servers.");

        return $all_votes;
    }#}}}
    sub vote_server {#{{{
        my $self            = shift;
        my $av_rec          = shift;    # ScheduleAutovote record
        my $server_votes    = 0;

        $self->logger->info(
            "Autovoting for props proposed by " 
            . $av_rec->proposed_by 
            . " on server " 
            . $av_rec->server_id
        );

        if($av_rec->proposed_by eq 'none') {
            $self->logger->info("Specifically requested not to perform autovoting on this server.  Skipping.");
            return $server_votes;
        }

        if( my $server = $self->schema->resultset('Servers')->find({id => $av_rec->server_id}) ) {
            unless( $self->game_connect($server->id) ) {
                $self->logger->info("Failed to connect to " . $server->name . " - check your credentials!");
                return $server_votes;
            }
        }
        else { return $server_votes; }

        my $ss_rs = $self->schema->resultset('BodyTypes')->search({
            type_general => 'space station', 
            server_id => $av_rec->server_id
        });
        my @ss_recs = $ss_rs->all;
        $self->logger->info("User has set up autovote on " . @ss_recs . " stations.");

        STATION:
        foreach my $ss_rec(@ss_recs) {#{{{
            my $station_votes = try {
                $self->vote_station($ss_rec, $av_rec);
            }
            catch {
                my $msg = (ref $_) ? $_->text : $_;
                $self->logger->error("Attempt to vote failed: $msg");
                return $server_votes;
            };
            $station_votes // next STATION;
            $server_votes += $station_votes;
            $self->logger->info("$station_votes votes cast.");
        }#}}}

        $self->logger->info("$server_votes votes recorded server-wide.");
        return $server_votes;
    }#}}}
    sub vote_station {#{{{
        my $self        = shift;
        my $ss_rec      = shift;    # BodyTypes record
        my $av_rec      = shift;    # ScheduleAutovote record
        my $votecount   = 0;

        my $station_name = $self->game_client->planet_name($ss_rec->body_id);
        unless($station_name) {
            $self->logger->info("Station " . $ss_rec->body_id . " no longer exists; removing voting prefs.");
            $ss_rec->delete;
            return $votecount;
        }
        $self->logger->info("Attempting to vote on $station_name" );

        my $ss_status = try {
            $self->game_client->get_body_status($ss_rec->body_id);
        }
        catch { return $votecount; };
        $ss_status or croak "Could not get station status";
        my $ss_name   = $ss_status->{'name'};
        my $ss_owner  = $ss_status->{'empire'}{'name'};

        my $parl = try {
            $self->game_client->get_building($ss_rec->body_id, 'Parliament');
        }
        catch { return $votecount; };
        $parl or croak "No parliament";

        my $props = try {
            $parl->view_propositions;
        }
        catch { return $votecount; };
        $props or croak "No props";
        $self->logger->info("Checking props on $ss_name.");

        unless($props and ref $props eq 'HASH' and defined $props->{'propositions'}) {
            croak "No active props";
        }
        $props = $props->{'propositions'};
        $self->logger->info(@{$props} . " props active on $ss_name.");

        PROP:
        foreach my $prop(@{$props}) {#{{{
            try {
                $self->vote_prop($parl, $prop, $av_rec, $ss_owner);
            }
            catch {
                my $msg = (ref $_) ? $_->text : $_;
                chomp $msg;
                $self->logger->info($msg);
                return;
            };
            $votecount++;
        }#}}}

        return $votecount;
    }#}}}
    sub vote_prop {#{{{
        my $self        = shift;
        my $parl        = shift;
        my $prop        = shift;
        my $av_rec      = shift;    # ScheduleAutovote record
        my $ss_owner    = shift;    # SS owner name - string

        ### The die messages will appear in the log viewer; we don't need 
        ### filenames and line numbers in there, so end them with newlines.
        ### This is also why we're using die() rather than croak().
        ###
        ### So death messages caught from this will end with newlines; chomp 
        ### them before output.

        ## no critic qw(RequireCarping)
        if( $prop->{my_vote} ) {
            die "$prop->{name} - I've already voted on this prop; skipping.\n";
        }

        my $propper = $prop->{'proposed_by'}{'name'};
        if($av_rec->proposed_by eq 'owner' and $propper ne $ss_owner) {
            die "Prop $prop->{name} was proposed by $propper, who is not the SS owner - skipped.\n";
        }

        my $rv = try {
            $parl->cast_vote($prop->{'id'}, 1);
        }
        catch { die "Attempt to vote failed with: $_"; };

        unless( $rv->{proposition}{my_vote} ) {
            die "Vote attempt did not produce an error, but did not succeed either.\n";
        }
        ## use critic qw(RequireCarping)

        return 1;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

1;
