
=pod

This absolutely must provide a main_panel as Wx::Panel for MainSplitterWindow to work.

=cut


package LacunaWaX::MainSplitterWindow::LeftPane {
    use v5.14;
    use English qw( -no_match_vars );
    use Moose;
    use Time::HiRes;
    use Try::Tiny;
    use Wx qw(:everything);
    with 'LacunaWaX::Roles::GuiElement';

    use LacunaWaX::MainSplitterWindow::LeftPane::BodiesTreeCtrl;

    has 'has_focus'     => (is => 'rw', isa => 'Int', lazy => 1, default => 0);
    has 'main_panel'    => (is => 'rw', isa => 'Wx::Panel');
    has 'main_sizer'    => (is => 'rw', isa => 'Wx::Sizer');
    has 'bodies_tree'   => (is => 'rw', isa => 'LacunaWaX::MainSplitterWindow::LeftPane::BodiesTreeCtrl');

    sub BUILD {
        my $self = shift;

        $self->main_panel(  Wx::Panel->new($self->parent, -1, wxDefaultPosition, wxDefaultSize) );

        $self->bodies_tree( 
            LacunaWaX::MainSplitterWindow::LeftPane::BodiesTreeCtrl->new(
                app         => $self->app,
                parent      => $self->main_panel, 
                ancestor    => $self,
            )
        );

        $self->main_sizer( Wx::BoxSizer->new(wxHORIZONTAL) );
        $self->main_sizer->Add($self->bodies_tree->treectrl, 1, wxEXPAND, 0);
        $self->main_panel->SetSizer($self->main_sizer);
        $self->main_sizer->SetMinSize(200, 1);
        return $self;
    }
    sub _set_events { }

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;
