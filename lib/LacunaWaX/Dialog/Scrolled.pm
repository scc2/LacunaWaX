
package LacunaWaX::Dialog::Scrolled {
    use v5.14;
    use Moose;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw();
    with 'LacunaWaX::Roles::GuiElement';

    use MooseX::NonMoose::InsideOut;
    extends 'Wx::Dialog';

    has 'page_sizer'    => (is => 'rw', isa => 'Wx::BoxSizer',          lazy_build => 1, documentation => 'horizontal'  );
    has 'main_sizer'    => (is => 'rw', isa => 'Wx::Sizer',             lazy_build => 1, documentation => 'vertical'    );
    has 'swindow'       => (is => 'rw', isa => 'Wx::ScrolledWindow',    lazy_build => 1);
    has 'title'         => (is => 'rw', isa => 'Str',                   lazy_build => 1);
    has 'position'      => (is => 'rw', isa => 'Wx::Point',             lazy_build => 1);
    has 'size'          => (is => 'rw', isa => 'Wx::Size',              lazy_build => 1);

    sub FOREIGNBUILDARGS {## no critic qw(RequireArgUnpacking) {{{
        my $self = shift;
        my %args = @_;

        my $pos = $args{'position'} // Wx::Point->new(10,10);

        return (
            undef, -1, 
            q{},
            $pos,
            wxDefaultSize,
            wxRESIZE_BORDER|wxDEFAULT_DIALOG_STYLE
        );
    }#}}}
    sub BUILD {
        my $self = shift;
        $self->page_sizer->AddSpacer(5);
        $self->page_sizer->Add($self->main_sizer, 0, 0, 0);
        $self->swindow->SetSizer($self->page_sizer);
        return $self;
    };
    sub _build_main_sizer {#{{{
        my $self = shift;
        my $v = $self->build_sizer($self, wxVERTICAL, 'Main Sizer');
        return $v;
    }#}}}
    sub _build_page_sizer {#{{{
        my $self = shift;
        my $v = $self->build_sizer($self->swindow, wxHORIZONTAL, 'Page Sizer');
        return $v;
    }#}}}
    sub _build_position {#{{{
        my $self = shift;
        return wxDefaultPosition;
    }#}}}
    sub _build_size {#{{{
        my $self = shift;
        return wxDefaultSize;
    }#}}}
    sub _build_swindow {#{{{
        my $self = shift;

        my $v = Wx::ScrolledWindow->new(
            $self, -1, 
            wxDefaultPosition, 
            wxDefaultSize, 
            wxTAB_TRAVERSAL
            |wxALWAYS_SHOW_SB
        );
        $v->SetScrollRate(10,10);

        return $v;
    }#}}}
    sub _build_title {#{{{
        my $self = shift;
        return 'Dialog Title';
    }#}}}
    sub _set_events { }

    sub init_screen {#{{{
        my $self = shift;

=head2 init_screen

The extending class needs to call init_screen at the end of its BUILD sub.

I realize that '$self->init_screen' doesn't save us all that much over '$self->swindow->FitInside'.
But NonScrolled.pm is requiring the user to end BUILD with its init_screen(), so I'm setting it up
this way here too just for consistency.

=cut

        $self->swindow->FitInside();
        return 1;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;

__END__

=head1 NAME

LacunaWaX::Dialog::Scrolled - A scrolled dialog with margins.

=head1 DESCRIPTION

This is not meant to be used on its own; it's meant to be extended to create a 
dialog box with just a scoche of margin.

This is similar in purpose to LacunaWaX::Dialog::NonScrolled, but the addition
of the scrollbars means that usage is a bit different, so if you've extended 
NonScrolled before, pay attention.

The main difference is the addition of the swindow (Wx::ScrolledWindow) attribute,
which is what your extending class's Wx components should be added to.

LacunaWaX::Dialog::Scrolled implements the LacunaWaX::Roles::GuiElement role, 
so extending classes will require app, ancestor, and parent arguments passed to 
their constructors.

=head1 SYNOPSIS

 package ExtendingClass;
 use Moose;
 extends 'LacunaWaX::Dialog::Scrolled';

 # Any Wx components your extending class creates should use $self->swindow
 # as parent, eg:
 sub _build_button {
  my $self = shift;
  my $b = Wx::Button->new(
   $self->swindow,     # NOT just $self, as when extending NonScrolled.pm!
   -1, "Button Text",
   wxDefaultPosition, wxDefaultSize
  );
  return $b;
 }

 sub BUILD {
  my $self = shift;

  # title and size attributes are provided by NonScrolled.pm, but you're not
  # likely to enjoy the default values, so your extending class should set
  # its own values.  These attributes are lazy, so your extending class can
  # provide _build_*() methods for them:
  $self->SetTitle( $self->title );
  $self->SetSize( $self->size );

  # main_sizer is a vertical Wx::Sizer provided by NonScrolled.  Your
  # extending class's Wx components should be added to that sizer:
  $self->main_sizer->Add( $self->button, 0, 0, 0 );

  # If your screen contents are taller than the dialog itself, the screen
  # will start out scrolled to whichever Wx component has focus.  This will
  # probably be the last component you added, at the bottom of the screen.
  # Since you almost certainly don't want to start out scrolled all the way 
  # down, force focus onto an element at the top of the screen, like your
  # header label:
  $self->lbl_header->SetFocus();

  # Finish up and display the screen
  $self->init_screen();

  return $self;
 }
 sub _build_title { return 'My Title' }
 sub _build_size  { return Wx::Size->new($some_width, $some_height) }

 # That main_sizer is itself added to a page_sizer, which maintains the
 # dialog-wide left margin.  This happens automatically, so your extending
 # class does not need to touch page_sizer.

=head1 ARGUMENTS

=head2 app, ancestor, parent (required)

The standard arguments required by LacunaWaX::Roles::GuiElement

=head2 position (optional)

A Wx::Point object defining the NW corner of the dialog.  Defaults to (10,10).

=cut

