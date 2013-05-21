
package LacunaWaX::MainSplitterWindow::RightPane::RearrangerPane::Buttons {
    use v5.14;
    use Carp;
    use Moose;
    use Try::Tiny;

    has 'buttons' => (
        is      => 'rw',
        isa     => 'HashRef',
        lazy    => 1,
        default => sub{ {} },
    );

    sub add {#{{{
        my $self = shift;
        my $butt = shift;
        $self->buttons->{$butt->GetId} = $butt;
        return 1;
    }#}}}
    sub all {#{{{
        my $self = shift;
        return values %{$self->buttons};
    }#}}}
    sub by_id {#{{{
        my $self = shift;
        my $id   = shift // croak "ID is required";
        return $self->buttons->{$id} // {};
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;

__END__

=head1 NAME

LacunaWaX::MainSplitterWindow::RightPane::RearrangerPane::Buttons 
- Collection to organize the bitmap buttons on the Rearranger Pane.

=head1 SYNOPSIS

 $buttons = LacunaWaX::MainSplitterWindow::RightPane::RearrangerPane::Buildings->new();
 $butt    = LacunaWaX::MainSplitterWindow::RightPane::RearrangerPane::BitmapButton->new( ... );
 $buttons->add($butt);

 # Given a button id:
 $button = $buttons->by_id($id);

 @all_buttons = $buttons->all()

