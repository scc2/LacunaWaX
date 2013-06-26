
package LacunaWaX::Dialog::SitterManager::SitterRow {
    use v5.14;
    use Carp;
    use DateTime;
    use DateTime::Duration;
    use Moose;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_BUTTON EVT_TEXT);
    with 'LacunaWaX::Roles::GuiElement';

    has 'sizer_debug' => (is => 'rw', isa => 'Int',  lazy => 1, default => 0);

    has 'main_sizer' => (is => 'rw', isa => 'Wx::BoxSizer', lazy_build => 1, documentation => 'vertical');

    has 'row_panel'         => (is => 'rw', isa => 'Wx::Panel',     lazy_build => 1                             );
    has 'row_panel_sizer'   => (is => 'rw', isa => 'Wx::BoxSizer',  lazy_build => 1, documentation => 'vertical');

    has 'player_rec' => (is => 'rw', isa => 'Maybe[LacunaWaX::Model::Schema::SitterPasswords]', 
        documentation => q{
            This must be passed in from the outside if you want to display 
            anything but a blank row or a header.
        }
    );

    has 'is_header'     => (is => 'rw', isa => 'Int', lazy => 1, default => 0,
        documentation => q{
            If true, the produced 'SitterRow' will be a simple header with no input
            controls and no events.  The advantage is that the header's size will 
            match the size of the rest of the rows you're about to produce.
        }
    );

    has 'input_width'   => (is => 'rw', isa => 'Int', lazy => 1, default => 150);
    has 'input_height'  => (is => 'rw', isa => 'Int', lazy => 1, default => 25);
    has 'button_width'  => (is => 'rw', isa => 'Int', lazy => 1, default => 80);
    has 'button_height' => (is => 'rw', isa => 'Int', lazy => 1, default => -1);

    has 'name_header'   => (is => 'rw', isa => 'Wx::StaticText');
    has 'pass_header'   => (is => 'rw', isa => 'Wx::StaticText');

    has 'txt_name'      => (is => 'rw', isa => 'Wx::TextCtrl',     lazy_build => 1);
    has 'txt_sitter'    => (is => 'rw', isa => 'Wx::TextCtrl',     lazy_build => 1);
    has 'btn_save'      => (is => 'rw', isa => 'Wx::Button',       lazy_build => 1);
    has 'btn_delete'    => (is => 'rw', isa => 'Wx::Button',       lazy_build => 1);
    has 'btn_test'      => (is => 'rw', isa => 'Wx::Button',       lazy_build => 1);

=pod


Fix this broken nasty pod.


Hands back a single row as shown on the Sitter Password manager.


***

    IMPORTANT - the row handed back will be HIDDEN.  Once your caller 
    (SitterManager.pm) has the row in hand and is finished setting it up, that 
    row's show() method _must_ be called to actually display the row.

***


If is_header is passed in with a true value, the row returned will be a header 
row, respecting the same size constraints that define an actual row.  show() 
still needs to be called on header rows.



LAYOUT

