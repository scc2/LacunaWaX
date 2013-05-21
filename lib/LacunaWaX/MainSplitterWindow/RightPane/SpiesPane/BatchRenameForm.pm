
package LacunaWaX::MainSplitterWindow::RightPane::SpiesPane::BatchRenameForm {
    use v5.14;
    use Moose;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_BUTTON);
    with 'LacunaWaX::Roles::GuiElement';

    has 'sizer_debug'   => (is => 'rw', isa => 'Int',                       lazy => 1, default => 0 );
    has 'dialog_status' => (is => 'rw', isa => 'LacunaWaX::Dialog::Status', lazy_build  => 1        );
    has 'fix_labels'    => (is => 'rw', isa => 'ArrayRef',                  lazy_build  => 1        );

    has 'stop_renaming' => (is => 'rw', isa => 'Int', lazy => 1, default => 0,
        documentation => q{
            If the user closes the status window, this will be set to True, in which 
            case the renaming loop will quit.
        }
    );

    has 'btn_rename'    => (is => 'rw', isa => 'Wx::Button',        lazy_build => 1);
    has 'txt_name'      => (is => 'rw', isa => 'Wx::TextCtrl',      lazy_build => 1);
    has 'rdo_fix'       => (is => 'rw', isa => 'Wx::RadioBox',      lazy_build => 1, 
        documentation => q{
            sufFIX or preFIX (or none)
        }
    );

    has 'szr_main'          => (is => 'rw', isa => 'Wx::BoxSizer', lazy_build => 1, documentation => 'vertical'     );
    has 'szr_center_name'   => (is => 'rw', isa => 'Wx::BoxSizer', lazy_build => 1, documentation => 'horizontal'   );
    has 'szr_center_button' => (is => 'rw', isa => 'Wx::BoxSizer', lazy_build => 1, documentation => 'horizontal'   );

    sub BUILD {
        my $self = shift;

        $self->szr_center_name->AddSpacer(5);
        $self->szr_center_name->Add($self->txt_name, 0, 0, 0);
       
        $self->szr_main->Add($self->szr_center_name, 0, 0, 0);
        $self->szr_main->AddSpacer(10);

        $self->szr_main->Add($self->rdo_fix, 0, 0, 0);
        $self->szr_main->AddSpacer(10);

        $self->szr_center_button->AddSpacer(30);
        $self->szr_center_button->Add($self->btn_rename, 0, 0, 0);

        $self->szr_main->Add($self->szr_center_button, 0, 0, 0);
        return $self;
    }
    sub _build_btn_rename {#{{{
        my $self = shift;
        my $v = Wx::Button->new(
            $self->parent, -1,
            "Rename all spies"
        );
        $v->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_1') );
        return $v;
    }#}}}
    sub _build_dialog_status {#{{{
        my $self = shift;

        my $v = LacunaWaX::Dialog::Status->new( 
            app         => $self->app,
            ancestor    => $self,
            title       => 'Batch Rename Spies',
            recsep      => '-=-=-=-=-=-=-',
        );
        $v->hide;
        return $v;
    }#}}}
    sub _build_fix_labels {#{{{
        my $self = shift;
        return ['Prefix', 'Suffix', 'None'];
    }#}}}
    sub _build_rdo_fix {#{{{
        my $self = shift;
        my $v = Wx::RadioBox->new(
            $self->parent, -1, 
            "Add Pre- or Suf- fix", 
            wxDefaultPosition, 
            Wx::Size->new(220,50), 
            $self->fix_labels,
            1, 
            wxRA_SPECIFY_ROWS
        );
        $v->SetSelection(1);    # Default to Suffix
        $v->SetToolTip( "An integer counter will be added to the beginning or end of all of your spies' names." );
        return $v;
    }#}}}
    sub _build_szr_center_button {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxHORIZONTAL, 'Center Button');
    }#}}}
    sub _build_szr_center_name {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxHORIZONTAL, 'Center Name');
    }#}}}
    sub _build_szr_main {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxVERTICAL, 'Batch Rename', 1, undef, Wx::Size->new(200, 150));
    }#}}}
    sub _build_txt_name {#{{{
        my $self = shift;
        my $v = Wx::TextCtrl->new(
            $self->parent, -1, 
            q{},
            wxDefaultPosition, 
            Wx::Size->new(150, 20)
        );
        $v->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_1') );
        $v->SetToolTip( 'This will be the name of all of your spies, modified by the Pre- or Suf- fix' );
        return $v;
    }#}}}
    sub _set_events {#{{{
        my $self = shift;
        EVT_BUTTON( $self->parent,  $self->btn_rename->GetId,    sub{$self->OnRenameButtonClick(@_)} );
        return 1;
    }#}}}

    ### Wrappers around dialog_status's methods to first check for existence of 
    ### dialog_status.
    sub dialog_status_say {#{{{
        my $self = shift;
        my $msg  = shift;
        if( $self->has_dialog_status ) {
            try{ $self->dialog_status->say($msg) };
        }
        return 1;
    }#}}}
    sub dialog_status_say_recsep {#{{{
        my $self = shift;
        if( $self->has_dialog_status ) {
            try{ $self->dialog_status->say_recsep };
        }
        return 1;
    }#}}}

    ### Pseudo events
    sub OnClose {#{{{
        my $self = shift;
        $self->dialog_status->close if $self->has_dialog_status;
        return 1;
    }#}}}
    sub OnDialogStatusClose {#{{{
        my $self = shift;
        if($self->has_dialog_status) {
            $self->clear_dialog_status;
        }
        $self->stop_renaming(1);
        return 1;
    }#}}}

    ### Real events
    sub OnRenameButtonClick {#{{{
        my $self    = shift;
        my $parent  = shift;
        my $event   = shift;

        my $base_name = $self->txt_name->GetValue;
        my $fix       = $self->rdo_fix->GetString( $self->rdo_fix->GetSelection );

        unless($base_name) {
            $self->app->poperr("You must enter a name to rename spies.");
            return;
        }
        if( $fix eq 'None' ) {
            if( wxNO == $self->app->popconf("Without a prefix or suffix, all of your spies on this planet will have the same name.\nThis is legal if it's what you really want - is it?", "Are you sure?") ) {
                $self->app->popmsg("OK - add either a prefix or suffix and try again.");
                return;
            }
        }

        $self->dialog_status->erase;
        $self->dialog_status->show;
        $self->app->Yield;

        ### Most people will have 90 spies, and the server seems to handle 
        ### renames pretty quickly, so make sure that we're sleeping a second 
        ### between each request.  We'll put it back again when we're done.
        my $old_rpc_sleep = $self->app->game_client->rpc_sleep;
        $self->app->game_client->rpc_sleep(1);

        my $cnt = my $renamed = 0;
        SPY_ROW:
        foreach my $row( @{$self->ancestor->spy_table} ) {
            $cnt++;

            if( $self->stop_renaming ) {
                ### User closed the status dialog box, so get out.
                $self->stop_renaming(0);
                last SPY_ROW;
            }

            my $new_name;
            given($fix) {
                when( 'Prefix' ) { $new_name = $cnt . " $base_name"; }
                when( 'Suffix' ) { $new_name = "$base_name " . $cnt; }
                default { $new_name = $base_name; }
            }

            if( $row->spy->name eq $new_name ) {
                $self->dialog_status_say($row->spy->name . " is already correctly named; skipping.");
                next SPY_ROW;
            }

            $self->dialog_status_say("Renaming " . $row->spy->name . " to $new_name");
            my $rv = try {
                ### No need to create our own int_min; we know the SpiesPane has 
                ### one.
                $self->ancestor->int_min->name_spy($row->spy->id, $new_name);
            }
            catch {
                my $msg = (ref $_) ? $_->text : $_;
                if( $msg =~ /slow down/i ) {
                    my $start = time();
                    my $resp  = $self->app->popconf("You just went over 60 RPC/minute - wait a minute and try again?");
                    if( $resp == wxYES ) {
                        my $slp_cnt = 0;
                        SLEEP:
                        while(1) {
                            $slp_cnt++;
                            last SLEEP if time() > $start + 60;
                            last SLEEP if $slp_cnt > 62;    # failsafe
                            $self->dialog_status_say("$slp_cnt) Sleeping...");
                            sleep 1;
                            $self->app->Yield;
                        }
                        return 'redo';
                    }
                    else {
                        $self->dialog_status->close;
                        $self->clear_dialog_status;
                        return 'last';
                    }
                }
                $self->app->poperr($msg);
                $self->clear_dialog_status;
                return;
            };
            unless( ref $rv ) {
                redo SPY_ROW if $rv eq 'redo';
                last SPY_ROW if $rv eq 'last';
            }
            if( $rv ) {
                $row->change_name( $new_name );
                $renamed++;
            }
            $self->app->Yield;
        }

        if( $renamed ) {
            ### Spies have been renamed, so expire the spies currently in the 
            ### cache so the new names show up on the next screen load.
            if( $self->app->wxbb ) {
                my $chi  = $self->app->wxbb->resolve( service => '/Cache/raw_memory' );
                my $key  = join q{:}, ('BODIES', 'SPIES', $self->ancestor->planet_id);
                $chi->remove($key);
            }
        }

        $self->app->game_client->rpc_sleep($old_rpc_sleep);
        $self->dialog_status_say_recsep;
        $self->dialog_status_say("Renamed $renamed spies.");
        $self->dialog_status_say("You may now close this window.");

        return 1;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;
