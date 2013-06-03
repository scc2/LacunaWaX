use v5.14;

package LacunaWaX::Schedule::Lottery {
    use Carp;
    use LacunaWaX::Model::Lottery::Links;
    use LWP::UserAgent;
    use Moose;
    use Try::Tiny;

    with 'LacunaWaX::Roles::ScheduledTask';

    has 'links' => (
        is          => 'rw',
        isa         => 'LacunaWaX::Model::Lottery::Links',
        clearer     => 'clear_links',
        predicate   => 'has_links',
        documentation => q{
            Cannot be lazily-built.  Created on a per-server basis by calls to make_links in play_server.
        }
    );
    has 'ua' => (
        is          => 'rw',
        isa         => 'LWP::UserAgent',
        lazy_build  => 1,
    );

    sub BUILD {
        my $self = shift;
        $self->logger->component('Lottery');
    }
    sub _build_ua {#{{{
        my $self = shift;
        return LWP::UserAgent->new(
            agent                   => 'Mozilla/5.0 (Windows NT 5.1; rv:20.0) Gecko/20100101 Firefox/20.0',
            max_redirects           => 3,
            requests_redirectable   => ['GET'],
            timeout                 => 20,  # high, but the server's been awfully laggy lately.
        );
    }#}}}
    sub make_links {#{{{
        my $self    = shift;
        my $body_id = shift;

        my $links = try {
            LacunaWaX::Model::Lottery::Links->new(
                client      => $self->game_client,
                planet_id   => $body_id,
            );
        }
        catch {
            my $msg = (ref $_) ? $_->text : $_;
            $self->logger->error("Unable to get lottery links: $msg");
            ### Likely a server problem, maybe a planet problem.
        } or return;

        $self->links($links);
        return 1;
    }#}}}

    sub play_all_servers {#{{{
        my $self    = shift;
        my $ttl     = 0;

        my @server_recs = $self->schema->resultset('Servers')->search()->all;

        foreach my $server_rec( @server_recs ) {
            my $server_count = $self->play_server($server_rec);
            $ttl += $server_count;
        }
        $self->logger->info("The lottery has been played $ttl times on all servers.");

        return $ttl;
    }#}}}
    sub play_server {#{{{
        my $self            = shift;
        my $server_rec      = shift;    # Servers table record
        my $server_plays    = 0;

        unless( $self->game_connect($server_rec->id) ) {
            $self->logger->info("Failed to connect to " . $server_rec->name . " - check your credentials!");
            return $server_plays;
        }
        $self->logger->info("Playing lottery on server " . $server_rec->name);

        my @lottery_planet_recs = $self->schema->resultset('LotteryPrefs')->search({
            server_id => $server_rec->id
        })->all;

        PLANET:
        foreach my $lottery_rec(@lottery_planet_recs) {

            ### Create the links just once per server...
            unless( $self->has_links ) {
                $self->make_links( $lottery_rec->body_id );
            }

            my $planet_count = try {
                $self->play_planet($lottery_rec);
            }
            catch {
                $self->logger->error("Unable to play lottery on body " . $lottery_rec->body_id . ": $!");
            } or next PLANET;
            $server_plays += $planet_count;

            ### ...clear them before working on the next server.
            $self->clear_links;
        }
        $self->logger->info("The lottery has been played $server_plays times on server " . $server_rec->name);
        return $server_plays;
    }#}}}
    sub play_planet {#{{{
        my $self            = shift;
        my $lottery_rec     = shift;    # LotteryPrefs table record
        my $planet_count    = 0;

        return $planet_count unless $lottery_rec->count;

        unless( $self->has_links ) {
            carp "We need to have links set up before playing a planet.";    # wtf?
        }

        ### Make sure the lottery links are using the current planet's ID so 
        ### our plays will take place in the correct zone.
        unless( $lottery_rec->body_id eq $self->links->planet_id ) {
            try {
                $self->links->change_planet($lottery_rec->body_id);
            }
            catch {
                my $msg = (ref $_) ? $_->text : $_;
                $self->logger->error("Unable to change links' planet to " . $lottery_rec->body_id . " - $msg");
                return $planet_count;
            }
        }

        my $pname = $self->game_client->planet_name($lottery_rec->body_id);
        $self->logger->info("Playing lottery " . $lottery_rec->count . " times on $pname ");

        if( $self->links->remaining <= 0 ) {
            $self->logger->info("You've already played out the lottery on this server today.");
            return $planet_count;
        }
        $self->logger->info("There are " . $self->links->remaining . " lottery links left to play.");

        PLAY:
        for( 1..$lottery_rec->count ) {
            $planet_count += $self->play();
        }

        $self->logger->info("The lottery has been played $planet_count times on $pname.");
        return $planet_count;
    }#}}}
    sub play {#{{{
        my $self    = shift;
        my $plays   = 0;

        unless( $self->has_links ) {
            carp "We need to have links set up before playing the lottery.";    # wtf?
        }

        my $link = $self->links->next or do {
            $self->logger->error("I ran out of links before playing all assigned slots; re-do your assignments!");
            return $plays;
        };
        $self->logger->info("Trying link for " . $link->name);

        my $resp = $self->ua->get($link->url);
        if( $resp->is_success ) {
            $self->logger->info(" -- Success!");
            $plays++;
        }
        else {
            $self->logger->error(" -- Failure! " . $resp->status_line);
            $self->logger->error(" -- This /probably/ means that the voting site is down, but you /probably/ still got credit for this vote.");

            ### 
            ### The attempt to hit the voting site link failed.
            ### 
            ### But we've already pinged the TLE server, so we're reasonably 
            ### sure it's still up.
            ###
            ### Lottery links first hit the TLE server, recording the fact 
            ### that we've clicked the link and played the lottery.  After 
            ### that, the TLE server redirects us to the voting site.
            ### 
            ### So this failure means that, though we were unable to hit the 
            ### final destination voting website, we almost certainly _were_ 
            ### able to hit the TLE server, which recorded this attempt as a 
            ### successful lottery play.
            ###
            ### So count it.
            ### 

            $plays++;
        }

        return $plays;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

1;
