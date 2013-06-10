use v5.14;

package LacunaWaX::Schedule::Spies {
    use Carp;
    use English qw( -no_match_vars );
    use List::Util qw(first);
    use Memoize;
    use Moose;
    use Try::Tiny;

    with 'LacunaWaX::Roles::ScheduledTask';

    has 'types_of_training' => (
        is      => 'ro',
        isa     => 'ArrayRef',
        traits  => ['Array'],
        lazy    => 1,
        default => sub{ [qw(Intel Mayhem Politics Theft)] },
        handles => {
            training_types => 'elements',
        }
    );

    sub BUILD {
        my $self = shift;
        $self->logger->component('Spies');
        memoize('get_int_min');
        memoize('get_spies');
        return $self;
    }

    sub train_all_servers {#{{{
        my $self    = shift;
        my $trained = 0;

        my $servers = [];
        my $servers_rs = $self->schema->resultset('Servers');
        while(my $server_rec = $servers_rs->next) {
            push @{$servers}, $server_rec;
        }

        foreach my $server_rec(@{$servers}) {
            my $cnt = $self->train_server($server_rec);
            $self->logger->info("$cnt spies trained on " . $server_rec->name . q{.});
            $trained += $cnt;
        }
        $self->logger->info("$trained spies trained on all servers.");
        return $trained;
    }#}}}
    sub train_server {#{{{
        my $self    = shift;
        my $s_rec   = shift;
        my $trained = 0;

        $self->logger->info("Attempting to train spies on server " . $s_rec->name);
        unless( $self->game_connect($s_rec->id) ) {
            $self->logger->info("Failed to connect to " . $s_rec->name . " - check your credentials!");
            return $trained;
        }

        foreach my $pid( values %{$self->game_client->planets} ) {
            $trained += $self->train_planet($pid, $s_rec->id);
        }
        $self->logger->info("$trained spies trained on " . $s_rec->name . q{.});
        return $trained;
    }#}}}
    sub train_planet {#{{{
        my $self    = shift;
        my $pid     = shift;
        my $sid     = shift;
        my $trained = 0;

        my $pname   = $self->game_client->planet_name($pid);

        ### Skip known stations
        if(
            my $rec = $self->schema->resultset('BodyTypes')->search({
                body_id         => $pid,
                server_id       => $sid,
                type_general    => 'space station'
            })->single
        ) {
            $self->logger->info("$pname is an SS - no spy training possible.");
            return 0;
        }
        $self->logger->info("Attempting to train spies on $pname.");

        my $avail_training_bldgs;
        unless( $avail_training_bldgs = $self->training_buildings_available($pid) ) {
            $self->logger->info("$pname has no spy training buildings; skipping.");
            return 0;
        }

        foreach my $type(keys %{$avail_training_bldgs}) {   # 'Intel', 'Mayhem', etc
            $self->logger->info("$pname has a $type training building.");
            my $cnt = $self->train_at_building($type, $avail_training_bldgs->{$type}) // 0;
            $trained += $cnt;
            $self->logger->info("$cnt spies trained at this building.");
        }

        return $trained;
    }#}}}
    sub train_at_building {#{{{
        my $self = shift;
        my $type = shift;
        my $bldg = shift;

        my $view = try   { $bldg->view; }
                   catch { return };
        $view and ref $view eq 'HASH' or return;

        my $spies = [];
        ### $view->{'spies'}{'training_costs'}{'time'} is an AoH
        ### https://us1.lacunaexpanse.com/api/IntelTraining.html
        if( defined $view->{'spies'}{'training_costs'}{'time'} and ref $view->{'spies'}{'training_costs'}{'time'} eq 'ARRAY' ) {
            $spies = $view->{'spies'}{'training_costs'}{'time'};
        }

        $self->logger->info(@{$spies} . " spies are available to train at this building.");
        my $trained = 0;
        foreach my $spy(@{$spies}) {
            $trained += $self->train_spy($spy, $type, $bldg);
        }

        return $trained;
    }#}}}
    sub train_spy {#{{{
        my $self    = shift;
        my $spy     = shift;
        my $type    = shift;
        my $bldg    = shift;
        my $trained = 0;

        if(
            my $rec = $self->schema->resultset('SpyTrainPrefs')->search({
                spy_id  => $spy->{'spy_id'},
                train   => (lc $type)
            })->single
        ) {
            unless( $self->is_idle($spy) ) {
                $self->logger->info("Spy $spy->{'name'} is available for training, but is set to Counter, so we won't train him.");
                return $trained;
            }
            my $rv = try {
                $bldg->train_spy($rec->spy_id);
            }
            catch {
                my $err = (ref $_ eq 'LacunaRPCException') ? $_->{'text'} : $_;
                $self->logger->error("Attempt to train spy returned '$err'.  Skipping spy.");
                return;
            };
            $rv and ref $rv eq 'HASH' or return $trained;

            if( $rv->{'trained'} ) {
                $self->logger->info("Spy $spy->{'name'} was trained in $type.");
                $trained++;
            }
            else {
                $self->logger->error("Spy $spy->{'name'} was not trained.");
            }
        }

        return $trained;
    }#}}}

    sub training_buildings_available {#{{{
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
        foreach my $type( $self->training_types ) {
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
    sub is_idle {#{{{
        my $self = shift;
        my $spy  = shift;

        my $int_min     = get_int_min($self->game_client, $spy->{'based_from'}{'body_id'}) or return;
        my $home_spies  = get_spies($int_min) or return;

        my $full_spy_info = first{ $_->{'name'} eq $spy->{'name'} }@{$home_spies};
        return( $full_spy_info->{'assignment'} eq 'Idle' ? 1 : 0 );
    }#}}}

    ### Subs, not methods.  Memoized.
    sub get_int_min {#{{{
        my $client  = shift;
        my $pid     = shift;
        my $int_min = try   { $client->get_building($pid, 'Intelligence'); }
                      catch { return; };
        return $int_min;
    }#}}}
    sub get_spies {#{{{
        my $int_min = shift;
        my $spies   = try   { $int_min->view_all_spies(); }
                      catch { return };
        return $spies->{'spies'} // undef;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

1;

__END__

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
