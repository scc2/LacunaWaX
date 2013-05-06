


###
### Demonstrates adding scrollbars to a dialog.
### 


package LacunaWaX::Dialog::Test {
    use v5.14;
    use Moose;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_BUTTON EVT_CLOSE EVT_SIZE);
    with 'LacunaWaX::Roles::GuiElement';

    use LacunaWaX::Dialog::SitterManagerr::SitterRow;

    has 'row_spacer_size' => (is => 'rw', isa => 'Int', lazy => 1, default => 1,
        documentation => q{
            The pixel size of the horizontal spacer used to slightly separate each SitterRow
        }
    );

    has 'dialog'        => (is => 'rw', isa => 'Wx::Dialog',    lazy_build => 1);
    has 'title'         => (is => 'rw', isa => 'Str',           lazy => 1,      default => 'Sitter Manager');
    has 'position'      => (is => 'rw', isa => 'Wx::Point',     lazy => 1,      default => sub {wxDefaultPosition});
    has 'dialog_size'   => (is => 'rw', isa => 'Wx::Size',      lazy_build => 1);

    has 'main_sizer'     => (is => 'rw', isa => 'Wx::Sizer', lazy_build => 1, documentation => q{vertical});
    has 'scroll_sizer'   => (is => 'rw', isa => 'Wx::Sizer', lazy_build => 1, documentation => q{vertical});

    has 'swindow'        => (is => 'rw', isa => 'Wx::ScrolledWindow',    lazy_build => 1);

=pod


To add scrollbars to a Wx::Dialog:

    - Create the dialog
        - parent is undef
        - this does NOT get a sizer.

    - Create the Wx::ScrolledWindow
        - parent is the dialog
        - see _build_swindow() in here for that.
        - Also note the comment in there about always showing the scrollbars.

    - Create your controls
        - Their parent will be the _ScrolledWindow_

    - Create a sizer, put the controls in it as usual, call 
      ScrolledWindow->SetSizer  (not Dialog->SetSizer).

    - This is the part that fixes the funk with the scrollbars:
        - Dialog->Fit
        - ScrolledWindow->FitInside
        - Order does not seem to matter.

=cut

    sub BUILD {
        my($self, @params) = @_;

        $self->dialog->SetTitle("Testing.  Ignore me.");


    ### Pick one start

        ### Short enough to fit on screen without needing scrollbars.
        my( $w, $h ) = (50, 50);

        ### Tall enough that it does need scrollbars.
        #my( $w, $h ) = (50, 100);

    ### Pick one end


        my $st1 = Wx::StaticText->new(
            $self->swindow, -1, "Foo 1",
            wxDefaultPosition, Wx::Size->new($w, $h)
        );
        my $st2 = Wx::StaticText->new(
            $self->swindow, -1, "Foo 2",
            wxDefaultPosition, Wx::Size->new($w, $h)
        );
        my $st3 = Wx::StaticText->new(
            $self->swindow, -1, "Foo 3",
            wxDefaultPosition, Wx::Size->new($w, $h)
        );
        my $st4 = Wx::StaticText->new(
            $self->swindow, -1, "Foo 4",
            wxDefaultPosition, Wx::Size->new($w, $h)
        );
        my $st5 = Wx::StaticText->new(
            $self->swindow, -1, "Foo 5",
            wxDefaultPosition, Wx::Size->new($w, $h)
        );
        my $st6 = Wx::StaticText->new(
            $self->swindow, -1, "Foo 6",
            wxDefaultPosition, Wx::Size->new($w, $h)
        );
        my $st7 = Wx::StaticText->new(
            $self->swindow, -1, "Foo 7",
            wxDefaultPosition, Wx::Size->new($w, $h)
        );
        my $st8 = Wx::StaticText->new(
            $self->swindow, -1, "Foo 8",
            wxDefaultPosition, Wx::Size->new($w, $h)
        );


        $self->scroll_sizer->Add($st1, 0, 0, 0);
        $self->scroll_sizer->AddSpacer(5);
        $self->scroll_sizer->Add($st2, 0, 0, 0);
        $self->scroll_sizer->AddSpacer(5);
        $self->scroll_sizer->Add($st3, 0, 0, 0);
        $self->scroll_sizer->AddSpacer(5);
        $self->scroll_sizer->Add($st4, 0, 0, 0);
        $self->scroll_sizer->AddSpacer(5);
        $self->scroll_sizer->Add($st5, 0, 0, 0);
        $self->scroll_sizer->AddSpacer(5);
        $self->scroll_sizer->Add($st6, 0, 0, 0);
        $self->scroll_sizer->AddSpacer(5);
        $self->scroll_sizer->Add($st7, 0, 0, 0);
        $self->scroll_sizer->AddSpacer(5);
        $self->scroll_sizer->Add($st8, 0, 0, 0);
        $self->scroll_sizer->AddSpacer(5);

        $self->swindow->SetSizer($self->scroll_sizer);


        ### To see the "funk with the scrollbars", comment these next two 
        ### lines.
        $self->swindow->FitInside;
        $self->dialog->Fit;

        return $self;
    };
    sub _build_dialog {#{{{
        my $self = shift;

        my $v = Wx::Dialog->new(
            undef, -1, 
            $self->title, 
            $self->position, 
            $self->dialog_size,
            wxRESIZE_BORDER
            |
            wxDEFAULT_DIALOG_STYLE
        );

        return $v;
    }#}}}
    sub _build_dialog_size {#{{{
        my $self = shift;

        ### See comments in LacunaWaX::MainFrame's _build_size.

        my $s = wxDefaultSize;
        $s->SetWidth(600);
        $s->SetHeight(700);

        return $s;
    }#}}}
    sub _build_main_sizer {#{{{
        my $self = shift;

        #### Production
        #my $y = Wx::BoxSizer->new(wxVERTICAL);
        ### Debugging
        my $box = Wx::StaticBox->new($self->dialog, -1, 'Main Sizer', wxDefaultPosition, wxDefaultSize);
        my $y = Wx::StaticBoxSizer->new($box, wxVERTICAL);

        return $y;
    }#}}}
    sub _build_scroll_sizer {#{{{
        my $self = shift;

        #### Production
        my $y = Wx::BoxSizer->new(wxVERTICAL);
        ### Debugging
        #my $box = Wx::StaticBox->new(
        #    $self->dialog, -1, 
        #    'Scroll Sizer', 
        #    wxDefaultPosition, 
        #    wxDefaultSize
        #    #$self->dialog_size,
        #);
        #my $y = Wx::StaticBoxSizer->new($box, wxVERTICAL);

        return $y;
    }#}}}
    sub _build_swindow {#{{{
        my $self = shift;

        ### wxALWAYS_SHOW_SB always shows the scrollbars.  They'll be there 
        ### but grayed out if they're not needed.
        ###
        ### Along with consistency, this also provides a nice grabber in the 
        ### lower right corner of the dialog.
        ###
        ### Try this both ways and use it or don't as you like.

        my $v = Wx::ScrolledWindow->new(
            $self->dialog, -1, 
            wxDefaultPosition, 
            wxDefaultSize, 
            wxTAB_TRAVERSAL
            |wxALWAYS_SHOW_SB
        );
        $v->SetScrollRate(10,10);
        $v->FitInside(); # Force the scrollbars to reset

        return $v;
    }#}}}

    sub _set_events {#{{{
        my $self = shift;
        EVT_CLOSE(  $self->dialog,                                  sub{$self->OnClose(@_)}     );
    }#}}}
    sub OnClose {#{{{
        my($self, $dialog, $event) = @_;
        $dialog->Destroy;
        $event->Skip();
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;
