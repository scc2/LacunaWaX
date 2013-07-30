
package LacunaWaX::Model::SStation {
    use v5.14;
    use utf8;
    use open qw(:std :utf8);
    use Data::Dumper;
    use Moose;
    use Try::Tiny;

    has 'id'        => (is => 'rw', isa => 'Int',       required => 1       );
    has 'name'      => (is => 'rw', isa => 'Str',       lazy_build => 1     );
    has 'status'    => (is => 'rw', isa => 'HashRef',   lazy_build => 1     );

    has 'game_client' => (
        is          => 'rw', 
        isa         => 'LacunaWaX::Model::Client', 
        required    => 1,
    );

    has 'police' => (
        is          => 'rw',
        isa         => 'Maybe[LacunaWaX::Model::SStation::Police]', 
        lazy_build  => 1,
        handles => {
            incoming_hostiles => 'incoming_hostiles',
            has_hostile_spies => 'has_hostile_spies',
        }
    );

    sub BUILD {
        my $self = shift;
    }
    sub _build_name {#{{{
        my $self = shift;
        return $self->game_client->planet_name ($self->id );
    }#}}}
    sub _build_police {#{{{
        my $self = shift;
        my $bldg = try {
            $self->game_client->get_building($self->id, 'Police');
        };

        my $popo = undef;
        if( $bldg ) {
            $popo = LacunaWaX::Model::SStation::Police->new( 
                precinct => $bldg,
                game_client => $self->game_client,
            )
        }
        return $popo;
    }#}}}
    sub _build_status {#{{{
        my $self = shift;
        my $s = try {
            $self->game_client->get_body_status( $self->id );
        }
        catch {
            $self->poperr("$_->{'text'} ($_)");
            return;
        };
        return $s;
    }#}}}

    sub subpar_res {#{{{
        my $self = shift;
        my $min  = shift;

        my $view = $self->game_client->get_building_view(
            $self->id, 
            $self->police->precinct,
        );

        foreach my $res( qw(food ore water energy) ) {
            my $rate = $res . '_hour';
            if( $view->{'status'}{'body'}{$rate} < $min ) {
                ### No need to report on all res types that are too low; as 
                ### soon as we find one, the user will have to go check on 
                ### that, and will see the others if they're too low as well.
                return $res;
            }
        }

        return 0;   # res/hr is fine
    }#}}}
    sub star_unseized {#{{{
        my $self = shift;

=pod

Returns true if the star orbited by the station has not been seized by anybody.

=cut

        return ( defined $self->status->{'station'} ) ? 0 : 1;
    }#}}}
    sub star_seized_by_other {#{{{
        my $self = shift;

=pod

Returns true if the star orbited by the station has been seized by a station 
other than the current station.

=cut

        return 0 if $self->star_unseized;
        if( $self->status->{'station'}{'name'} ne $self->name ) {
            return 1;
        }
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

1;

__END__

=head1 NAME

LacunaWaX::Model::Lottery::Link - Link to a voting site

=head1 SYNOPSIS

 use LacunaWaX::Model::Lottery::Link;

 $l = LacunaWaX::Model::Lottery::Link->new(
  name => $name,
  url  => $url
 );

=head1 DESCRIPTION

You won't normally need to use this module or construct objects from it 
explicitly.  Instead, you'll use L<LacunaWaX::Model::Lottery::Links|the Links 
module> to construct a list of links.

=cut
