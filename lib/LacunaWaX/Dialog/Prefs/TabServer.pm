
package LacunaWax::Dialog::Prefs::TabServer {
    use Moose;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_BUTTON EVT_CHOICE EVT_COMBOBOX);
    with 'LacunaWaX::Roles::GuiElement';

    has 'main_sizer'        => (is => 'rw', isa => 'Wx::Sizer',                 lazy_build => 1);
    has 'pnl_main'          => (is => 'rw', isa => 'Wx::Panel',                 lazy_build => 1);

    has 'server_id'     => (is => 'rw', isa => 'Int');
    has 'server_list'   => (is => 'ro', isa => 'ArrayRef', lazy_build => 1, 
        documentation => q{Arrayref of server names only}
    );

    has 'grid_sizer'    => (is => 'rw', isa => 'Wx::FlexGridSizer',     lazy_build => 1);
    has 'lbl_server'    => (is => 'rw', isa => 'Wx::StaticText',        lazy_build => 1);
    has 'lbl_user'      => (is => 'rw', isa => 'Wx::StaticText',        lazy_build => 1);
    has 'lbl_pass'      => (is => 'rw', isa => 'Wx::StaticText',        lazy_build => 1);
    has 'chc_server'    => (is => 'rw', isa => 'Wx::Choice',            lazy_build => 1);
    has 'rdo_http'      => (is => 'rw', isa => 'Wx::RadioButton',       lazy_build => 1);
    has 'rdo_https'     => (is => 'rw', isa => 'Wx::RadioButton',       lazy_build => 1);
    has 'txtbox_user'   => (is => 'rw', isa => 'Wx::TextCtrl',          lazy_build => 1);
    has 'txtbox_pass'   => (is => 'rw', isa => 'Wx::TextCtrl',          lazy_build => 1);
    has 'btn_save'      => (is => 'rw', isa => 'Wx::Button',            lazy_build => 1);

    sub BUILD {
        my($self, @params) = @_;

        my $szr_vert = Wx::BoxSizer->new(wxVERTICAL);
        $szr_vert->AddSpacer(10);
        $szr_vert->Add($self->grid_sizer, 1, wxEXPAND, 0);
        $szr_vert->AddSpacer(20);
        $szr_vert->Add($self->btn_save, 0, 0, 0);

        $self->main_sizer->AddSpacer(10);
        $self->main_sizer->Add($szr_vert, 0, 0, 0);
        $self->pnl_main->SetSizer( $self->main_sizer );

        $self->set_txtbox_user;
        $self->set_pass;
        $self->_set_events;

        return $self;
    }
    sub _build_server_list {#{{{
        my $self = shift;
        my $schema = $self->get_main_schema;
        my $rs_servers = $schema->resultset('Servers')->search();

        my $list = [];
        while(my $rec = $rs_servers->next) {
            push @{$list}, $rec->name;
        }
        return $list;
    }#}}}
    sub _build_grid_sizer {#{{{
        my $self = shift;

        ### 3 rows, 3 cols, 5px vgap and hgap.
        ### Column 1 is a small spacer column.
        my $grid_sizer = Wx::FlexGridSizer->new(3, 3, 5, 5);

        ### Row 1, server choice
        $grid_sizer->Add($self->lbl_server, 0, 0, 0);
        $grid_sizer->Add($self->chc_server, 0, 0, 0);
        my $szr_radio = Wx::BoxSizer->new(wxHORIZONTAL);
        $szr_radio->Add($self->rdo_http, 0, 0, 0);
        $szr_radio->Add($self->rdo_https, 0, 0, 0);
        $grid_sizer->Add($szr_radio, 0, 0, 0);

        ### Row 2, username
        $grid_sizer->Add($self->lbl_user, 0, 0, 0);
        $grid_sizer->Add($self->txtbox_user, 0, 0, 0);
        $grid_sizer->AddSpacer(5);

        ### Row 3, password
        $grid_sizer->Add($self->lbl_pass, 0, 0, 0);
        $grid_sizer->Add($self->txtbox_pass, 0, 0, 0);
        $grid_sizer->Add(Wx::StaticText->new($self->pnl_main, -1, q{}, wxDefaultPosition, Wx::Size->new(-1,-1)));   # empty placeholder

        return $grid_sizer;
    }#}}}
    sub _build_lbl_server {#{{{
        my $self = shift;
        my $v = Wx::StaticText->new($self->pnl_main, -1, "Server", wxDefaultPosition, Wx::Size->new(80,25));
        $v->SetFont( $self->get_font('/bold_para_text_1') );
        return $v;
    }#}}}
    sub _build_lbl_user {#{{{
        my $self = shift;
        my $v =  Wx::StaticText->new($self->pnl_main, -1, "Username", wxDefaultPosition, Wx::Size->new(80,25));
        $v->SetFont( $self->get_font('/bold_para_text_1') );
        return $v;
    }#}}}
    sub _build_lbl_pass {#{{{
        my $self = shift;
        my $v = Wx::StaticText->new($self->pnl_main, -1, "Password", wxDefaultPosition, Wx::Size->new(80,25));
        $v->SetFont( $self->get_font('/bold_para_text_1') );
        return $v;
    }#}}}
    sub _build_btn_save {#{{{
        my $self = shift;
        return Wx::Button->new($self->pnl_main, -1, "Save");
    }#}}}
    sub _build_chc_server {#{{{
        my $self = shift;
        my $v = Wx::Choice->new($self->pnl_main, -1, wxDefaultPosition, Wx::Size->new(150,25), $self->server_list);
        $v->SetSelection(0);
        return $v;
    }#}}}
    sub _build_rdo_protocol {#{{{
        my $self = shift;
        return Wx::RadioBox->new(
            $self->pnl_main, -1, 
            "Connect with", 
            wxDefaultPosition, 
            Wx::Size->new(150,30), 
            ["http", "https"], 
            1, 
            wxRA_SPECIFY_ROWS
        );
    }#}}}
    sub _build_rdo_http {#{{{
        my $self = shift;

        my $v = Wx::RadioButton->new(
            $self->pnl_main, -1, 
            "http", 
            wxDefaultPosition, 
            Wx::Size->new(65,30), 
            wxRB_GROUP,
        );
        $v->SetValue(1) if( $self->get_server_protocol eq 'http');
        return $v;
    }#}}}
    sub _build_rdo_https {#{{{
        my $self = shift;
        my $v = Wx::RadioButton->new(
            $self->pnl_main, -1, 
            "https", 
            wxDefaultPosition, 
            Wx::Size->new(65,30), 
        );
        $v->SetToolTip(
              "https is more secure, but PT tends to have issues with https.\n"
            . "So if you get 'malformed JSON string' errors when connecting \n"
            . "to PT, be sure its protocol is set to 'http', not 'https'."
        );
        $v->SetValue(1) if( $self->get_server_protocol eq 'https');
        return $v;
    }#}}}
    sub _build_txtbox_user {#{{{
        my $self = shift;
        return Wx::TextCtrl->new($self->pnl_main, -1, q{}, wxDefaultPosition, Wx::Size->new(150,25));
    }#}}}
    sub _build_txtbox_pass {#{{{
        my $self = shift;
        return Wx::TextCtrl->new($self->pnl_main, -1, q{}, wxDefaultPosition, Wx::Size->new(150,25));
    }#}}}
    sub _build_main_sizer {#{{{
        my $self = shift;
        return Wx::BoxSizer->new(wxHORIZONTAL);
    }#}}}
    sub _build_pnl_main {#{{{
        my $self = shift;
        return Wx::Panel->new($self->parent, -1, wxDefaultPosition, wxDefaultSize);
    }#}}}
    sub _set_events {#{{{
        my $self = shift;
        EVT_BUTTON(     $self->pnl_main,  $self->btn_save->GetId,     sub{$self->ancestor->OnSavePrefs(@_)} );
        EVT_CHOICE(     $self->pnl_main,  $self->chc_server->GetId,   sub{$self->OnChooseServer()} );
        return 1;
    }#}}}

    sub get_server_protocol {#{{{
        my $self = shift;
        my $server_name = $self->server_list->[ $self->chc_server->GetCurrentSelection ];
        my $schema      = $self->get_main_schema;
        my $server_rec  = $schema->resultset('Servers')->find({ name => $server_name });
        return $server_rec->protocol;
    }#}}}
    sub set_proto {#{{{
        my $self = shift;
        my $schema      = $self->get_main_schema;
        my $server_name = $self->server_list->[ $self->chc_server->GetCurrentSelection ];

        my $server_rec = $schema->resultset('Servers')->find({ name => $server_name });
        if( $server_rec->protocol eq 'https' ) {
            $self->rdo_https->SetValue(1);
        }
        else {
            $self->rdo_http->SetValue(1);
        }
        return 1;
    }#}}}
    sub set_txtbox_user {#{{{
        my $self        = shift;
        my $schema      = $self->get_main_schema;
        my $server_name = $self->server_list->[ $self->chc_server->GetCurrentSelection ];

        my $rs = $schema->resultset('ServerAccounts')->search(
            { 
                'server.name' => $server_name,
                'default_for_server' => 1,
            },
            { join => 'server' }
        );
        if( my $r = $rs->next ) {
            $self->txtbox_user->SetValue($r->username);
        }
        return 1;
    }#}}}
    sub set_pass {#{{{
        my $self = shift;
        my $schema      = $self->get_main_schema;
        my $server_name = $self->server_list->[ $self->chc_server->GetCurrentSelection ];
        my $username    = $self->txtbox_user->GetLineText(0);

        my $password = q{};
        if( my $rec = $schema->resultset('ServerAccounts')->find(
            { 
                username        => $username,
                'server.name'   => $server_name 
            },
            { join => 'server' }
        ) ) {
            $password = $rec->password;
        }
        $self->txtbox_pass->SetValue( $password );
        return 1;
    }#}}}
    sub set_default_account {#{{{
        my $self = shift;
        my $schema      = $self->get_main_schema;
        my $server_name = $self->server_list->[ $self->chc_server->GetCurrentSelection ];
        my $username    = $self->txtbox_user->GetLineText(0);

        my $password = q{};
        my $state    = 0;
        if( my $rec = $schema->resultset('ServerAccounts')->find(
            { 
                username        => $username,
                'server.name'   => $server_name 
            },
            { join => 'server' }
        ) ) {
            $state = 1 if $rec->default_for_server;

        }

        ### Exactly one account has to be the default for each server.  If the 
        ### user neglected to check the 'default' checkbox for their only 
        ### account, force that account to be the default.
        unless($state) {
            my $rs = $schema->resultset('ServerAccounts')->search(
                {
                    default_for_server  => 1,
                    'server.name'       => $server_name,
                },
                { join => 'server' }
            );
            unless( $rs->count ) {
                $state = 1;
            }
        }
        return 1;
    }#}}}

    sub OnChooseServer {#{{{
        my $self = shift;
        $self->set_proto();
        $self->set_txtbox_user();
        $self->set_default_account();
        $self->set_pass();
        return 1;
    }#}}}
    sub OnChooseUser {#{{{
        my $self = shift;
        $self->set_default_account();
        $self->set_pass();
        return 1;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;
