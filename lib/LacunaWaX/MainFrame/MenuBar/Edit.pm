
package LacunaWaX::MainFrame::MenuBar::Edit {
    use v5.14;
    use Moose;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_MENU);
    with 'LacunaWaX::Roles::GuiElement';

    use LacunaWaX::Dialog::Prefs;

    ### Wx::Menu is a non-hash object.  Extending such requires 
    ### MooseX::NonMoose::InsideOut instead of plain MooseX::NonMoose.
    use MooseX::NonMoose::InsideOut;
    extends 'Wx::Menu';

    has 'itm_prefs'   => (is => 'rw', isa => 'Wx::MenuItem',  lazy_build => 1);

    sub FOREIGNBUILDARGS {#{{{
        return; # Wx::Menu->new() takes no arguments
    }#}}}
    sub BUILD {
        my $self = shift;
        $self->Append( $self->itm_prefs );
        return $self;
    }

    sub _build_itm_prefs {#{{{
        my $self = shift;
        my $v = Wx::MenuItem->new(
            $self, -1,
            '&Preferences',
            'Preferences',
            wxITEM_NORMAL,
            undef   # if defined, this is a sub-menu
        );
        return $v;
    }#}}}
    sub _set_events {#{{{
        my $self = shift;
        EVT_MENU($self->parent,  $self->itm_prefs->GetId, sub{$self->OnPrefs(@_)});
    }#}}}

    sub OnPrefs {#{{{
        my $self = shift;

        ### Determine starting point of Prefs window
        my $top_window_point = $self->app->GetTopWindow()->GetPosition;
        my $self_origin = Wx::Point->new( $top_window_point->x + 30, $top_window_point->y + 30 );
        my $prefs_frame = LacunaWaX::Dialog::Prefs->new(
            app         => $self->app,
            ancestor    => $self,
            parent      => undef,
            title       => "Preferences",
            position    => $self_origin,
        );
        $prefs_frame->Show(1);
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

1;
