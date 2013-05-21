
=pod

The $text being displayed here is a single StaticText label, and it's a big ugly 
unweildy schmear and should be refactored.

=cut

package LacunaWaX::MainSplitterWindow::RightPane::SummaryPane {
    use v5.14;
    use utf8;
    use open qw(:std :utf8);
    use Moose;
    use Try::Tiny;
    use Wx qw(:everything);
    with 'LacunaWaX::Roles::MainSplitterWindow::RightPane';

    has 'sizer_debug' => (is => 'rw', isa => 'Int',  lazy => 1, default => 0 );

    has 'planet_name'   => (is => 'rw', isa => 'Str',       required => 1     );
    has 'planet_id'     => (is => 'rw', isa => 'Str',       lazy_build => 1   );
    has 'status'        => (is => 'rw', isa => 'HashRef',   lazy_build => 1   );
    has 'type'          => (is => 'rw', isa => 'Str',       lazy_build => 1   );
    has 'text'          => (is => 'rw', isa => 'Str',       lazy_build => 1   );
    has 'owner'         => (is => 'rw', isa => 'Str',       lazy_build => 1   );

    has 'szr_header'    => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1   );
    has 'lbl_header'    => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1   );
    has 'lbl_text'      => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1   );

    has 'refocus_window_name' => (is => 'rw', isa => 'Str', lazy => 1, default => 'lbl_header');

    sub BUILD {
        my $self = shift;

        $self->szr_header->Add($self->lbl_header, 0, 0, 0);
        $self->content_sizer->Add($self->szr_header, 0, 0, 0);
        $self->content_sizer->AddSpacer(20);
        $self->content_sizer->Add($self->lbl_text, 0, 0, 0);
        return $self;
    }
    sub _build_szr_header {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxVERTICAL, 'Header');
    }#}}}
    sub _build_lbl_header {#{{{
        my $self = shift;
        my $v = Wx::StaticText->new(
            $self->parent, -1, 
            $self->planet_name,
            wxDefaultPosition, 
            Wx::Size->new(-1, 30)
        );
        $v->SetFont( $self->app->wxbb->resolve(service => '/Fonts/header_1') );
        return $v;
    }#}}}
    sub _build_lbl_text {#{{{
        my $self = shift;
        my $v = Wx::StaticText->new(
            $self->parent, -1, 
            $self->text, 
            wxDefaultPosition, 
            Wx::Size->new(400,600)
        );
        $v->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_2') );
        return $v;
    }#}}}
    sub _build_owner {#{{{
        my $self = shift;
        return $self->status->{'empire'}{'name'} // 'Owner name unknown';
    }#}}}
    sub _build_planet_id {#{{{
        my $self = shift;
        return $self->app->game_client->planet_id( $self->planet_name );
    }#}}}
    sub _build_status {#{{{
        my $self = shift;

        my $s = try {
            $self->app->game_client->get_body_status( $self->planet_id );
        }
        catch {
            $self->app->poperr("$_->{'text'} ($_)");
            return;
        };
        return $s;
    }#}}}
    sub _build_text {#{{{
        my $self  = shift;
        my $owner = $self->owner;
        
        my $s = $self->status;

        my $text = $self->type . " $s->{name} ($s->{x}, $s->{y}) (ID $s->{id})
Owned by $owner
Orbit $s->{orbit} around $s->{star_name} (ID $s->{star_id}), in zone $s->{zone}\n";
        if( $self->type eq 'Station' ) {
            if( defined $s->{station} ) {
                if( $s->{'station'}{'name'} ne $s->{'name'} ) {
                    $text .= "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-\n";
                    $text .= "THIS STATION IS CURRENTLY UNDER CONTROL OF ANOTHER STATION ($s->{'station'}{'name'}) - THIS MIGHT BE A PROBLEM!\n";
                    $text .= "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-\n";
                }
            }
            else {
                $text .= "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-\n";
                $text .= "THIS STATION HAS NOT SEIZED ITS OWN STAR AND IS VULNERABLE - PLEASE GO FIX THAT!\n";
                $text .= "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-\n";
            }
        }
        elsif( defined $s->{'station'} ) {
            $text .= "Under control of station $s->{station}{name} (ID $s->{station}{id})\n";
        }
        $text .= "Size $s->{size}\n";
        $text .= "$s->{plots_available} plots available\n";
        $text .= "$s->{building_count} buildings\n";

        if( $self->type eq 'Station' ) {
            my($spent, $total) = @{$s->{'influence'}}{qw(spent total)};
            my $diff = $total - $spent;
            my $pl_star = ($diff == 1) ? 'star' : 'stars';
            $text .= "Influence: $spent/$total";
            if( $diff ) {
                $text .= " - this station can seize $diff more $pl_star.";
            }
            $text .= "\n";

            my $parl = try { $self->app->game_client->get_building($self->planet_id, 'Parliament') };
            my $laws = try { $parl->view_laws($self->planet_id) } if $parl;

            my @non_seizure_laws = ();
            LAW:
            foreach my $hr(@{$laws->{'laws'}}) {
                next LAW if $hr->{'name'} =~ /^Seize /;
                push @non_seizure_laws, $hr;
            }

            if( @non_seizure_laws ) {
                $text .= "\nLaws (other than star seizures):\n";
                $text .= "-------------------------------\n";
                foreach my $l(sort {$a->{'name'} cmp $b->{'name'}}@non_seizure_laws) {
                    $text .= "$l->{'name'}\n";
                }
            }
        }

        return $text;
    }#}}}
    sub _build_type {#{{{
        my $self  = shift;
        return ($self->status->{'type'} eq 'space station') ? 'Station' : 'Planet';
    }#}}}
    sub _set_events {}

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

1;

