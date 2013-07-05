
package LacunaWaX::MainSplitterWindow {
    use v5.14;
    use Moose;
    use Try::Tiny;
    use Wx qw(:allclasses :everything);
    use Wx::Event qw(EVT_CLOSE);
    with 'LacunaWaX::Roles::GuiElement';

    use LacunaWaX::MainSplitterWindow::LeftPane;
    use LacunaWaX::MainSplitterWindow::RightPane;

    has 'size' => (is => 'rw', isa => 'Wx::Size', lazy_build => 1);

    has 'splitter_window'   => (is => 'rw', isa => 'Wx::SplitterWindow', lazy_build => 1);
    has 'main_sizer'        => (is => 'rw', isa => 'Wx::Sizer', lazy_build => 1);
    has 'min_pane_size'     => (is => 'rw', isa => 'Int', lazy => 1, default => 50);
    has 'init_sash_pos'     => (is => 'rw', isa => 'Int', lazy => 1, default => 200);
    has 'left_pane'         => (is => 'rw', isa => 'LacunaWaX::MainSplitterWindow::LeftPane',   lazy_build => 1);
    has 'right_pane'        => (is => 'rw', isa => 'LacunaWaX::MainSplitterWindow::RightPane',  lazy_build => 1);


    sub BUILD {
        my($self, @params) = @_;

        $self->splitter_window->Show(0);

        $self->splitter_window->SplitVertically($self->left_pane->main_panel, $self->right_pane->main_panel);
        $self->splitter_window->SetMinimumPaneSize( $self->min_pane_size );
        $self->splitter_window->SetSashPosition( $self->init_sash_pos, 1 );

        $self->main_sizer->Add($self->splitter_window, 1, wxEXPAND, 0);
        $self->parent->SetSizer($self->main_sizer);
        $self->splitter_window->Show(1);

        return $self;
    };
    sub _build_left_pane {#{{{
        my $self = shift;
        my $y = LacunaWaX::MainSplitterWindow::LeftPane->new(
            app      => $self->app,
            ancestor => $self,
            parent   => $self->splitter_window,
        );
        return $y;
    }#}}}
    sub _build_main_sizer {#{{{
        my $self = shift;
        my $y = Wx::BoxSizer->new(wxVERTICAL);
        return $y;
    }#}}}
    sub _build_right_pane {#{{{
        my $self = shift;
        my $y = LacunaWaX::MainSplitterWindow::RightPane->new(
            app      => $self->app,
            ancestor => $self,
            parent   => $self->splitter_window,
        );
        return $y;
    }#}}}
    sub _build_size {#{{{
        my $self = shift;
        my $y = $self->parent->GetSize;
        return $y;
    }#}}}
    sub _build_splitter_window {#{{{
        my $self = shift;
        my $y = Wx::SplitterWindow->new(
            $self->parent, -1, 
            wxDefaultPosition, 
            $self->size,
            wxSP_3D|wxSP_BORDER
        );
        return $y;
    }#}}}
    sub _set_events {#{{{
        my $self = shift;
        EVT_CLOSE($self->splitter_window, sub{$self->OnClose(@_)});
        return;
    }#}}}

=pod

The various focus methods are advisory only; they don't actually claim or kill 
focus.

If a focus-related event has been triggered and caused (eg) the right pane to be 
focused, you'd call focus_right(), and vice-versa.

If an event causes the entire MainSplitterWindow to lose focus (this will likely 
be an app-lost-focus event), call defocus().

You can then check which pane has focus with:

 $msw = <MainSplitterWindow object>;
 if( $msw->which_focus < 0 ) {
  say "The left pane has focus."
 }
 elsif( $msw->which_focus > 0 ) {
  say "The right pane has focus."
 }
 else {
  say "Neither pane has focus."
 }

=cut
    sub defocus {#{{{
        my $self = shift;
        $self->left_pane->has_focus(0);
        $self->right_pane->has_focus(0);
        return;
    }#}}}
    sub focus_left {#{{{
        my $self = shift;
        $self->left_pane->has_focus(1);
        $self->right_pane->has_focus(0);
        return;
    }#}}}
    sub focus_right {#{{{
        my $self = shift;
        $self->left_pane->has_focus(0);
        $self->right_pane->has_focus(1);
        return;
    }#}}}
    sub which_focus {#{{{
        my $self = shift;
        return -1 if $self->left_pane->has_focus();
        return 1 if $self->right_pane->has_focus();
        return 0;
    }#}}}

    sub hide {#{{{
        my $self = shift;
        $self->splitter_window->Show(0);
        return;
    }#}}}
    sub show {#{{{
        my $self = shift;
        $self->splitter_window->Show(1);
        return;
    }#}}}

    sub OnClose {#{{{
        my $self    = shift;

        if( $self->has_left_pane ) {
            $self->left_pane->OnClose if $self->left_pane->can('OnClose');
        }
        if( $self->has_right_pane ) {
            $self->right_pane->OnClose if $self->right_pane->can('OnClose');
        }
        return;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;
