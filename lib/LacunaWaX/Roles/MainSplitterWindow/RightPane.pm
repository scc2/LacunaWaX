

=head1 DESCRIPTION

Role defining a panel to be displayed on the right side of the app's main split 
window.

This role itself extends the GuiElement role.

=head1 ATTRIBUTES

=head2 refocus_window_name

When the screen regains focus, this is the name of the window (control) that 
should gain focus.

When this is set, you can mouse-over the left TreeCtrl and your scrollwheel will 
affect that, then mouse-over your right pane contents and your scrollwheel will 
affect that.

The drawback to this is that, when your right pane regains focus, the screen is 
going to jump to the control named in refocus_window_name.

In some cases (SpiesPane.pm), that jump is simply unacceptable; in that case, do 
not set a refocus_window_name, but accept that the scroll wheel will not switch 
focus on mouseover.  

If you chose not to set refocus_window_name, you'll need to handle any scrolling 
behavior yourself.

To set this, simply assign during BUILD:

 sub BUILD {
  ...
  $self->refocus_window_name('lbl_planet_name'); # or whatever
 }

see GlyphsPane.pm for an example of a screen that does require special focus 
handling.

=head2 scroll_x, scroll_y

These get set to the position to which the screen was scrolled when it lost 
focus.  Not something you'll normally need to touch.

=head2 sizer_debug

Set to a true value to enable boxes around the spacers as well as STDOUT 
messages produced by the events.  

Set to false or omit entirely to disable debugging.

=head2 sizers

Hashref containing the sizers and their associated boxes (if any) keyed off the 
sizers' names:

 {
  sizer_one_name => {
   sizer => 'The sizer object',
   box   => 'The StaticBox object used when sizer_debug is true'
  },
  sizer_two_name => {
   sizer => 'The sizer object',
   box   => 'The StaticBox object used when sizer_debug is true'
  },
  ...
 }

Most of the time you can ignore this.

=head2 top_margin_width, left_margin_width

The integer width, in pixels, of the top and left margins.  Both defaults to 10 
and can be omitted entirely from your class if you don't need to change the 
defaults.

=head2 main_sizer, main_horiz_sizer, content_sizer

All are Wx::BoxSizer objects, and all are provided by the role.

main_sizer is vertical.  It contains a small top margin, and then the 
main_horiz_sizer.

main_horiz_sizer is, oddly enough, horizontal.  It contains a small left 
margin, and then the content_sizer.

content_sizer contains the actual screen contents.

 __ main_sizer ____________________
|             MARGIN               |
|  __ main_horiz_sizer ___________ |
| |    __ content_sizer _________ ||
| |   |                          |||
| | M |                          |||
| | A |                          |||
| | R |                          |||
| | G |                          |||
| | I |                          |||
| | N |                          |||
| |   |__________________________|||
| |_______________________________||
|__________________________________|

=head1 EVENTS

Events will be generated for mouse entering and leaving the pane, and also for 
losing focus.

=head1 USING

Your panel/dialog/window/whatever will add its controls to content_sizer, and 
essentially ignore the existence of main_sizer and main_horiz_sizer.

SetSizer gets called on behalf of your $self->parent on the main_sizer for 
you.

 with 'LacunaWaX::Roles::MainSplitterWindow::RightPane';

 sub BUILD {
  $self->content_sizer->Add($self->SOME_CONTROL_1, 0, 0, 0);
  $self->content_sizer->Add($self->..., 0, 0, 0);
  $self->content_sizer->Add($self->SOME_CONTROL_N, 0, 0, 0);
 }

=head1 CLOSING YOUR PANE

Most RightPane::* objects won't need to do anything special when they close.  
However, if any sub-dialogs, such as Dialog::Status's, get opened, those will need 
to be taken down when the RightPane:: object is closed as a result of the app 
being closed.

So if your RightPane:: object implements an OnClose method, it will be called 
when the pane (the app) closes.

This might seem a bit mysterious, as the RightPane:: objects do not actually 
receive an EVT_CLOSE event when the app is closed.  What's actually happening is 
that MainFrame, which I<does> receive an OnClose event, is calling 
MainSplitterWindow's OnClose(), which is calling both LeftPane's and RightPane's 
OnClose(), etc, setting up a chain down to your RightPane:: object.

The point is that you don't have to do anything to cause your OnClose method to 
be called; if you need one, just create one and it will be called.

I<Nothing in this RightPane role is actually affecting the closure of its 
implementors, this just seemed like the most logical place for this 
documentation.>

Exactly what action is needed is going to be specific to each individual 
RightPane:: module, but it'll be something along the lines of:

 ### Not a true event, so the usual $dialog and $event are not passed in.
 sub OnClose {
  my $self = shift;
  $self->dialog_status->close if $self->dialog_status;
 }

