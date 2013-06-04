
package LacunaWaX {
    use v5.14;
    use strict;
    use warnings;
    use English qw( -no_match_vars );
    use Games::Lacuna::Client::TMTRPC;
    use Getopt::Long;
    use Moose;
    use Time::HiRes;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_MOVE EVT_CLOSE);

    use LacunaWaX::MainFrame;
    use LacunaWaX::MainSplitterWindow;
    use LacunaWaX::Model::Client;
    use LacunaWaX::Model::Container;
    use LacunaWaX::Model::WxContainer;
    use LacunaWaX::Schedule;
    use LacunaWaX::Servers;

    use MooseX::NonMoose;
    extends 'Wx::App';

    our $VERSION = 1.12;

    has 'root_dir'          => (is => 'rw', isa => 'Str',                               required   => 1);
    has 'bb'                => (is => 'rw', isa => 'LacunaWaX::Model::Container',       lazy_build => 1);
    has 'wxbb'              => (is => 'rw', isa => 'LacunaWaX::Model::WxContainer',     lazy_build => 1);
    has 'db_file'           => (is => 'rw', isa => 'Str',                               lazy_build => 1);
    has 'db_log_file'       => (is => 'rw', isa => 'Str',                               lazy_build => 1);
    has 'icon_bundle'       => (is => 'rw', isa => 'Wx::IconBundle',                    lazy_build => 1);

    has 'main_frame' => (
        is      => 'rw', 
        isa     => 'LacunaWaX::MainFrame', 
        lazy_build => 1,
        handles => {
            menu_bar            => 'menu_bar',
            intro_panel         => 'intro_panel',
            has_intro_panel     => 'has_intro_panel',
            left_pane           => 'left_pane',
            right_pane          => 'right_pane',
            splitter            => 'splitter',
        }
    );
    has 'servers' => (
        is      => 'ro',
        isa     => 'LacunaWaX::Servers',
        handles => {
            server_ids              => 'ids',
            server_records          => 'records',
            server_pairs            => 'pairs',
            server_record_by_id     => 'get',
        },
        lazy_build => 1,
    );
    has 'server' => (
        is              => 'rw',
        isa             => 'Maybe[LacunaWaX::Model::Schema::Servers]',
        clearer         => 'clear_server',
        documentation   => q{
            DBIC Servers record of the server to which we're connected.
            Populated by call to ->game_connect().
        },
    );
    has 'account' => (
        is              => 'rw', 
        isa             => 'Maybe[LacunaWaX::Model::Schema::ServerAccounts]',
        clearer         => 'clear_server_prefs',
        documentation   => q{
            DBIC ServerAccounts record of the account we're connected as.
            Populated by call to ->game_connect().
        },
    );
    has 'game_client' => (
        is              => 'rw', 
        isa             => 'LacunaWaX::Model::Client', 
        clearer         => 'clear_game_client',
        predicate       => 'has_game_client',
        documentation   => q{
            Chicken-and-egg.
            This makes sense as an attribute of LacunaWaX, but it cannot connect 
            until the user has updated their username/password in the 
            Preferences window during their first run.  Populated by call to 
            ->game_connect().
        }
    );

    has 'glyphs'   => (is => 'rw', isa => 'ArrayRef[Str]', lazy_build => 1, documentation => q{hardcoded list});
    has 'warships' => (is => 'rw', isa => 'ArrayRef[Str]', lazy_build => 1, documentation => q{hardcoded list});

    sub FOREIGNBUILDARGS {#{{{
        return (); # Wx::App->new() gets no arguments.
    }#}}}
    sub BUILD {
        my $self = shift;

        $self->SetTopWindow($self->main_frame->frame);
        $self->main_frame->frame->SetIcons( $self->icon_bundle );
        $self->main_frame->frame->Show(1);
        my $logger = $self->bb->resolve( service => '/Log/logger' );
        $logger->debug('Starting application');

        $self->_set_events;
        return $self;
    }
    sub _build_bb {#{{{
        my $self = shift;
        return LacunaWaX::Model::Container->new(
            name            => 'my container',
            root_dir        => $self->root_dir,
            db_file         => $self->db_file,
            db_log_file     => $self->db_log_file,
        );
    }#}}}
    sub _build_db_file {#{{{
        my $self = shift;
        my $file = $self->root_dir . '/user/lacuna_app.sqlite';
        return $file;
    }#}}}
    sub _build_db_log_file {#{{{
        my $self = shift;
        my $file = $self->root_dir . '/user/lacuna_log.sqlite';
        return $file;
    }#}}}
    sub _build_glyphs {#{{{
        return [sort qw(
            anthracite
            bauxite
            beryl
            chalcopyrite
            chromite
            fluorite
            galena
            goethite
            gold
            gypsum
            halite
            kerogen
            magnetite
            methane
            monazite
            rutile
            sulfur
            trona
            uraninite
            zircon
        )];
    }#}}}
    sub _build_icon_bundle {#{{{
        my $self = shift;

        my $bundle = Wx::IconBundle->new();
        my @images = map{ join q{/}, ($self->bb->resolve(service => q{/Directory/ico}), qq{frai_$_.png}) }qw(16 24 32 48 64 72 128 256);
        foreach my $i(@images) {
            $bundle->AddIcon( Wx::Icon->new($i, wxBITMAP_TYPE_ANY) );
        }

        return $bundle;
    }#}}}
    sub _build_main_frame {#{{{
        my $self = shift;

        my $args = {
            app         => $self,
            title       => $self->bb->resolve(service => '/Strings/app_name'),
        };

        ### Coords to place frame if we saved them from a previous run.
        ### If not, we'll start the main_frame in the center of the display.
        my $schema = $self->bb->resolve( service => '/Database/schema' );
        if( my $db_x = $schema->resultset('AppPrefsKeystore')->find({ name => 'MainWindowX' }) ) {
            if( my $db_y = $schema->resultset('AppPrefsKeystore')->find({ name => 'MainWindowY' }) ) {
                $args->{'position'} = Wx::Point->new($db_x->value, $db_y->value);
            }
        }

        ### position arg is optional.  Window will be centered on display if 
        ### position is not sent.
        my $mf = LacunaWaX::MainFrame->new( $args );
        return $mf;
    }#}}}
    sub _build_servers {#{{{
        my $self        = shift;
        my $schema      = $self->bb->resolve( service => '/Database/schema' );
        return LacunaWaX::Servers->new( schema => $schema );
    }#}}}
    sub _build_warships {#{{{
        my $self = shift;
        my $list = [qw(
            bleeder
            detonator
            fighter
            placebo
            placebo2
            placebo3
            placebo4
            placebo5
            placebo6
            scow
            scow_large
            scow_fast
            scow_mega
            security_ministry_seeker
            snark
            snark2
            snark3
            spaceport_seeker
            sweeper
            thud
        )];
        return $list;
    }#}}}
    sub _build_wxbb {#{{{
        my $self = shift;
        return LacunaWaX::Model::WxContainer->new(
            name        => 'wx container',
            root_dir    => $self->root_dir,
        );
    }#}}}
    sub _set_events {#{{{
        my $self = shift;
        EVT_CLOSE( $self->main_frame->frame, sub{$self->OnClose(@_)} );
        return;
    }#}}}

    sub api_ship_name {#{{{
        my $self = shift;
        my $ship = shift;

=head2 api_ship_name

Given a human-friendly ship name as returned by human_ship_name, this turns it 
back into an API-friendly name (eg "Snark 3" => "snark3").

=cut

        $ship =~ s/\s(\d)/$1/g;     # <space> digit => digit
        $ship =~ s/ /_/g;           # space => underscore
        $ship = lc $ship;           # lowercase the whole mess
        return $ship;
    }#}}}
    sub build_img_list_glyphs {#{{{
        my $self = shift;

=head2 build_img_list_glyphs

Returns a Wx::ImageList of glyphs.  ImageList contains one image per glyph 
type, ordered alpha by glyph name.

Does I<not> return a singleton; a new ImageList is created each time this is 
called.

=cut

        my $img_list = Wx::ImageList->new( '39', '50', '0', '20' );
        foreach my $g( @{$self->game_client->glyphs} ) {#{{{

            my $img = $self->wxbb->resolve(service => "/Assets/images/glyphs/$g.png");
            $img->Rescale('39', '50');
            my $bmp = Wx::Bitmap->new($img);

            $img_list->Add($bmp, wxNullBitmap);
        }#}}}
        return $img_list;
    }#}}}
    sub build_img_list_warships {#{{{
        my $self = shift;

=head2 build_img_list_warships

Returns a Wx::ImageList of warships.  ImageList contains one image per warship  
as returned by $self->warships.

Does I<not> return a singleton; a new ImageList is created each time this is 
called.

04/30/2013 - I've added the code to resolve the ship images out of the 
assets.zip file, but because this code is not being used, that zip file does not 
contain any ships images.  If this becomes needed, add the ships images to that 
assets file and this method /should/ just work.

04/05/2013 - this is not being used by anything, so I'm removing the ships 
images from user/assets/ to keep them from having to be installed each time.

=cut

        my $img_list = Wx::ImageList->new( '50', '50', '0', '4' );
        foreach my $ship( @{$self->game_client->warships} ) {

            my $img = $self->wxbb->resolve(service => "/Assets/images/ships/$ship.png");
            $img->Rescale('50', '50');
            my $bmp = Wx::Bitmap->new($img);

            $img_list->Add($bmp, wxNullBitmap);
            $self->Yield;
        }

        return $img_list;
    }#}}}
    sub caption {#{{{
        my $self = shift;
        my $msg  = shift;

=head2 caption

Sets the main frame caption text and returns the previously-set text

 my $old_caption = $app->caption('New Text');

Really just a convenience method to keep you from having to call

 my $old_caption = $self->main_frame->status_bar->change_caption('New Text');

=cut

        my $old_text = $self->main_frame->status_bar->change_caption($msg);
        return $old_text;
    }#}}}
    sub game_connect {#{{{
        my $self = shift;

=pod

Attempts to connect to the server in $self->server.  "Connect" means "send a 
ping in the form of an "empire get_status call".


Returns true/false on success/fail.

=cut

        my $logger = $self->bb->resolve( service => '/Log/logger' );
        $logger->component('LacunaWaX');
        $logger->debug("Attempting to create client connection");

        my $schema = $self->bb->resolve( service => '/Database/schema' );
        unless( $self->server ) {
            $logger->debug("No server set up yet; cannot connect.");
            return;
        }
        if( 
            my $server_account = $schema->resultset('ServerAccounts')->search({
                server_id => $self->server->id,
                default_for_server => 1
            })->single
        ) {
            $logger->debug("Server is set up; attempting to connect.");
            $self->Yield;
            $self->account( $server_account );

            my $game_client = LacunaWaX::Model::Client->new (
                    app         => $self,
                    bb          => $self->bb,
                    wxbb        => $self->wxbb,
                    server_id   => $self->server->id,
                    rpc_sleep   => 0,
                    allow_sleep => 0,   # Treat '> RPC Limit' error as any other error from the GUI
            );
            $self->game_client( $game_client );

            $self->Yield;
            my $rv = $self->game_client->ping;
            return unless $rv;  # no $rv means bad creds.
            $self->Yield;
        }
        else {
            $self->poperr("Could not find server.");
            return;
        }
        $self->Yield;
        return $self->game_client->ping;    # rslt of the previous call was cached, so this is OK.
    }#}}}
    sub endthrob {#{{{
        my $self = shift;

        $self->main_frame->status_bar->bar_reset;
        $self->Yield; 
        local %SIG = ();
        $SIG{ALRM} = undef;     ##no critic qw(RequireLocalizedPunctuationVars) - PC thinks $SIG there is a scalar - whoops
        alarm 0;
        return;
    }#}}}
    sub poperr {#{{{
        my $self    = shift;
        my $message = shift || 'Unknown error occurred';
        my $title   = shift || 'Error!';
        Wx::MessageBox($message, $title, wxICON_EXCLAMATION, $self->main_frame->frame );
        return;
    }#}}}
    sub popmsg {#{{{
        my $self    = shift;
        my $message = shift || 'Everything is fine';
        my $title   = shift || 'LacunaWaX';
        Wx::MessageBox($message,
                        $title,
                        wxOK | wxICON_INFORMATION,
                        $self->main_frame->frame );
        return;
    }#}}}
    sub popconf {#{{{
        my $self    = shift;
        my $message = shift || 'Everything is fine';
        my $title   = shift || 'LacunaWaX';

=pod

The rv from this will be either wxYES or wxNO.  BOTH ARE POSITIVE INTEGERS.

So don't do this:

 ### BAD AND WRONG AND EVIL
 if( popconf("Are you really sure", "Really?") ) {
  ### Do Eeet
 }
 else {
  ### User said 'no', so don't really do eeet.
  ### GONNNNNG!  THAT IS WRONG!
 }

That code will never hit the else block, even if the user choses 'No', since the 
'No' response is true.  This could be A Bad Thing.


Instead, you need something like this...

 ### GOOD AND CORRECT AND PURE
 if( wxYES == popconf("Are you really sure", "Really really?") ) {
  ### Do Eeet
 }
 else {
  ### User said 'no', so don't really do eeet.
 }

...or often, more simply, this...

 return if wxNO == popconf("Are you really sure", "Really really?");
 ### do $stuff confident that the user did not say no.

=cut

        my $resp = Wx::MessageBox($message,
                                    $title,
                                    wxYES_NO|wxYES_DEFAULT|wxICON_QUESTION|wxSTAY_ON_TOP,
                                    $self->main_frame->frame );
        return $resp;
    }#}}}
    sub throb {#{{{
        my $self = shift;

        $self->main_frame->status_bar->gauge->Pulse;        ## no critic qw(ProhibitLongChainsOfMethodCalls)
        $self->Yield; 
        local %SIG = ();
        $SIG{ALRM} = sub {  ##no critic qw(RequireLocalizedPunctuationVars) - PC thinks $SIG there is a scalar - whoops
            $self->main_frame->status_bar->gauge->Pulse;    ## no critic qw(ProhibitLongChainsOfMethodCalls)
            $self->Yield; 
            alarm 1;
        };
        alarm 1;
        return;
    }#}}}

    sub OnClose {#{{{
        my($self, $frame, $event) = @_;

        my $schema = $self->bb->resolve( service => '/Database/schema' );
        my $logger = $self->bb->resolve( service => '/Log/logger' );
        $logger->component('LacunaWaX');

        ### Save main window position
        my $db_x = $schema->resultset('AppPrefsKeystore')->find_or_create({ name => 'MainWindowX' });
        my $db_y = $schema->resultset('AppPrefsKeystore')->find_or_create({ name => 'MainWindowY' });
        my $point = $self->GetTopWindow()->GetPosition;
        $db_x->value( $point->x ); $db_x->update;
        $db_y->value( $point->y ); $db_y->update;

        ### Save main window size
        my $db_w = $schema->resultset('AppPrefsKeystore')->find_or_create({ name => 'MainWindowW' });
        my $db_h = $schema->resultset('AppPrefsKeystore')->find_or_create({ name => 'MainWindowH' });
        my $size = $self->GetTopWindow()->GetSize;
        $db_w->value( $size->width ); $db_w->update;
        $db_h->value( $size->height ); $db_h->update;

        ### Prune old log entries
        my $now   = DateTime->now();
        my $dur   = DateTime::Duration->new(days => 7);     # TBD this duration should perhaps be configurable
        my $limit = $now->subtract_duration( $dur );
        $logger->debug('Pruning old log entries');
        $logger->prune_bydate( $limit );
        $logger->debug('Closing application');

        ### Set the current app version
        ### TBD doing this here is somewhat questionable; see UPGRADING in the 
        ### dev notes file.
        if( my $app_version = $schema->resultset('AppPrefsKeystore')->find_or_create({ name => 'AppVersion' }) ) {
            $app_version->value( $LacunaWaX::VERSION );
            $app_version->update;
        }
        if( my $db_version = $schema->resultset('AppPrefsKeystore')->find_or_create({ name => 'DbVersion' }) ) {
            $db_version->value( $LacunaWaX::Model::Schema::VERSION );
            $db_version->update;
        }

        $event->Skip();
        return;
    }#}}}
    sub OnInit {#{{{
        my $self = shift;
        ### This gets called by the Wx::App (our parent) constructor.  This 
        ### means that $self is not yet a LacunaWaX object, so Moose hasn't 
        ### gotten involved fully yet.
        ### eg $self->root_dir is going to be undef, even though it's required 
        ### and was passed in by the user.
        ###
        ### The point being that any code in here should relate only to the 
        ### Wx::App, not to the LacunaWaX.
        Wx::InitAllImageHandlers();
        return 1;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

1;

__END__

 vim: syntax=perl
