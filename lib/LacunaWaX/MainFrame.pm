
package LacunaWaX::MainFrame {
    use v5.14;
    use Data::Dumper;
    use Moose;
    use POSIX qw(:sys_wait_h);
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_CLOSE EVT_SET_FOCUS EVT_KILL_FOCUS EVT_SIZE);

    use LacunaWaX::Dialog::Status;
    use LacunaWaX::MainFrame::IntroPanel;
    use LacunaWaX::MainFrame::MenuBar;
    use LacunaWaX::MainFrame::StatusBar;
    use LacunaWaX::MainFrame::StatusBar::Timer;
    use LacunaWaX::MainSplitterWindow;

    has 'app'       => (is => 'rw', isa => 'LacunaWaX', required => 1,  weak_ref => 1);

    has 'position'  => (is => 'rw', isa => 'Maybe[Wx::Point]',
        documentation => q{
            Optional - if sent, it will be the point of the upper-left corner of the app.
            If no position is passed in, the app will be displayed centered on the screen.
        }
    );

    has 'style'     => (is => 'rw', isa => 'Int',       lazy_build => 1);
    has 'frame'     => (is => 'rw', isa => 'Wx::Frame', lazy_build => 1);
    has 'title'     => (is => 'rw', isa => 'Str',       lazy_build => 1);
    has 'size'      => (is => 'rw', isa => 'Wx::Size',  lazy_build => 1);
    has 'icon'      => (is => 'rw', isa => 'Wx::Icon',  lazy_build => 1);

    has 'status_bar'    => (is => 'rw', isa => 'LacunaWaX::MainFrame::StatusBar',   lazy_build => 1 );
    has 'menu_bar'      => (is => 'rw', isa => 'LacunaWaX::MainFrame::MenuBar',     lazy_build => 1 );

    has 'intro_panel' => (
        is          => 'rw', 
        isa         => 'LacunaWaX::MainFrame::IntroPanel',
        lazy_build  => 1,
        clearer     => 'clear_intro_panel',
        predicate   => 'has_intro_panel',
    );

    has 'splitter' => (
        is          => 'rw',
        isa         => 'LacunaWaX::MainSplitterWindow',
        lazy_build  => 1, 
        clearer     => 'clear_splitter',
        predicate   => 'has_splitter'
    );

    has 'intro_panel_sizer' => (is => 'rw', isa => 'Wx::Sizer', lazy_build => 1 );
    has 'splitter_sizer'    => (is => 'rw', isa => 'Wx::Sizer', lazy_build => 1 );


    sub BUILD {
        my($self, @params) = @_;

        $self->frame->Show(0);
        $self->frame->SetMenuBar($self->menu_bar);
        $self->intro_panel_sizer->Add( $self->intro_panel->main_panel, 1, wxEXPAND );
        $self->frame->SetSizer($self->intro_panel_sizer);

        ### The intro panel could really live without the status bar.  If you 
        ### wanted to skip it there for a cleaner look, this line could be 
        ### removed.  The status bar would then be created on subsequent panels 
        ### by its lazy builder.
        $self->_build_status_bar;

        $self->_set_events;
        $self->frame->Show(1);
        return $self;
    };
    sub _build_frame {#{{{
        my $self = shift;
        my $y = Wx::Frame->new(
            undef, -1, 
            $self->title, 
            $self->position || wxDefaultPosition, 
            $self->size,
            $self->style
        );
        unless( $self->position ) {
            $y->Centre();
        }
        return $y;
    }#}}}
    sub _build_icon {#{{{
        my $self = shift;

        my $icon = Wx::Icon->new(
            join q{/}, $self->app->bb->resolve(service => '/Directory/assets'), 'Futurama', '128', 'frai_128.png',
            wxBITMAP_TYPE_ANY,
        );

        return $icon;
    }#}}}
    sub _build_intro_panel_sizer {#{{{
        my $self = shift;
        my $ips = Wx::BoxSizer->new(wxHORIZONTAL);
        return $ips;
    }#}}}
    sub _build_intro_panel {#{{{
        my $self = shift;
        return LacunaWaX::MainFrame::IntroPanel->new(
            app         => $self->app,
            ancestor    => $self,
            parent      => $self->frame,
        );
    }#}}}
    sub _build_menu_bar {#{{{
        my $self = shift;
        my $mb = LacunaWaX::MainFrame::MenuBar->new(
            app         => $self->app,
            ancestor    => $self,
            parent      => $self->frame
        );
        return $mb;
    }#}}}
    sub ORIG_build_menu_bar {#{{{
        my $self = shift;
        my $mb = LacunaWaX::MainFrame::MenuBar->new(
            app         => $self->app,
            ancestor    => $self,
            parent      => $self->frame
        );
        return $mb;
    }#}}}
    sub _build_size {#{{{
        my $self = shift;

        ### This is fucked up.  If I start with a Wx::Size object using the 
        ### constructor, the resulting window ends up being way too small, as 
        ### if it received no size specification.
        #my $s = Wx::Size->new(800,700);     # Broke

        ### But if I start with a wxDefaultSize object, I can then call 
        ### SetWidth and SetHeight on it and end up with the specified dimensions.
        my $s = wxDefaultSize;             # works

        ### Maintain the h/w most recently set by the user
        my($w,$h) = (900,800);  # defaults
        my $schema = $self->app->bb->resolve( service => '/Database/schema' );
        if( my $db_w = $schema->resultset('AppPrefsKeystore')->find({ name => 'MainWindowW' }) ) {
            $w = $db_w->value;
        }
        if( my $db_h = $schema->resultset('AppPrefsKeystore')->find({ name => 'MainWindowH' }) ) {
            $h = $db_h->value;
        }

        ### Obviously must be called if we started with the wxDefaultSize 
        ### constant.
        ### If we start with the constructor, this shouldn't be necessary.
        ### But in that case, this actually has no effect at all whether it's 
        ### called or not.
        $s->SetWidth($w);
        $s->SetHeight($h);

        ### Regardless of which method of generating $s you used, the 
        ### following all produce the same output.
        ### But only starting with wxDefaultSize has any effect on the actual 
        ### starting size of the app.
        #say ref $s;
        #say $s->width;
        #say $s->height;
        #say $s->IsFullySpecified;

        return $s;
    }#}}}
    sub _build_splitter {#{{{
        my $self = shift;
        my $y = LacunaWaX::MainSplitterWindow->new(
            app         => $self->app, 
            parent      => $self->frame,
            ancestor    => $self,
        );
        return $y;
    }#}}}
    sub _build_splitter_sizer {#{{{
        my $self = shift;
        my $y= Wx::BoxSizer->new(wxHORIZONTAL);
        return $y;
    }#}}}
    sub _build_status_bar {#{{{
        my $self = shift;
        my $sb = LacunaWaX::MainFrame::StatusBar->new(
            app         => $self->app, 
            ancestor    => $self,
            parent      => $self->frame
        );
        return $sb;
    }#}}}
    sub _build_style {#{{{
        my $self = shift;
        return wxCAPTION|wxCLOSE_BOX|wxMINIMIZE_BOX|wxMAXIMIZE_BOX|wxSYSTEM_MENU|wxRESIZE_BORDER|wxCLIP_CHILDREN;
    }#}}}
    sub _build_title {#{{{
        my $self = shift;
        return $self->app->bb->resolve(service => '/Strings/app_name')
    }#}}}
    sub _set_events {#{{{
        my $self = shift;
        EVT_CLOSE($self->frame, sub{$self->OnClose(@_)});
        return;
    }#}}}

    before 'clear_intro_panel' => sub {#{{{
        my $self = shift;
        $self->intro_panel->main_panel->Destroy();
    };#}}}
    before 'clear_splitter' => sub {#{{{
        my $self = shift;
        $self->splitter->splitter_window->Destroy();
        return;
    };#}}}

    sub OnClose {#{{{
        my $self    = shift;
        my $frame   = shift;
        my $event   = shift;

        if( $self->has_splitter ) {
            $self->splitter->OnClose;
        }
        $event->Skip();
        return;
    }#}}}
    sub OnGameServerConnect {#{{{
        my $self        = shift;
        my $server_id   = shift;

### CHECK
### I'm beginning to feel like this event should be in LacunaWaX.pm, not here.  
### But I'm not 100% convinced yet.

        if( $self->has_intro_panel ) {
            ### Keep the user from double clicking the connect button and thus 
            ### producing a "You're already connected" poperr.
            foreach my $srvr_id( keys %{$self->intro_panel->buttons} ) {
                $self->intro_panel->buttons->{$srvr_id}->Disable();
            }
        }

        if($self->has_splitter) {
            ### We're already connected so a splitter is displayed.  Clear 
            ### it.
            $self->clear_splitter;
        }

        my $schema = $self->app->bb->resolve( service => '/Database/schema' );
        if( my $server = $schema->resultset('Servers')->find({id => $server_id}) ) {
            $self->app->server( $server );

            $self->app->caption("Connecting...");
            $self->app->throb();

            unless($self->app->game_connect) {
                ### Probably bad creds filled out in Prefs frame.  Undef 
                ### app->server so we don't get told we're "Already Connected" 
                ### on our next attempt.
                $self->app->server(undef);
                $self->app->endthrob();
                #$self->status_bar->caption("Connection Failed!  Correct your login credentials in Edit... Preferences.");
                $self->app->caption("Connection Failed!  Correct your login credentials in Edit... Preferences.");
                return;
            }
            if( $self->has_intro_panel ) {
                $self->clear_intro_panel;
            }

            ### Enable any menu items that were disabled on creation because we 
            ### weren't connected yet.
            $self->menu_bar->show_connected();

            $self->splitter_sizer->Add( $self->splitter->splitter_window, 1, wxEXPAND );
            $self->frame->Layout();

            $self->app->endthrob();
            #$self->status_bar->caption("Connected to " . $server->name . " as " . $self->app->account->username);
            $self->app->caption("Connected to " . $server->name . " as " . $self->app->account->username);
        }
        else {
            Wx::MessageBox("Invalid Server!", "Whoops", wxICON_EXCLAMATION, $self->frame);
        }

        return;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;
