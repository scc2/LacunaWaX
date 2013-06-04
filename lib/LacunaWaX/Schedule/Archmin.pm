use v5.14;

package LacunaWaX::Schedule::Archmin {
    use List::Util qw(first);
    use Moose;
    use Try::Tiny;
    with 'LacunaWaX::Roles::ScheduledTask';

    has GLYPH_CARGO_SIZE => (
        is      => 'ro',
        isa     => 'Str',
        lazy    => 1,
        default => 100,
    );

    sub BUILD {
        my $self = shift;
        $self->logger->component('Archmin');
        return $self;
    }

    sub push_all_servers {#{{{
        my $self = shift;
        my $ttl  = 0;

        my @server_recs = $self->schema->resultset('Servers')->search()->all;
        foreach my $server_rec( @server_recs ) {
            my $server_pushes = $self->push_server($server_rec);
            $self->logger->info("Performed $server_pushes glyph pushes on this server.");
            $ttl += $server_pushes;
        }

        $self->logger->info("Performed $ttl total glyph pushes on all servers.");
        $self->logger->info("- Glyph Push Complete -");
        return $ttl;
    }#}}}
    sub push_server {#{{{
        my $self   = shift;
        my $s_rec  = shift;   # Servers table record
        my $pushes = 0;

        $self->logger->info("Pushing glyphs on server " . $s_rec->id);
        unless( $self->game_connect($s_rec->id) ) {
            $self->logger->info("Failed to connect to " . $s_rec->name . " - check your credentials!");
            return $pushes;
        }

        my @am_recs = $self->schema->resultset('ArchMinPrefs')->search({server_id => $s_rec->id})->all;
        $self->logger->info("User has Arch Min pref records on " . @am_recs . " planets.");
        foreach my $am_rec(@am_recs) {
            $pushes += $self->push_body($am_rec) || 0;
        }

        return $pushes;
    }#}}}
    sub push_body {#{{{
        my $self   = shift;
        my $am_rec = shift; 
        my $pushes = 0;

        my $body_name = $self->game_client->planet_name($am_rec->body_id);

        unless($body_name) {
            $self->logger->info("Scheduler found prefs for a planet that you've since abandoned; deleting that pref.");
            $am_rec->delete;
            return $pushes;
        }

        #unless( ($am_rec->glyph_home_id and $am_rec->pusher_ship_name) or $am_rec->auto_search_for ) {
        if( $am_rec->glyph_home_id and $am_rec->pusher_ship_name ) {
            $self->logger->info("Pushing glyphs from $body_name.");
        }
        else {
            $self->logger->info("No glyph push set up for $body_name.");
            return $pushes;
        }

        $pushes = $self->push_glyphs($am_rec);
        return $pushes;
    }#}}}
    sub push_glyphs {#{{{
        my $self   = shift;
        my $am_rec = shift;    # ArchMinPrefs record
        my $pushes = 0;

=head2 push_glyphs

Pushes glyphs from one body to another.  Origin and target are both 
represented by the ArchMinPrefs record passed as the first argument.

=cut

        my $this_body_name = $self->game_client->planet_name($am_rec->body_id) or return $pushes;

        unless( $am_rec->glyph_home_id and $am_rec->pusher_ship_name ) {
            $self->logger->info("- No glyph push requested.");
            return $pushes;
        }

        my $glyph_home_name;
        unless( $glyph_home_name = $self->planet_exists($am_rec->glyph_home_id) ) {
            $self->logger->info("- Specified glyph home is invalid; perhaps it was abandoned?");
        }
        $self->logger->info("- Planning to push to $glyph_home_name.");

        my $pusher_ship = $self->ship_exists($am_rec->pusher_ship_name, $am_rec->body_id);
        unless($pusher_ship) {
            $self->logger->info("- Requested pusher ship " . $am_rec->pusher_ship_name . " either does not exist or is not currently available.");
            return $pushes;
        }
        my $hold_size = $pusher_ship->{'hold_size'} || 0;
        $self->logger->info("- Pushing with ship " . $am_rec->pusher_ship_name . q{.});

        my $glyphs;
        unless( $glyphs = $self->get_glyphs_available($am_rec->body_id) ) {
            $self->logger->info("- No glyphs are on $this_body_name right now.");
            return $pushes;
        }
        $self->logger->debug( scalar @{$glyphs} . " glyphs onsite about to be pushed.");

        my $cargo = $self->load_glyphs_in_cargo($glyphs, $hold_size);
        $pushes = scalar @{$cargo};
        unless( $pushes ) { # Don't attempt the push with zero glyphs
            $self->logger->info("- Cargo is empty, nothing to push home.");
            return $pushes;
        }

        my $trademin = $self->get_trademin($am_rec->body_id);
        my $rv = try {
            $trademin->push_items($am_rec->glyph_home_id, $cargo, {ship_id => $pusher_ship->{'id'}});
        }
        catch {
            $self->logger->error("Attempt to push glyphs failed with: $_");
            return $pushes;
        };
        $rv or return $pushes;

        $self->logger->info("- Pushed $pushes glyphs to $glyph_home_name.");
        return $pushes;
    }#}}}

    sub search_all_servers {#{{{
        my $self = shift;
        my $ttl  = 0;

        my @server_recs = $self->schema->resultset('Servers')->search()->all;
        foreach my $server_rec( @server_recs ) {
            my $server_searches = $self->search_server($server_rec);
            $self->logger->info("Performed $server_searches searches on this server.");
            $ttl += $server_searches;
        }

        $self->logger->info("Performed $ttl total searches on all servers.");
        $self->logger->info("- Searches Complete -");
        return;
    }#}}}
    sub search_server {#{{{
        my $self   = shift;
        my $s_rec  = shift;   # Servers table record
        my $searches = 0;

        $self->logger->info("Searching Arch Mins on server " . $s_rec->id);
        unless( $self->game_connect($s_rec->id) ) {
            $self->logger->info("Failed to connect to " . $s_rec->name . " - check your credentials!");
            return $searches;
        }

        my @am_recs = $self->schema->resultset('ArchMinPrefs')->search({server_id => $s_rec->id})->all;
        $self->logger->info("User has Arch Min pref records on " . @am_recs . " planets.");
        foreach my $am_rec(@am_recs) {
            $searches += $self->search_body($am_rec) || 0;
        }

        return $searches;
    }#}}}
    sub search_body {#{{{
        my $self   = shift;
        my $am_rec = shift; 
        my $searches = 0;

        my $body_name = $self->game_client->planet_name($am_rec->body_id);

        unless($body_name) {
            $self->logger->info("Scheduler found prefs for a planet that you've since abandoned; deleting that pref.");
            $am_rec->delete;
            return $searches;
        }

        if( $am_rec->auto_search_for ) {
            $self->logger->info("Searching for " . $am_rec->auto_search_for . " on $body_name.");
        }
        else {
            $self->logger->info("No auto search set up for $body_name.");
            return $searches;
        }

        $searches = $self->search($am_rec);
        return $searches;
    }#}}}
    sub search {#{{{
        my $self     = shift;
        my $am_rec   = shift;
        my $searches = 0;

        my $body_name = $self->game_client->planet_name($am_rec->body_id) or return;
        my $ore_types = $self->game_client->ore_types;

        unless( $am_rec->auto_search_for ~~ $ore_types ) {
            $self->logger->error("Somehow you're attempting to search for an invalid ore type.");
            return $searches;
        }

        my $archmin = try {
            $self->game_client->get_building($am_rec->body_id, 'Archaeology');
        }
        catch {
            $self->logger->error("Attempt to get archmin failed with: $_");
            return $searches;
        };
        unless($archmin) {
            $self->logger->info("- No Arch Min exists.");
            return $searches;
        }

        ### Arch Min is currently idle?
        my $view = try {
            $archmin->view;
        }
        catch {
            my $msg = (ref $_) ? $_->text : $_;
            $self->logger->error("Could not get archmin view: $msg");
        };
        ref $view eq 'HASH' or return $searches;
        if( my $work = $view->{'building'}{'work'} ) {
            my $glyph     = $work->{'searching'};
            my $secs_left = $work->{'seconds_remaining'};
            $self->logger->info("- Already searching for a $glyph glyph; complete in $secs_left seconds.");
            return $searches;
        }

        ### Get ores available to this arch min
        my $ores_onsite = try {
            $archmin->get_ores_available_for_processing;
        }
        catch {
            my $msg = (ref $_) ? $_->text : $_;
            $self->logger->error("Could not get ores for processing: $msg");
        };
        ref $ores_onsite eq 'HASH' or return $searches;
        unless( defined $ores_onsite->{'ore'} and %{$ores_onsite->{'ore'}} ) {
            $self->logger->info("- Not enough of any type of ore to search.");
            return $searches;
        }

        ### If the type requested by the user is not available, chose another 
        ### type to search for at 'random'.
        my $ore_to_search = q{};
        if( defined $ores_onsite->{'ore'}{$am_rec->auto_search_for} ) {
            $ore_to_search = $am_rec->auto_search_for;
        }
        else {
            ($ore_to_search) = keys %{$ores_onsite->{'ore'}};
            $self->logger->info("- There's not enough " . $am_rec->auto_search_for . " ore to perform a search.");
            $self->logger->info("    Searching instead for $ore_to_search.");
        }
        unless($ore_to_search) {
            $self->logger->error("I can't figure out what to search for; we should never get here.");
            return $searches;
        }

        ### Perform the search
        $searches = try {
            my $rv = $archmin->search_for_glyph($ore_to_search);
            $self->logger->info("- Arch Min is now searching for one $ore_to_search glyph.");
            return 1;
        }
        catch {
            my $msg = (ref $_) ? $_->text : $_;
            $self->logger->error("Arch Min ore search failed: $msg");
            return 0;
        };

        return $searches;
    }#}}}



### CHECK
### these two might be better off in Client.pm
    sub planet_exists {#{{{
        my $self = shift;
        my $pid  = shift;
        my $glyph_home_name = $self->game_client->planet_name($pid);
        return $glyph_home_name;    # undef if the pid wasn't found
    }#}}}
    sub ship_exists {#{{{
        my $self        = shift;
        my $ship_name   = shift;
        my $pid         = shift;

        my $ships = $self->game_client->get_available_ships($pid);
        my($ship) = first{ $_->{'name'} eq $ship_name }@{$ships};
        return $ship;
    }#}}}

### CHECK
### Heck, these might as well.
    sub get_glyphs_available {#{{{
        my $self    = shift;
        my $pid     = shift;

        my $trademin = $self->get_trademin($pid);
        my $glyphs_rv = try {
            $trademin->get_glyph_summary;
        };

        unless( ref $glyphs_rv eq 'HASH' and defined $glyphs_rv->{'glyphs'} and @{$glyphs_rv->{'glyphs'}} ) {
            return;
        }

        return $glyphs_rv->{'glyphs'};
    }#}}}
    sub get_trademin {#{{{
        my $self        = shift;
        my $pid         = shift;

        my $trademin = try {
            $self->game_client->get_building($pid, 'Trade');
        };

        return $trademin;
    }#}}}
    sub load_glyphs_in_cargo {#{{{
        my $self        = shift;
        my $glyphs      = shift;
        my $hold_size   = shift;

=head2 load_glyphs_in_cargo

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
            if( $count * $self->GLYPH_CARGO_SIZE > $hold_size ) { # Whoops
                $count -= $g->{'quantity'};
                last ADD_GLYPHS;
            }
            push @{$cargo}, {type => 'glyph', name => $g->{'name'}, quantity => $g->{'quantity'}};
        }
        return $cargo;
    }#}}}


    no Moose;
    __PACKAGE__->meta->make_immutable;
}

1;
