
=pod

TestBlockingStatus.pm

Very important to set waiting_for_enter to False upon closing either this dialog 
or any child dialogs (eg Dialog::Status) that might be waiting for an ENTER event.  
Otherwise we could end up in an infinite loop (see OnMyButton).

=cut


package LacunaWaX::Dialog::Test {
    use v5.14;
    use Moose;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_BUTTON EVT_CLOSE EVT_SIZE EVT_TEXT_ENTER);
    with 'LacunaWaX::Roles::GuiElement';

    has 'dialog'        => (is => 'rw', isa => 'Wx::Dialog',    lazy_build => 1);
    has 'title'         => (is => 'rw', isa => 'Str',           lazy => 1,      default => 'Sitter Manager');
    has 'position'      => (is => 'rw', isa => 'Wx::Point',     lazy => 1,      default => sub {wxDefaultPosition});
    has 'dialog_size'   => (is => 'rw', isa => 'Wx::Size',      lazy_build => 1);

    has 'dialog_status'     => (is => 'rw', isa => 'LacunaWaX::Dialog::Status', lazy_build => 1             );
    has 'waiting_for_enter' => (is => 'rw', isa => 'Int',                       lazy => 1,      default => 0);

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
    sub _build_dialog_status {#{{{
        my $self = shift;

=head2 _build_dialog_status

When the TestDialog's Click Me button gets clicked, a Dialog::Status window pops 
into existence.  When that Dialog::Status gets closed, it needs to be fully 
closed; all references to it go away.

So if the Click Me button gets clicked again, a brand new Dialog::Status window 
needs to pop into existence, complete with its events (the ENTER keyboard event, 
mainly).

So that event can't just be called in _set_events, which only gets called during 
the construction of this TestDialog, not during the construction of every 
Dialog::Status created by this TestDialog.

However:

 - somebody calls $self->dialog_status(), which calls dialog_status lazy builder 
   (this method)

 - this lazy builder calls $self->_set_dialog_events to make sure the ENTER 
   event gets set on the new Dialog::Status.

 - but _set_dialog_events refers to $self->dialog_status, which calls back into 
   this lazy builder method, and we have an infinite loop.

The solution is to change _set_dialog_events() so that it accepts a Dialog::Status 
as an argument, rather than attempting to access $self->status_dialog (which 
doesn't exist yet).  We create that Dialog::Status, pass it off to the event 
creator, and then, after the event is set up, we return the Dialog::Status object 
as expected.

=cut

        my $v = LacunaWaX::Dialog::Status->new( 
            app         => $self->app,
            ancestor    => $self,
            title       => 'Test Status Dialog More of a Long Title So It Stretches Out',
            recsep      => '-=-=-=-=-=-=-',
        );
        $self->_set_dialog_events($v);
        return $v;
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
            "Click Me",
            wxDefaultPosition, 
            Wx::Size->new(200,200),
        );

        return $v;
    }#}}}
    sub _set_events {#{{{
        my $self = shift;

        EVT_BUTTON( $self->dialog, $self->button->GetId, sub{$self->OnMyButton(@_)} );
        EVT_CLOSE(  $self->dialog,                       sub{$self->OnClose(@_)});
        $self->_set_dialog_events($self->dialog_status);
    }#}}}
    sub _set_dialog_events {#{{{
        my $self = shift;
        my $dialog_status = shift;

        ### See _build_dialog_status for an explanation as to why this needs to 
        ### accept an argument (and why it needs to exist in the first place).

        ### We can only respond to the user clicking the enter key on the status 
        ### dialog if its status TextCtrl was created with the 
        ### wxTE_PROCESS_ENTER style (which it is).
        EVT_TEXT_ENTER(
            $dialog_status->dialog,
            $dialog_status->txt_status->GetId,
            sub{$self->OnStaticTextEnter(@_)}
        );

    }#}}}

    sub OnClose {#{{{
        my $self    = shift;
        my $dialog  = shift; 
        my $event   = shift;

        $self->waiting_for_enter(0);
        $self->dialog_status->close;
        $self->dialog->Destroy;
        $event->Skip();
    }#}}}
    sub OnStaticTextEnter {#{{{
        my $self    = shift;
        my $parent  = shift;    # Wx::Dialog
        my $event   = shift;    # Wx::CommandEvent
        $self->waiting_for_enter(0);
    }#}}}
    sub OnMyButton {#{{{
        my $self    = shift;
        my $parent  = shift;    # Wx::Dialog
        my $event   = shift;    # Wx::CommandEvent

        $self->dialog_status->show();

        $self->waiting_for_enter(1);
        $self->dialog_status->say( "This will display until you hit <ENTER>.");
        $self->dialog_status->say();
        $self->dialog_status->say("Hit <Enter> to dismiss this message and continue:");
        while( $self->waiting_for_enter ) {
            ### Block until the user hits their enter button
            Wx::MilliSleep(100);
            $self->app->Yield;
        }
        $self->dialog_status->erase();

        $self->dialog_status->say( "Congratulations on finding your <ENTER> key!");
    }#}}}
    sub OnDialogStatusClose {#{{{
        my $self    = shift;
        $self->waiting_for_enter(0);
        $self->dialog_status->close;
        $self->clear_dialog_status;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}


1;
