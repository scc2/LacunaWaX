
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
            Wx::Size->new(500,300)
        );
        $v->SetFont( $self->get_font('/para_text_2') );
        return $v;
    }#}}}
    sub _build_text {#{{{
        my $self = shift;
        my $txt = "Now that you've logged in, be sure to check the Preferences window again.\n
You had to check it to enter your empire name and password, but now that you're logged in, there are new options there that weren't available before logging in.\n
*** Also, PLEASE eyeball the list of bodies in the tree to the left. ***\n
If any of the listed bodies are new, they're probably space stations.  For this program to be able recognize the difference between a space station and a planet, you have to double-click the station's name on the left there. \n
Doing so will let LacunaWaX figure out whether the new body is a station or not.  You only need to do this one time per new station - once you've done it once, LacunaWaX will remember that it's a station.\n";
        return $txt;
        
    }#}}}
    sub _set_events {}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;
