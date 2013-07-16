
package LacunaWaX::MainSplitterWindow::RightPane::DefaultPane {
    use v5.14;
    use Moose;
    use Try::Tiny;
    use Wx qw(:everything);
    with 'LacunaWaX::Roles::MainSplitterWindow::RightPane';

    has 'sizer_debug'           => (is => 'rw', isa => 'Int', lazy => 1, default => 0);

    has 'text' => (is => 'rw', isa => 'Str', lazy_build => 1 );

    has 'header_sizer'      => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1   );
    has 'lbl_header'        => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1   );
    has 'lbl_text'          => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1   );

    sub BUILD {
        my $self = shift;

        $self->header_sizer->Add($self->lbl_header, 0, 0, 0);
        $self->content_sizer->Add($self->header_sizer, 0, 0, 0);
        $self->content_sizer->AddSpacer(20);
        $self->content_sizer->Add($self->lbl_text, 0, 0, 0);
        $self->refocus_window_name( 'lbl_header' );
        return $self;
    }
    sub _build_header_sizer {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxVERTICAL, 'Header');
    }#}}}
    sub _build_lbl_header {#{{{
        my $self = shift;
        my $v = Wx::StaticText->new(
            $self->parent, -1, 
            'Welcome',
            wxDefaultPosition, 
            Wx::Size->new(-1, 30)
        );
        $v->SetFont( $self->get_font('/header_1') );
        return $v;
    }#}}}
    sub _build_lbl_text {#{{{
        my $self = shift;
        my $v = Wx::StaticText->new(
            $self->parent, -1, 
            $self->text, 
            wxDefaultPosition, 
            Wx::Size->new(500,400)
        );
        $v->SetFont( $self->get_font('/para_text_2') );
        return $v;
    }#}}}
    sub _build_text {#{{{
        my $self = shift;

        my $txt = "Now that you've logged in, be sure to check the Preferences window again.

You had to check it to enter your empire name and password, but now that you're logged in, there are new options there that weren't available before logging in.

If any of your Space Stations in the tree on the left are displaying child leaves that would only apply to Planets, not stations (eg 'Glyphs', 'Lottery', 'Spies'), just double-click on the Station's name.  This will display a summary screen and update the tree to display the correct leaves.

The main LacunaWaX program you're looking at right now provides some tools, and also allows you to set up preferences for exactly what you want the scheduled tasks (like Autovote) to do.

But you must set those scheduled tasks up separately!

Be sure to see the Help documentation (Help menu, above, then choose Help to bring up the help browser).  Especially see the 'Set up Scheduled Programs' section!";

        return $txt;
    }#}}}
    sub _set_events {}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;
