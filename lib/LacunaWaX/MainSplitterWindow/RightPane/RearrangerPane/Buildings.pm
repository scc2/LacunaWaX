
package LacunaWaX::MainSplitterWindow::RightPane::RearrangerPane::Buildings {
    use v5.14;
    use Carp;
    use Moose;
    use Try::Tiny;

    has 'buildings' => (
        is      => 'rw',
        isa     => 'HashRef',
        lazy    => 1,
        default => sub{ {} },
    );

    sub BUILD {
        my $self  = shift;
        my $bldgs = shift;

        my $b_hr = {};
        foreach my $bid( keys %{$bldgs} ) {
            my $hr                                  = $bldgs->{$bid};
            $hr->{bldg_id}                          = $bid;
            $self->buildings->{$hr->{x}}{$hr->{y}}  = $hr;
        }
        return $self;
    }

    sub by_loc {#{{{
        my $self = shift;
        my $x    = shift // croak "x and y coords are required";
        my $y    = shift // croak "x and y coords are required";
        return $self->buildings->{$x}{$y} // {};
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;

__END__

=head1 NAME

LacunaWaX::MainSplitterWindow::RightPane::RearrangerPane::Buildings 
- Collection to organize a colony's buildings by coordinates

=head1 SYNOPSIS

 $surface_bldgs = $client->get_buildings($planet_id);
 $bldgs = LacunaWaX::MainSplitterWindow::RightPane::RearrangerPane::Buildings->new( $surface_bldgs );

 $specific_bldg = $bldgs->by_loc(0, 0); # Will always be the PCC