=head1 TBD

On Alt-Tabbing away and then back again, the screen autoscrolls to the top (or 
at least, presumably, to the location of the $refocus_window_name).  It would be 
nice if we could detect that sort of regain of focus and add an event to 
rescroll to the last known pos like in OnMouseEnterScreen.

=cut

package LacunaWaX::Roles::MainSplitterWindow::RightPane {
    use v5.14;
    use Moose::Role;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_ENTER_WINDOW EVT_LEAVE_WINDOW EVT_KILL_FOCUS EVT_CLOSE);
    with 'LacunaWaX::Roles::GuiElement';

    has 'main_sizer'        => (is => 'rw', isa => 'Wx::BoxSizer',  lazy_build => 1, documentation => 'vertical'   );
    has 'main_horiz_sizer'  => (is => 'rw', isa => 'Wx::BoxSizer',  lazy_build => 1, documentation => 'horizontal' );
    has 'content_sizer'     => (is => 'rw', isa => 'Wx::BoxSizer',  lazy_build => 1, documentation => 'vertical'   );

    has 'left_margin_width' => (is => 'rw', isa => 'Int',  lazy => 1, default => 10   );
    has 'top_margin_width'  => (is => 'rw', isa => 'Int',  lazy => 1, default => 10   );

    has 'scroll_x'              => (is => 'rw', isa => 'Int', lazy => 1, default => 0                   );
    has 'scroll_y'              => (is => 'rw', isa => 'Int', lazy => 1, default => 0                   );
    has 'refocus_window_name'   => (is => 'rw', isa => 'Str', lazy_build => 1  );


    after BUILD => sub {
        my $self = shift;
        $self->main_sizer->AddSpacer( $self->top_margin_width );
        $self->main_sizer->Add($self->main_horiz_sizer, 0, 0, 0);

        $self->main_horiz_sizer->AddSpacer( $self->left_margin_width );
        $self->main_horiz_sizer->Add($self->content_sizer, 0, 0, 0);

        $self->parent->SetSizer($self->main_sizer);
        return $self;
    };
    after _set_events => sub {#{{{
        my $self = shift;
        EVT_ENTER_WINDOW(   $self->parent,  sub{$self->OnMouseEnterScreen(@_)}      );
        EVT_LEAVE_WINDOW(   $self->parent,  sub{$self->OnMouseLeaveScreen(@_)}      );
        EVT_KILL_FOCUS(     $self->parent,  sub{$self->OnAppLoseFocus(@_)}          );
        return 1;
    };#}}}

    sub _build_content_sizer {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxVERTICAL, 'Content Sizer');
    }#}}}
    sub _build_main_sizer {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxVERTICAL, 'Main Vert Sizer');
    }#}}}
    sub _build_main_horiz_sizer {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxHORIZONTAL, 'Main Horiz Sizer');
    }#}}}
    sub _build_refocus_window_name {#{{{
        my $self = shift;
        return 'lbl_planet_name';
    }#}}}

    sub OnAppLoseFocus {#{{{
        my $self    = shift;
        my $parent  = shift;
        my $event   = shift;

        ### This actually gets called when anything loses focus, not just the 
        ### entire app.  It does trigger on an alt-tab away from LacunaWax.
        $self->ancestor->ancestor->defocus();

        my($x,$y) = $parent->GetViewStart;
        $self->scroll_x($x);
        $self->scroll_y($y);

        $event->Skip;
        return 1;
    }#}}}
    sub OnMouseEnterScreen {#{{{
        my $self    = shift;
        my $parent  = shift;    # Wx::ScrolledWindow
        my $event   = shift;    # Wx::MouseEvent
        
        return unless $self->can('has_refocus_window_name');
        return unless $self->has_refocus_window_name;
        my $ctrl_name = $self->refocus_window_name;

        if( $self->ancestor->has_focus ) {
            $self->$ctrl_name->SetFocus;
        }
        else {
            $self->parent->Show(0);
            my $control = $self->refocus_window_name;
            $self->$control->SetFocus;
            $self->ancestor->ancestor->focus_right();
            $parent->Scroll( $self->scroll_x, $self->scroll_y );
            $self->parent->Show(1);
        }
        return 1;
    }#}}}
    sub OnMouseLeaveScreen {#{{{
        my $self    = shift;
        my $parent  = shift;    # Wx::ScrolledWindow
        my $event   = shift;    # Wx::MouseEvent

        my($x,$y) = $parent->GetViewStart;
        $self->scroll_x($x);
        $self->scroll_y($y);
        return 1;
    }#}}}

    no Moose::Role;
}

1;