parent (SitterManager's dialog)
    main_sizer
        row_panel
            row_panel_sizer
                controls

The reason for the above is so that all controls on a given row can be jammed 
onto that row_panel, which can then be easily hidden or shown.

This show/hide bit allows us to create a new, empty Sitter row when the Add New 
Sitter button is clicked, and not have this new row create ugly artifacts all 
over the dialog while the row is being created.

=cut

    sub BUILD {
        my $self = shift;

        $self->row_panel->SetSizer($self->row_panel_sizer);

        if( $self->is_header ) {#{{{
            $self->name_header(
                Wx::StaticText->new(
                    $self->row_panel, -1, 
                    'Player Name: ',
                    wxDefaultPosition, 
                    Wx::Size->new($self->input_width,$self->input_height)
                )
            );
            $self->pass_header(
                Wx::StaticText->new(
                    $self->row_panel, -1, 
                    'Sitter: ',
                    wxDefaultPosition, 
                    Wx::Size->new($self->input_width,$self->input_height)
                )
            );

            $self->name_header->SetFont( $self->get_font('/header_5') );
            $self->pass_header->SetFont( $self->get_font('/header_5') );

            $self->row_panel_sizer->Add($self->name_header, 0, 0, 0);
            $self->row_panel_sizer->Add($self->pass_header, 0, 0, 0);

            $self->main_sizer->Add($self->row_panel, 0, 0, 0);
            return;
        }#}}}

        $self->row_panel_sizer->Add($self->txt_name, 0, 0, 0);
        $self->row_panel_sizer->Add($self->txt_sitter, 0, 0, 0);
        $self->row_panel_sizer->Add($self->btn_save, 0, 0, 0);
        $self->row_panel_sizer->Add($self->btn_test, 0, 0, 0);
        $self->row_panel_sizer->AddSpacer(5);  # Separate delete button a hair
        $self->row_panel_sizer->Add($self->btn_delete, 0, 0, 0);
        $self->main_sizer->Add($self->row_panel, 0, 0, 0);
        $self->yield;

        $self->_set_events;
        return $self;
    }
    sub _build_main_sizer {#{{{
        my $self = shift;
        #return Wx::BoxSizer->new(wxHORIZONTAL);
        return $self->build_sizer($self->parent, wxHORIZONTAL, 'Row Main Sizer');
    }#}}}
    sub _build_row_panel_sizer {#{{{
        my $self = shift;
        #return Wx::BoxSizer->new(wxHORIZONTAL);
        return $self->build_sizer($self->row_panel, wxHORIZONTAL, 'Row');
    }#}}}
    sub _build_row_panel {#{{{
        my $self = shift;

        my $y = Wx::Panel->new(
            $self->parent, -1, 
            wxDefaultPosition, wxDefaultSize,
            wxTAB_TRAVERSAL,
            'mainPanel',
        );
        $y->Show(0);

        return $y;
    }#}}}
    sub _build_txt_name {#{{{
        my $self = shift;

        my $player_name = ($self->player_rec) ? $self->player_rec->player_name : q{};
        return Wx::TextCtrl->new(
            $self->row_panel, -1, 
            $player_name,
            wxDefaultPosition, 
            Wx::Size->new($self->input_width,$self->input_height),
        );
    }#}}}
    sub _build_txt_sitter {#{{{
        my $self = shift;

        my $sitter = ($self->player_rec) ? $self->player_rec->sitter : q{};
        return Wx::TextCtrl->new(
            $self->row_panel, -1, 
            $sitter, 
            wxDefaultPosition, 
            Wx::Size->new($self->input_width,$self->input_height),
        );
    }#}}}
    sub _build_btn_save {#{{{
        my $self = shift;
        my $text = ($self->player_rec) ? "Update" : "Add";
        return Wx::Button->new(
            $self->row_panel, -1, 
            $text,
            wxDefaultPosition,
            Wx::Size->new($self->button_width,$self->button_height),
        );
    }#}}}
    sub _build_btn_delete {#{{{
        my $self = shift;
        my $text = "Delete";
        ### In a perfect world, I'd like to remove this delete button from the 
        ### tab chain so the user doesn't carelessly tab onto it and delete a 
        ### sitter.
        ###
        ### However it looks to me like there's no convenient way of doing this 
        ### - there's no wxTABSTOP style or equivalent that will remove a window 
        ### from the tab chain.
        ###
        ### I found a forum posting saying that I could create a new class 
        ### derived from Wx::Button, and then override a method from Wx::Window, 
        ### but that seems not to be worth my time.
        ###
        ### In the meantime, accidentally tabbing onto the Delete button and 
        ### clicking it does produce a popconf window, so I'm not going to kill 
        ### myself for this.
        my $v = Wx::Button->new(
            $self->row_panel, -1, 
            $text,
            wxDefaultPosition,
            Wx::Size->new($self->button_width,$self->button_height),
        );
        unless($self->player_rec) {
            $v->Enable(0);
        }
        return $v;
    }#}}}
    sub _build_btn_test {#{{{
        my $self = shift;
        my $text = "Test";
        my $v = Wx::Button->new(
            $self->row_panel, -1, 
            $text,
            wxDefaultPosition,
            Wx::Size->new($self->button_width,$self->button_height),
        );
        my $vis = ( $self->txt_name->GetLineText(0) and $self->txt_sitter->GetLineText(0) ) ? 1 : 0;
        $v->Enable($vis);
        return $v;
    }#}}}
    sub _set_events {#{{{
        my $self = shift;
        unless( $self->is_header ) {
            ### Setting up these events will call the various widgets' lazy 
            ### builders if the widgets have not already been built.  On the 
            ### header row, they have not already been built, and we don't 
            ### want them built, so don't set up events (and therefore create 
            ### these widgets) for the header row.  Dummy.
            EVT_TEXT(   $self->row_panel, $self->txt_name->GetId,      sub{$self->OnTextChange(@_)} );
            EVT_TEXT(   $self->row_panel, $self->txt_sitter->GetId,    sub{$self->OnTextChange(@_)} );
            EVT_BUTTON( $self->row_panel, $self->btn_save->GetId,      sub{$self->OnSave(@_)} );
            EVT_BUTTON( $self->row_panel, $self->btn_test->GetId,      sub{$self->OnTest(@_)} );
            EVT_BUTTON( $self->row_panel, $self->btn_delete->GetId,    sub{$self->OnDelete(@_)} );
        }
        return 1;
    }#}}}

    sub find_player_id {#{{{
        my $self = shift;
        my $name = shift;

        my $hr = try {
            $self->game_client->empire->find($name);   ## no critic qw(ProhibitLongChainsOfMethodCalls)
        }
        catch {
            my $msg = (ref $_) ? $_->text : $_;
            $self->poperr($msg, "Error");
            return;
        };

# 'empires' => [
#   {
#     'name' => 'kiamo',
#     'id' => '22710'
#   }
# ],
#
# empires is defined but points to empty arref if name not found.

        return $hr->{'empires'}[0]{'id'} // undef;
    }#}}}
    sub hide {#{{{
        my $self = shift;
        $self->row_panel->Show(0);
        return 1;
    }#}}}
    sub show {#{{{
        my $self = shift;
        $self->row_panel->Show(1);
        return 1;
    }#}}}
    sub test_sitter {#{{{
        my $self = shift;
        my $name = shift;
        my $pass = shift;

=pod

Tests a name/password combo for validity.  Returns the game ID of the empire 
$name on success, dies on failure.  

The returned game ID was just fetched from the game server, not the local 
database.  So if the returned ID disagrees with whatever you have stored 
locally, the local value is wrong.

Meant to be used in cases where an automated GUI response, as from 
test_sitter_gui(), is unacceptable.

 try{
  $self->test_sitter($name, $pass)
 }
 catch {
   say "test_sitter died with '$_'";
 };

=cut

        my $uri     = $self->get_connected_server->protocol . '://' . $self->get_connected_server->url;
        my $api_key = $self->bb->resolve( service => '/Globals/api_key' );

        my $client = Games::Lacuna::Client->new(
            name        => $name,
            password    => $pass,
            uri         => $uri,
            api_key     => $api_key,
            allow_sleep => 0,
            rpc_sleep   => 1,
        );

        ### $client will be a Games::Lacuna::Client even with bogus creds, so 
        ### further testing is needed.

        ### This sub is supposed to die on error, so no try/catch needed here.
        my $empire = $client->empire(name => $name);
        my $status = $empire->get_status;

        if( defined $status->{'empire'} and defined $status->{'empire'}{'id'} ) {
            return $status->{'empire'}{'id'};
        }
        else {
            croak "Could not get empire status; this should be unreachable.";
        }
        return 1;
    }#}}}
    sub test_sitter_gui {#{{{
        my $self = shift;
        my $name = shift;
        my $pass = shift;

=pod

Calls test_sitter() and responds with appropriate popups.  Returns true on 
success, produces a popup and returns false but defined on failure; does not 
die.

if( $self->test_sitter_gui($name, $pass) ) {
 # Success!
}
else {
 # Failure, and the user already knows about it due to a poperr.
}

=cut

        my $rv = try { 
            $self->test_sitter($name, $pass);
        }
        catch {
            if( $_ =~ /empire does not exist/i ) {
                $self->poperr("No such empire exists - check spelling of empire name.", 'Error');
                return;
            }
            elsif( $_ =~ /password incorrect/i ) {
                $self->poperr("Bad password - check your spelling.", 'Error');
                return;
            }
            $self->poperr("Attempt to test sitter password returned error '$_'", 'Error');
        };

        return $rv || 0;
    }#}}}

    sub OnTextChange {#{{{
        my $self    = shift;
        my $parent  = shift;    # Wx::ScrolledWindow
        my $event   = shift;    # Wx::CommandEvent
        my $vis = ( $self->txt_name->GetLineText(0) and $self->txt_sitter->GetLineText(0) ) ? 1 : 0;
        $self->btn_test->Enable($vis);
        return 1;
    }#}}}
    sub OnSave {#{{{
        my $self    = shift;
        my $parent  = shift;    # Wx::ScrolledWindow
        my $event   = shift;    # Wx::CommandEvent

        my $name    = $self->txt_name->GetLineText(0);
        my $pass    = $self->txt_sitter->GetLineText(0);

        if( $self->player_rec ) {
            if( my $player_id = $self->test_sitter_gui($name, $pass) ) {
                ### If the user's not paying attention, they could possibly add 
                ### a given player's record twice.  In that case, we want to 
                ### make sure that whichever "update/save" button they hit most 
                ### recently really saves its data to the database, but the 
                ### older record won't be 'dirty', so DBIC won't actually update 
                ### the database, unless we force it to.
                $self->player_rec->make_column_dirty('player_id');
                $self->player_rec->make_column_dirty('player_name');
                $self->player_rec->make_column_dirty('sitter');

                $self->player_rec->player_id($player_id);
                $self->player_rec->player_name($name);
                $self->player_rec->sitter($pass);
                $self->player_rec->update();
            }
            else {
                ### The user has already received a 'bad credentials' poperr at 
                ### this point so there's no need to display another one here.
                return;
            }
        }
        else {
            if( $self->test_sitter_gui($name, $pass) ) {

                my $player_id = $self->find_player_id($name) or do { # WTF?
                    $self->poperr("Unable to find player name after it passed testing.", "WTF?");
                    return;
                };

                my $schema = $self->get_main_schema;
                if(
                    my $rec = $schema->resultset('SitterPasswords')->find_or_create(
                        {
                            server_id => $self->get_connected_server->id,
                            player_id => $player_id
                        },
                        { key => 'one_player_per_server' }
                    ) 
                ) {
                    $self->player_rec($rec);
                    $self->player_rec->player_id($player_id);
                    $self->player_rec->player_name($name);
                    $self->player_rec->sitter($pass);
                    $self->player_rec->update();
                    $self->btn_save->SetLabel('Update Sitter');
                }
                else { # WTF?
                    $self->poperr("Player record creation should not have failed, but it did.", "WTF?");
                    return;
                }
            }
            else {
                $self->poperr("The player name and sitter you entered are not a valid game login.", "Invalid Credentials!");
                return;
            }
        }
        $self->btn_delete->Enable(1);
        $self->popmsg("Sitter credentials have been saved.", "Success!");
        return 1;
    }#}}}
    sub OnTest {#{{{
        my $self    = shift;
        my $parent  = shift;    # Wx::ScrolledWindow
        my $event   = shift;    # Wx::CommandEvent

        my $name    = $self->txt_name->GetLineText(0);
        my $pass    = $self->txt_sitter->GetLineText(0);

        if( $self->test_sitter_gui($name, $pass) ) {
            $self->popmsg("Credentials are valid.", "Success!");
        }
        return 1;
    }#}}}
    sub OnDelete {#{{{
        my $self    = shift;
        my $parent  = shift;    # Wx::ScrolledWindow
        my $event   = shift;    # Wx::CommandEvent

        return unless $self->player_rec;
        return if wxNO == $self->popconf("Delete sitter for " . $self->player_rec->player_name . " - are you sure?");

        $self->player_rec->delete;
        $self->player_rec( undef );
        $self->txt_name->SetValue(q{});
        $self->txt_sitter->SetValue(q{});
        $self->btn_save->SetLabel('Add Sitter');
        $self->btn_delete->Enable(0);

        $self->popmsg("The sitter has been deleted.", "Success!");
        return 1;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

1;
