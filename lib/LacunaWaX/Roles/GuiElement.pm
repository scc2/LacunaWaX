

=head1 DESCRIPTION

A GUI element is meant to be a child of a larger GUI; this can be a dialog, 
window, or a chunk of GUI, such as the individual rows shown on the SpiesPane or 
GlyphsPane.

=head1 PROVIDED ATTRIBUTES

=head2 app

The main LacunaWaX object.

=head2 ancestor

The LacunaWaX::$whatever object from which we are called.

=head2 parent

The Wx::Window control on which this object will place its controls.  For 
parent-less GUI elements such as dialogs, this can be undef.

=head1 REQUIRED METHODS

=head2 _set_events

Sets the wxwidgets events for this GUI element.  It is possible to have a GUI 
element that does not need to respond to events; in that case, simply provide a 
noop _set_events method:

 sub _set_events { }

The _set_events method is called automatically after BUILD, so you only need to 
provide the method, but do not need to call it yourself.

=head1 PROVIDED METHODS

=head2 build_sizer

Builds and returns a sizer.  The simplest and most common usage returns an 
invisible sizer when $self->sizer_debug is off, and a visible box with the 
sizer's name when $self->sizer_debug is on.

 $sizer = $self->build_sizer($self->parent, wxHORIZONTAL, 'My Sizer Name');

B<Note> that the sizer name is meant to be unique withing your class.  Normally, 
duplicating sizer names won't actually cause you any heartache, but if you try 
to dig your sizer or its box out of $self->sizers and you've used duplicate 
names you're in for heartache and despair.  So don't do that.

You can force the box to always display regardless of the sizer_debug setting, 
and also modify the sizer's position and size if needed:

 $sizer = $self->build_sizer(
  $self->parent,
  wxHORIZONTAL,
  'My Sizer Name',
  1,                # Force the box to be drawn
  Wx::Position->new(...),
  Wx::Size->new(...),
 );

All sizers created by build_sizer will be added to the $self->sizers hashref.

=cut

package LacunaWaX::Roles::GuiElement {
    use v5.14;
    use Moose::Role;
    use Try::Tiny;
    use Wx qw(:everything);

    has 'app'           => (is => 'rw', isa => 'LacunaWaX', required => 1, weak_ref => 1);
    has 'ancestor'      => (is => 'rw', isa => 'Object',    required => 1, weak_ref => 1);
    has 'parent'        => (is => 'rw', isa => 'Maybe[Wx::Window]'                      );

    has 'sizer_debug' => (is => 'rw', isa => 'Int',  lazy => 1, default => 0,
        documentation => q{
            draws boxes with titles around all sizers if true.
        }
    );

    has 'sizers' => (is => 'rw', isa => 'HashRef', lazy => 1, default => sub{ {} });

    requires '_set_events';

    after BUILD => sub {
        my $self = shift;
        $self->_set_events;
        return 1;
    };

    sub build_sizer {#{{{
        my $self        = shift;
        my $parent      = shift;
        my $direction   = shift;
        my $name        = shift or die "iSizer name is required.";
        my $force_box   = shift || 0;
        my $pos         = shift || wxDefaultPosition;
        my $size        = shift || wxDefaultSize;

        my $hr = { };
        if( $self->sizer_debug or $force_box ) {
            $hr->{'box'} = Wx::StaticBox->new($parent, -1, $name, $pos, $size),
            $hr->{'box'}->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_1') );
            $hr->{'sizer'} = Wx::StaticBoxSizer->new($hr->{'box'}, $direction);
        }
        else {
            $hr->{'sizer'} = Wx::BoxSizer->new($direction);
        }
        $self->sizers->{$name} = $hr;

        return $hr->{'sizer'};
    }#}}}

    no Moose::Role;
}

1;
