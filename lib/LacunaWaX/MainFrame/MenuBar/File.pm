
package LacunaWaX::MainFrame::MenuBar::File {
    use v5.14;
    use Moose;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_MENU);
    with 'LacunaWaX::Roles::GuiElement';

    ### Wx::Menu is a non-hash object.  Extending such requires 
    ### MooseX::NonMoose::InsideOut instead of plain MooseX::NonMoose.
    use MooseX::NonMoose::InsideOut;
    extends 'Wx::Menu';

    use LacunaWaX::MainFrame::MenuBar::File::Connect;

    has 'itm_exit'      => (is => 'rw', isa => 'Wx::MenuItem',                                  lazy_build => 1);
    has 'itm_connect'   => (is => 'rw', isa => 'LacunaWaX::MainFrame::MenuBar::File::Connect',  lazy_build => 1);

    sub FOREIGNBUILDARGS {#{{{
        return; # Wx::Menu->new() takes no arguments
    }#}}}
    sub BUILD {
        my $self = shift;
        $self->AppendSubMenu    ( $self->itm_connect,   "&Connect...",  "Connect to a server"   );
        $self->Append           ( $self->itm_exit                                               );
        return $self;
    }

    sub _build_itm_exit {#{{{
        my $self = shift;
        return Wx::MenuItem->new(
            $self, -1,
            '&Exit',
            'Exit',
            wxITEM_NORMAL,
            undef   # if defined, this is a sub-menu
        );
    }#}}}
    sub _build_itm_connect {#{{{
        my $self = shift;
        return LacunaWaX::MainFrame::MenuBar::File::Connect->new(
            ancestor    => $self,
            app         => $self->app,
            parent      => $self->parent,   # MainFrame, not this Menu, is the parent.
        );
    }#}}}
    sub _set_events {#{{{
        my $self = shift;
        EVT_MENU($self->parent,  $self->itm_exit->GetId, sub{$self->OnQuit(@_)});
        return 1;
    }#}}}

    sub OnQuit {#{{{
        my $self  = shift;
        my $frame = shift;
        my $event = shift;
        $frame->Close(1);
        return 1;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

1;
