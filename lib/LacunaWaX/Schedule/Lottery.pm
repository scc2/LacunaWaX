use v5.14;

package LacunaWaX::Schedule::Lottery {
    use Carp;
    use English qw( -no_match_vars );
    use LacunaWaX::Model::Lottery::Links;
    use LWP::UserAgent;
    use Moose;
    use Try::Tiny;

### POD {#{{{

=head2 Review

There is a limited number of links to voting sites (15 right now) per server.  
Clicking each link counts as a single entry in the lottery /in the zone in 
which the entertainment district exists/.

Those 15 links can be played, in any combination, across the user's Ent Dists.  
Each link can be played once every 24 hours.

LacunaWaX allows the user to create 15 assignments (one per link, the number 
of assignment slots will increase if the game increases the number of playable 
links).

So, LacunaWaX will have 15 "play" assginments (10 at Ent Dist 1, 5 at Ent Dist 
2, or whatever) to play the 15 links.  The lottery scheduled task will attempt 
to click a link for each of those 15 assignments.


The possible issue is that, it's entirely possible for the user to (eg) 
manually click two of those 15 links.  As far as LacunaWaX is concerned, the 
user still has 15 assignments.  But as far as the game is concerned, the user 
only has 13 more playable links (today).


So, it's entirely possible for the play() method to be called when there are 
no more actual links to be played.  If that happens, play() will throw an 
exception that's meant to indicate that we should stop attempting to play the 
lottery on this server; we're done.

=cut

### }#}}}

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
        return $self;
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

        my @server_recs = $self->schema->resultset('Servers')->search()->all;   ## no critic qw(ProhibitLongChainsOfMethodCalls)

        foreach my $server_rec( @server_recs ) {
            my $server_count = try {
                $self->play_server($server_rec);
            }
            catch {
                chomp(my $msg = $_);
                $self->logger->error($msg);
                return;
            } or return;
        }
        $self->logger->info("The lottery has been played on all servers.");
        return;
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

        my @lottery_planet_recs = $self->schema->resultset('LotteryPrefs')->search({    ## no critic qw(ProhibitLongChainsOfMethodCalls)
            server_id => $server_rec->id
        })->all;

        LOTTERY_RECORD:
        foreach my $lottery_rec(@lottery_planet_recs) {
            unless( $self->has_links ) {
                ### Create the links just once per server...
                $self->make_links( $lottery_rec->body_id );
            }

            my $pname = $self->game_client->planet_name($lottery_rec->body_id);
            try {
                $self->play_lottery($lottery_rec);
            }
            catch {
                $self->logger->error("Unable to play lottery on $pname: $ARG");
            } or next LOTTERY_RECORD;
        }

        ### ...clear the links again before working on the next server.
        $self->clear_links;
        return 1;
    }#}}}
    sub play_lottery {#{{{
        my $self        = shift;
        my $lottery_rec = shift;    # LotteryPrefs table record

        return unless $lottery_rec->count;
        unless( $self->has_links ) {
            croak "We need to have links set up before playing a planet.";    # wtf?
        }

        ### Make sure the links are using the lottery record's planet's ID so 
        ### our plays will take place in the correct zone.
        unless( $lottery_rec->body_id eq $self->links->planet_id ) {
            try {
                $self->links->change_planet($lottery_rec->body_id);
            }
            catch {
                my $msg = (ref $_) ? $_->text : $_;
                croak "Unable to change links' planet to " . $lottery_rec->body_id . " - $msg";
            }
        }

        my $pname = $self->game_client->planet_name($lottery_rec->body_id);
        $self->logger->info("Playing lottery " . $lottery_rec->count . " times on $pname ");

        if( $self->links->remaining <= 0 ) {
            $self->logger->info("You've already played out the lottery on this server today.");
            return;
        }
        $self->logger->info("There are " . $self->links->remaining . " lottery links left to play.");

        for( 1..$lottery_rec->count ) {
            $self->play();
        }

        return;
    }#}}}
    sub play {#{{{
        my $self    = shift;
        my $plays   = 0;

=head2 play 

Attempts to play the next link in $self->links.

If $self->links->next returns undef, we're at the end of our list of links for 
the entire server.  In that case, play() will throw an exception.

That exception needs to be caught further up the chain to keep from attempting 
to play any remaining assignments.

=head3 Failed $ua->get

When an attempt to hit the voting site link with our LWP::UserAgent object 
fails, we still count that link as having been played in the lottery.

When we reach the point of attempting to hit the lottery URL, we've jalready 
pinged the TLE server, so we're reasonably sure it's still up.

Lottery links first hit the TLE server, recording the fact that we've clicked 
the link and played the lottery.  After that, the TLE server redirects us to 
the voting site.

So a $ua failure means that, though we were unable to hit the final 
destination voting website, we almost certainly _were_ able to hit the TLE 
server, which recorded the attempt as a successful lottery play.

=cut

        unless( $self->has_links ) {
            ### This is a carp because we really don't expect to ever hit 
            ### this; if we get to this point, we _should_ ->has_links.
            carp "We need to have links set up before playing the lottery.";
        }

        my $link = $self->links->next or do {
            ### This is a die because we do fully expect to hit this 
            ### periodically, and we don't need carp's extra info (line 
            ### number, etc) showing up in the logs.
            die "I ran out of links before playing all assigned slots.\n"; ## no critic qw(RequireCarping)
        };
        $self->logger->info("Trying link for " . $link->name);

### CHECK
$link->url('http://www.google.com');
        my $resp = $self->ua->get($link->url);
        if( $resp->is_success ) {
            $self->logger->info(" -- Success!");
            $plays++;
        }
        else {
            $self->logger->error(" -- Failure! " . $resp->status_line);
            $self->logger->error(" -- This /probably/ means that the voting site is down, but you /probably/ still got credit for this vote.");
            $plays++;
        }

        return $plays;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

1;
