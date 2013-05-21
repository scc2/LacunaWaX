
package LacunaWax::Dialog::Prefs::TabAutovote {
    use Moose;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_BUTTON);

    has 'app'      => (is => 'rw', isa => 'LacunaWaX',                 required => 1,  weak_ref => 1);
    has 'parent'   => (is => 'rw', isa => 'Wx::Notebook',              required => 1);
    has 'ancestor' => (is => 'rw', isa => 'LacunaWaX::Dialog::Prefs',  required => 1);

    has 'box_height' => (is => 'rw', isa => 'Int', lazy => 1, default => 140,
        documentation => q{
            Height of the radio and listctrl boxes in the middle of the screen.
        }
    );

    has 'btn_save'          => (is => 'rw', isa => 'Wx::Button',                lazy_build => 1);
    has 'lbl_instructions'  => (is => 'rw', isa => 'Wx::StaticText',            lazy_build => 1);
    has 'list_known_ss'     => (is => 'rw', isa => 'Wx::ListCtrl',              lazy_build => 1);
    has 'main_sizer'        => (is => 'rw', isa => 'Wx::Sizer',                 lazy_build => 1);
    has 'pnl_main'          => (is => 'rw', isa => 'Wx::Panel',                 lazy_build => 1);
    has 'rdo_autovote'      => (is => 'rw', isa => 'Wx::RadioBox',              lazy_build => 1);

    sub BUILD {
        my($self, @params) = @_;

        my $szr_av = Wx::BoxSizer->new(wxVERTICAL);
        $szr_av->AddSpacer(10);
        $szr_av->Add($self->lbl_instructions);
        $szr_av->AddSpacer(10);

        my $szr_middle = Wx::BoxSizer->new(wxHORIZONTAL);
        $szr_middle->Add($self->rdo_autovote);
        $szr_middle->AddSpacer(10);
        $szr_middle->Add($self->list_known_ss);
        $szr_av->Add($szr_middle);

        $szr_av->AddSpacer(10);
        $szr_av->Add($self->btn_save);

        $self->main_sizer->AddSpacer(10);
        $self->main_sizer->Add($szr_av, 0, 0, 0);
        $self->pnl_main->SetSizer( $self->main_sizer );
        $self->_set_events;

        return $self;
    }
    sub _build_main_sizer {#{{{
        my $self = shift;
        my $v = Wx::BoxSizer->new(wxHORIZONTAL);
        return $v;
    }#}}}
    sub _build_btn_save {#{{{
        my $self = shift;
        my $v = Wx::Button->new($self->pnl_main, -1, "Save");
        return $v;
    }#}}}
    sub _build_lbl_instructions {#{{{
        my $self = shift;

        my $inst = "Autovote settings here apply to all space stations you have visited in this app.  "
                . "See the Help menu for more information.";

        my $v = Wx::StaticText->new(
            $self->pnl_main, -1, 
            $inst, 
            wxDefaultPosition, 
            Wx::Size->new(365,25)
        );
        $v->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_1') );
        return $v;
    }#}}}
    sub _build_list_known_ss {#{{{
        my $self = shift;

        my $v = Wx::ListCtrl->new(
            $self->pnl_main, -1, 
            wxDefaultPosition, 
            Wx::Size->new(150,$self->box_height), 
            wxLC_REPORT
            |wxSUNKEN_BORDER
            |wxLC_SINGLE_SEL
        );
        $v->InsertColumn(0, 'Known Stations');
        $v->SetColumnWidth(0, 127);
        $v->Arrange(wxLIST_ALIGN_TOP);
        $self->app->Yield;

        my $schema = $self->app->bb->resolve( service => '/Database/schema' );
        my $ss_rs = $schema->resultset('BodyTypes')->search({type_general => 'space station', server_id => $self->app->server->id});

        my @stations = ();
        while(my $rec = $ss_rs->next) {
            if(my $pname = $self->app->game_client->planet_name($rec->body_id)) {
                push @stations, $pname;
            }
        }
        foreach my $s(reverse sort{ lc $a cmp lc $b}@stations) {
            my $item = Wx::ListItem->new();
            $item->SetText($s);
            my $row_idx = $v->InsertItem($item);
        }

        return $v;
    }#}}}
    sub _build_pnl_main {#{{{
        my $self = shift;
        my $v = Wx::Panel->new($self->parent, -1, wxDefaultPosition, wxDefaultSize);
        return $v;
    }#}}}
    sub _build_rdo_autovote {#{{{
        my $self = shift;
        my $schema = $self->app->bb->resolve( service => '/Database/schema' );

        my $choices = [qw(None Owner All)];
        my $checked = $choices->[0];
        if( my $rec = $schema->resultset('ScheduleAutovote')->find({server_id => $self->app->server->id}) ) {
            $checked = ucfirst $rec->proposed_by;
        }

        my $v = Wx::RadioBox->new(
            $self->pnl_main, -1, 
            "Autovote", 
            wxDefaultPosition, 
            Wx::Size->new(100, $self->box_height), 
            $choices,
            0,
            wxRA_SPECIFY_ROWS
        );
        $v->SetStringSelection( $checked );

        return $v;
    }#}}}
    sub _set_events {#{{{
        my $self = shift;
        EVT_BUTTON( $self->pnl_main,  $self->btn_save->GetId,     sub{$self->ancestor->OnSavePrefs(@_)} );
        return 1;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;
