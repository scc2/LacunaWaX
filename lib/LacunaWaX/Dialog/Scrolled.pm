
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
    has 'position'      => (is => 'rw', isa => 'Wx::Point'                             );
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

        return $v;
    }#}}}
    sub _build_title {#{{{
        my $self = shift;
        return 'Dialog Title';
    }#}}}
    sub _set_events {#{{{
        my $self = shift;
    }#}}}

    sub init_screen {#{{{
        my $self = shift;

=head2 init_screen

The extending class needs to call init_screen at the end of its BUILD sub.

=cut

        my $s = $self->GetSize;
        my $h = $s->GetHeight;
        my $w = $s->GetWidth + 1;
        $self->SetSize( Wx::Size->new($w, $h) );

        $self->swindow->FitInside();
        $self->swindow->SetScrollRate(10,10);

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

title and size attributes are provided by NonScrolled.pm, but you're not
likely to enjoy the default values, so your extending class should set
its own values.  These attributes are lazy, so your extending class can
provide _build_*() methods for them:

  $self->SetTitle( $self->title );
  $self->SetSize( $self->size );

Be sure to see the explanation of RESIZE DURING INIT, below.  The window's 
actual width is going to be one pixel larger than you set it.  This will 
likely never make a difference, but it's possible it could, so plan for it.

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

=head1 RESIZE DURING INIT; EXPLANATION

init_screen() is resizing the produced window's width by 1 pixel, so the 
actual width of the produced window will be one pixel larger than the width 
you request in your _build_size method.

Without doing this resize, we see the following behavior:

=over4

=item * The first time you open a window derived from Scrolled, everything 
looks fine.

=item * Close that window, and re-open it.

=item * The second time the window is opened, the scrollbars are partially 
buried in the border.  This doesn't break anything, but it's ugly.

=item * A manual resize of the window, by any amount, fixes the scrollbars.  
Simply clicking the border without an actual change in size does not.

=item * The easiest fix for this is to programmatically force a slight resize 
of the window by adding 1 pixel to its predefined size.

=item * This pixel addition is not cumulative; it's only a single pixel 
addition (not one extra pixel each time the window is resized or whatever, 
just one more than the preset size at the beginning when the window is 
created)

=back

I've tried every combination of ->Layout and ->Update that seems to make 
sense, resulting in varying combinations of brokenness.  The forced change in 
size is the only thing I've found that results in a proper-looking window.

=cut

