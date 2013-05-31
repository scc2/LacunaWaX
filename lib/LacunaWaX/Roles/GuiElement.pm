

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

=head1 HANDLERS

Any class that inherits from GuiElement gets the following methods:

=over 4

=item * app_name - string

=item * bb - The non-Wx Bread::Board container - safe for use from non-GUIs

=item * connected_account - LacunaWaX::Model::Schema::ServerAccounts record with which we're connected (may be undef)

=item * throb, endthrob - Starts and stops the throbber

=item * game_connect - Connects using the current creds.  Returns true/false on success/fail.

=item * game_client - Gets the LacunaWaX::Model::Client that's currently connected.

=item * get_chi - Returns the CHI (cache) object.  UN-safe for use from non-GUIs.

=item * get_connected_server

LacunaWaX::Model::Schema::Servers record of the connected server.  Undef unless 
game_connect has previously been called.

=item * get_font

Retrieves the requested font from the Wx Bread::Board container.  All 
fonts are in '/Fonts/...', so you only need to pass in (eg) 'para_text_1' to get 
at '/Fonts/para_text_1'.

=item * get_image

Retrieves the requested image asset from the Wx Bread::Board container.  All 
images are in '/Assets/images/...', so you only need to pass in (eg) 
'/app/arrow-left.png' to get at '/Assets/images/app/arrow-left.png'.

=item * get_splitter, get_left_pane, get_right_pane

Returns, respectively, the main splitter, or its left or right panes

=item * get_top_left_corner - Returns the Wx::Point object of the top left corner of the TopWindow

=item * get_main_schema - Returns the main (not 'logs') DBIC schema

=item * get_log_schema - Returns the logging (not 'main') DBIC schema

=item * get_logger - returns a Log::Dispatch object

=item * has_main_frame, get_main_frame

Respectively returns true if the app has gotten to the point of displaying the 
main frame, and returns that main frame if so.

=item * intro_panel_exists, get_intro_panel

Respectively checks to see if the main frame is currently displaying the 
introduction panel, and returns it if it is.

=item * popmsg, poperr, popconf

Pops up Message, Error, or Confirmation windows.  Popconf will return either 
wxYES or wxNO to indicate which button the user pressed.

=item * server_ids - Returns a list of valid server IDs from the Servers table

=item * server_record_by_id($id) - Returns the LacunaWaX::Model::Schema::Servers record indicated by $id

=item * set_caption($text) - Sets $text as the app caption on the status bar

=item * set_connected_server($srvr)

Where $srvr is a LacunaWaX::Model::Schema::Servers object; sets $srvr as the one 
to which we're currently connected.

=item * wxbb - The Wx Bread::Board container - UNsafe for use from non-GUIs

=item * [yY]ield - Calls wxApp::Yield.  Either casing is allowed.

=back

=cut

package LacunaWaX::Roles::GuiElement {
    use v5.14;
    use Moose::Role;
    use Try::Tiny;
    use Wx qw(:everything);

    has 'app' => (
        is          => 'rw',
        isa         => 'LacunaWaX',
        required    => 1,
        weak_ref    => 1,
        handles => {
            app_name                => sub{ return shift->bb->resolve(service => '/Strings/app_name') },
            bb                      => 'bb',
            connected_account       => 'account',
            endthrob                => 'endthrob',
            game_connect            => 'game_connect',
            game_client             => 'game_client',
            get_chi                 => sub{ return shift->wxbb->resolve( service => '/Cache/raw_memory' ) },
            get_connected_server    => 'server',
            get_font                => sub{ return shift->wxbb->resolve(service => '/Fonts' . shift) },
            get_image               => sub{ return shift->wxbb->resolve(service => '/Assets/images' . shift) },
            get_left_pane           => 'left_pane',
            get_log_schema          => sub{ return shift->bb->resolve(service => '/DatabaseLog/schema') },
            get_logger              => sub{ shift->bb->resolve( service => '/Log/logger' ) },
            get_right_pane          => 'right_pane',
            get_main_schema         => sub{ return shift->bb->resolve(service => '/Database/schema') },
            get_main_frame          => 'main_frame',
            get_splitter            => 'splitter',
            has_main_frame          => 'has_main_frame',
            intro_panel_exists      => 'has_intro_panel',
            get_intro_panel         => 'intro_panel',
            get_top_left_corner     => sub{ return shift->app->GetTopWindow()->GetPosition },
            menu                    => 'menu_bar',
            poperr                  => 'poperr',
            popmsg                  => 'popmsg',
            popconf                 => 'popconf',
            server_ids              => 'server_ids',
            server_record_by_id     => 'server_record_by_id',
            set_caption             => 'caption',
            set_connected_server    => 'server',
            throb                   => 'throb',
            wxbb                    => 'wxbb',
            yield                   => 'Yield',
            Yield                   => 'Yield',
        }
    );

    has 'ancestor'  => (is => 'rw', isa => 'Object',            weak_ref => 1       );
    has 'parent'    => (is => 'rw', isa => 'Maybe[Wx::Window]'                      );

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
