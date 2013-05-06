use v5.14;
package Games::Lacuna::Client::Task::Empire;
use Games::Lacuna::Client::Task::Mailbox;
use Games::Lacuna::Client::Task::Planet;
use Games::Lacuna::Client::Task::Station;
use Data::Dumper;
use Moose;
with 'Games::Lacuna::Client::Task';

### POD {#{{{

=head1 NAME

Games::Lacuna::Client::Task::Empire - Manage tasks that affect your entire 
empire.

=head1 SYNOPSIS

 my $client = Games::Lacuna::Client::App->new({ ... });
 my $empire = Games::Lacuna::Client::Task::Empire->new({ client => $client });

 my $bodies   = $empire->bodies;    # bodies is   { body_name    => body_id }
 my $planets  = $empire->planets;   # planets is  { planet_name  => planet_object }
 my $stations = $empire->stations;  # stations is { station_name => station_object }

 say "My empire's name is " . $empire->name;
 say "My empire's id is " . $empire->id;

 $bs_cnt  = $empire->build_ships;
 $et_cnt  = $empire->empty_trash;
 $r_cnt   = $empire->recycle;
 $g_cnt   = $empire->search_for_glyphs;
 $obs_cnt = $empire->update_observatory;
 $hll_cnt = $empire->build_halls;

=head1 DESCRIPTION

Describes an empire, and provides a number of methods that get called on all 
planets in the empire.

=head1 BODIES vs PLANETS and STATIONS

An empire object knows, at creation, the names and IDs of its bodies.  But it 
doesn't know if each of those bodies is a planet or a space station.  To find 
that out, I<the server must be queried for each body>, which takes 1-2 seconds 
I<per body>.  

Calling either C<$empire->planets> or C<$empire->stations> forces those 
individual server queries, and each space station actually has to query the 
server twice.

=head1 Attributes

=head2 id, name

Return the id and name of your empire.

=head1 Methods

=head2 build_ships, empty_trash, recycle, search_for_glyphs, update_observatory

Each of these calls the identically-named method from L<Games::Lacuna::Task::Planet> 
once for each planet in your empire, and returns a count of the total number of 
affected items.

=over4

=item build_ships returns the number of ships added to shipyard build queues

=item empty_trash returns the number of scows sent on waste runs

=item recycle returns the number of recycling centers that started a recycling task

=item search_for_glyphs returns the number of glyph searches started

=item update_observatory returns the number of records updated or inserted in the Planets table

=back

=cut

### }#}}}
BEGIN {#{{{
    ### $Id: Empire.pm 14 2012-12-10 23:19:27Z jon $
    ### $URL: https://tmtowtdi.gotdns.com:15000/svn/LacunaWaX/trunk/lib/Games/Lacuna/Client/Task/Empire.pm $
    my $revision = '$Rev: 14 $';
    $Games::Lacuna::CLient::Task::Planet::VERSION = '0.1.' . join '', $revision =~ m/(\d+)/;
}#}}}

