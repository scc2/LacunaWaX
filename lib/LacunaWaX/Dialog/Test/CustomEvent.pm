
=pod


This is an attempt to create my own custom event.  It does not work, but shows 
promise.  

While looking at this, also open up ./TestEvent.pm.




When the TestDialog window is brought up, the EVT_MYEVENT call (in _set_events() 
in here) is obviously being called.  It's being passed the button and the 
OnMyEvent function, which you can see from the CLI output.

However, I can't figure out how to make my event actually respond as an event.




Creating custom events (C++ docs)
http://wiki.wxwidgets.org/Custom_Events#Creating_a_Custom_Event_-_Method_1

Contains note re: Wx::PlEvent and Wx::PlCommandEvent (but not much info)
http://kevino.theolliviers.com/wxdocstuff/html/classwx_event.html


=cut


package LacunaWaX::Dialog::Test {
    use v5.14;
    use Moose;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_BUTTON EVT_CLOSE EVT_SIZE);
    use LacunaWaX::TestEvent qw(EVT_MYEVENT);
    with 'LacunaWaX::Roles::GuiElement';

    has 'dialog'        => (is => 'rw', isa => 'Wx::Dialog',    lazy_build => 1);
    has 'title'         => (is => 'rw', isa => 'Str',           lazy => 1,      default => 'Sitter Manager');
    has 'position'      => (is => 'rw', isa => 'Wx::Point',     lazy => 1,      default => sub {wxDefaultPosition});
    has 'dialog_size'   => (is => 'rw', isa => 'Wx::Size',      lazy_build => 1);

    has 'main_sizer'     => (is => 'rw', isa => 'Wx::Sizer',    lazy_build => 1, documentation => q{vertical});
    has 'button'         => (is => 'rw', isa => 'Wx::Button',   lazy_build => 1);


    sub BUILD {
        my($self, @params) = @_;

        $self->dialog->SetTitle("Testing.  Ignore me.");
        $self->main_sizer->Add($self->button, 0, 0, 0);
        $self->dialog->SetSizer($self->main_sizer);
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
        $s->SetWidth(300);
        $s->SetHeight(300);

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
    sub _build_button {#{{{
        my $self = shift;

        my $v = Wx::Button->new($self->dialog, -1, 
            "Yes",
            wxDefaultPosition, 
            Wx::Size->new(200,200),
        );

        return $v;
    }#}}}

    sub _set_events {
        my $self = shift;
        EVT_MYEVENT(  $self->button,   sub{$self->OnMyEvent(@_)}     );
    }
    sub OnClose {#{{{
        my($self, $dialog, $event) = @_;
        $dialog->Destroy;
        $event->Skip();
    }#}}}
    sub OnMyEvent {#{{{
        my $self    = shift;    # LacunaWaX::Dialog::Test
        my $button  = shift;    # Wx::Button
        my $event   = shift;    # Wx::PlCommandEvent

say '-self ' . (ref $self);
say '-button ' . (ref $button);
say '-event ' . (ref $event);
say "here";

    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}


1;