has ['id', 'name'] => ( isa => 'Str', is => 'rw', lazy_build => 1 );
has 'empire' => (
    is         => 'rw',
    isa        => 'Games::Lacuna::Client::Empire',
    lazy_build => 1,
);
has 'status' => (
    is         => 'rw',
    isa        => 'HashRef',
    lazy_build => 1,
    documentation => q{ hashref returned by Games::Lacuna::Client::Empire->get_status() },
);
has 'bodies' => (
    is            => 'rw',
    isa           => 'HashRef[Int]',
    lazy_build    => 1,
    documentation => q{ Simple hashref; planet_name => planet_id - no planet objects involved. }
);
has 'planets' => (
    is            => 'rw',
    isa           => 'HashRef[Games::Lacuna::Client::Task::Planet]',
    lazy_build    => 1,
    documentation => q{
        Keyed off the planets' names, value is planet object.
        Calling this is very slow; avoid if possible.
    }
);
has 'planet_ids' => (
    is            => 'rw',
    isa           => 'HashRef[Games::Lacuna::Client::Task::Planet]', 
    lazy_build    => 1,
    documentation => q{ Identical to 'planets' above except this is keyed off planet IDs, not names. },
);
has 'stations' => (
    is            => 'rw',
    isa           => 'HashRef[Games::Lacuna::Client::Task::Station]', 
    lazy_build    => 1,
    documentation => q{ Keyed off the stations' names, value is station object. }
);
has 'mailbox' => (
    is         => 'rw', 
    isa        => 'Games::Lacuna::Client::Task::Mailbox', 
    lazy_build => 1, 
);
has 'wrapped_planet_methods' => (
    is => 'ro',
    isa => 'ArrayRef',
    default => sub {[ qw(
            build_ships
            dump_probes
            empty_trash
            push_glyphs
            recycle
            res_push
            search_for_glyphs
            train_spies
            update_observatory
    ) ]},
    documentation => q{
        These methods get called on each planet in the empire.  Each takes an  
        empty argument list and returns an integer count of the number of $things 
        it did successfully.  
        Since the input and output prototypes are the same, these methods get 
        generated dynamically when the empire object is built.
    },
);

sub BUILD {#{{{
    my( $self, @params ) = @_;
    my $c = $self->client;

    my $meta = __PACKAGE__ ->meta;
    my $wpm = $self->wrapped_planet_methods;
    foreach my $meth(@$wpm) {
        ### Stops us from dynamically creating these methods if they've 
        ### already been created, which is illegal once we set make_immutable 
        ### below.
        next if $self->can($meth);

        die "Planet can't do $meth; check your spelling" unless Games::Lacuna::Client::Task::Planet->can($meth);
        $meta->add_method(
            $meth => sub {
                my $self = shift;
                my @args = @_;
                my $cnt  = 0;
                my $planets = $self->planets;
                foreach my $name (sort keys %$planets) {
                    $cnt += $c->call( $self->planets->{$name}, $meth, [@args] );
                }
                return $cnt;
            }
        )
    }
    $meta->make_immutable;
}#}}}
sub _build_bodies {#{{{
    my $self = shift;
    return { reverse %{$self->status->{'empire'}{'planets'}} };
}#}}}
sub _build_empire {#{{{
    my $self = shift;
    my $c    = $self->client;
    my $emp = $c->call($c, 'empire', [name => $c->name] );
    return $emp;
}#}}}
sub _build_id {#{{{
    my $self = shift;
    return $self->status->{empire}{id};
}#}}}
sub _build_mailbox {#{{{
    my $self = shift;
    my $c    = $self->client;

    my $mb = $c->call( 'Games::Lacuna::Client::Task::Mailbox', 'new', [client => $c] );
    die "Unable to access mailbox; unknown error"
        unless ref $mb eq 'Games::Lacuna::Client::Task::Mailbox';
    return $mb;
};#}}}
sub _build_name {#{{{
    my $self = shift;
    return $self->status->{empire}{name};
}#}}}
sub _build_planet_ids {#{{{
    my $self = shift;
    my $hr = {};
    my $planets = $self->planets;
    foreach my $pname( keys %$planets ) {
        my $pobj = $self->planets->{$pname};
        $hr->{ $pobj->id } = $pobj;
    }
    return $hr;
}#}}}
sub _build_planets {#{{{
    my $self = shift;
    my $c    = $self->client;

    my $planets_hr = $self->status->{'empire'}{'planets'};
    my $planet_objects  = {};
    my $station_objects = {};
    foreach my $pid( keys %$planets_hr ) {
        my $pname = $planets_hr->{$pid};
### Each planet takes 1-2 seconds to build.  For an empire with 24 planets 
### plus however many SSs, that's way too long.
#warn "building planet $pname: " . time() . "\n";
        my $body  = Games::Lacuna::Client::Task::Planet->new({ 
            client      => $self->client, 
            id          => $pid,
            empire_id   => $self->id,
        });
        if( $body->type eq 'habitable planet' or $body->type eq 'gas giant' ) {
            $planet_objects->{$pname} = $body;
        }
        elsif( $body->type eq 'space station' ) {
            ### $body is currently a GLCTPlanet - re-bless to Station, and 
            ### re-grab the correct server data.
            $station_objects->{$pname} = bless $body, 'Games::Lacuna::Client::Task::Station';
            ### Don't force the station to re-query the server right now, but 
            ### indicate that its server data is stale so it'll be re-queried 
            ### if needed.
            $station_objects->{$pname}->server_data_age( DateTime->new(year => 1970) );
        }
    }

    $self->planets ( $planet_objects  );
    $self->stations( $station_objects );

    return $self->planets;
}#}}}
sub _build_stations {#{{{
    my $self = shift;
    ### Calling ->planets invokes its builder if it hasn't already been 
    ### invoked.  That builder also sets up stations.
    my $p = $self->planets;
    return $self->stations;
}#}}}
sub _build_status {#{{{
    my $self = shift;
    my $c    = $self->client;
    my $status  = $c->call($self->empire, 'get_status');
    return $status;
}#}}}#}}}

sub build_halls {#{{{
    my $self = shift;
    my $c    = $self->client;

=head2 build_halls

Creates as many Halls of Vrbansk as it can, using the glyphs at your glyph_home.

 my $num_halls_built = $empire->build_halls;

Variable RPC
Base usage of 1 plus 1 per Halls that gets created
(I think; I haven't actually counted).

=cut

    my $arch_min = $self->glyph_home->get_buildings('Archaeology Ministry')->[0]
        or die "Could not get arch min for the planet set as your 'glyph_home' in prefs file.  Check spelling.";

    my $halls_built = 0;
    RECIPE:
    foreach my $recipe(@{$self->client->ute->hall_recipes}) {
        my $ingredient_count = 0;
        map{ $ingredient_count++ if scalar @{$self->glyphs_at_home->{$_}} }@$recipe;
        next RECIPE unless $ingredient_count == 4;
        my $glyph_ids = [];
        foreach my $ore(@$recipe) {
            my $g = shift @{$self->glyphs_at_home->{$ore}};
            push @$glyph_ids, $g->{'id'};
        }
        my $rv = $c->call( $arch_min, 'assemble_glyphs', [$glyph_ids] );
        $c->log->debug("Built a $rv->{'item_name'}.");
        $halls_built++;
        ### In case we have enough glyphs to do the recipe >1 time.
        redo RECIPE;
    }

    return $halls_built;
}#}}}
sub deserialize_planet {#{{{
    my $self = shift;
    my $ser  = shift;

=head2 deserialize_planet

Returns either a Planet or Station object from a serialized string, usually 
from a cache.

Despite the method's name, this I<will> return a Station object rather than a 
Planet object if that's what was originally serialized.

 my $ser_string = <some planet's serialized string you dug out of a cache or other storage>;
 my $planet = $empire->deserialize_planet($ser_string);

=cut

    my $planet = Games::Lacuna::Client::Task::Planet->deserialize( $ser, $self->client );
    return $planet;
}#}}}
sub find_fetchable_spies {#{{{
    my $self      = shift;
    my $max_ships = shift || 999;

=pod

Returns all spies who are both assigned to the task 'allow_fetch' and who are 
currently Idle.

Accepts one optional argument, the max number of planets to check for spies.  
This will generally be the number of fetching ships you've got available.  
We're making the assumption that all fetchable spies on any given planet will 
fit on a single fetch ship.  Sending this argument when you have fewer ships 
than planets with fetchable spies will definitely speed up this call.

Return is a hashref:

 {
  planet_id_1 => [ fetchable_spy_id_1, fetchable_spy_id_2, ... ],
  planet_id_2 => [ fetchable_spy_id_1, fetchable_spy_id_2, ... ],
  ...
 }

=cut

    my $c            = $self->client;
    my $schema       = $c->users_schema;
    my $u            = $schema->resultset('Login')->find({ username => $self->name });
    my $planet_spies = {};

    my %want_fetched = ();
    my $spy_rs = $u->spy_prefs;
    while(my $spy_rec = $spy_rs->next) {
        if( $spy_rec->task->name eq 'allow_fetch' ) {
            $want_fetched{$spy_rec->spy_id} = $spy_rec;
        }
    }
    unless( scalar keys %want_fetched ) {
        $c->log->debug("No spies are assigned to the allow_fetch task.");
        return $planet_spies;
    }

    my $planet_with_spies_cnt = 0;
    PLANET:
    foreach my $pname( keys %{$self->planets} ) {
        my $planet = $self->planets->{$pname};
        my $spies  = $planet->get_spies;
        my @can_be_fetched = ();
        foreach my $spy_id( keys %$spies ) {
            delete $want_fetched{ $spy_id } if defined $want_fetched{ $spy_id };
            if( $spies->{$spy_id}->{assignment} eq 'Idle' ) {
                push @can_be_fetched, $spy_id;
            }
        }
        if( scalar @can_be_fetched ) {
            $planet_spies->{$planet->id} = \@can_be_fetched;
            $planet_with_spies_cnt++;
        }
        last PLANET unless keys %want_fetched;
        last PLANET if $planet_with_spies_cnt >= $max_ships;
    }
    return $planet_spies;
}#}}}
sub valid_planet_name {#{{{
    my $self  = shift;
    my $pname = shift;

=head2 valid_planet_name

Returns true if arg is the name of one of our empire's planets

 say "got a planet" if $emp->valid_planet_name('SomePossibleName');

=cut

    return 1 if( defined $self->planets->{$pname} );
    return;
}#}}}

1;
__END__

=head1 AUTHOR

Jonathan D. Barton, E<lt>jdbarton@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Jonathan D. Barton

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut

