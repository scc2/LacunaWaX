use v5.14;

=pod


CREATE TABLE "SSAlerts" (
    "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, 
    "server_id" INTEGER NOT NULL,
    "station_id" INTEGER NOT NULL, 
    "enabled" INTEGER NOT NULL DEFAULT 0, 
    "min_res" BIGINT NOT NULL  DEFAULT 0
)


    "min_res" INTEGER NOT NULL  DEFAULT 0


Allow user to set up alerts per SS.

- Checkbox to turn on alerts for this station
    - alerts are automatically sent to the current player's account email

- If any res/hr drops below X

- If any ships are incoming
    - other than alliance ships

- If any foreign spies are onsite
    - other than alliance spies

- If our star becomes unseized
    - If seized by an SS other than ourselves, check if the seizing SS is 
      owned by the alliance.  If so, no alert.





- Allow sending alert to regular email
    - will need to be a bit more careful about this; may want to re-think it.
    - The more I think about this, the more I think it's a bad idea without 
      having some sort of email verifyer set up.

=cut


package LacunaWaX::MainSplitterWindow::RightPane::SSHealth {
    use Data::Dumper;
    use Moose;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_BUTTON EVT_CLOSE EVT_TEXT);
    with 'LacunaWaX::Roles::MainSplitterWindow::RightPane';

    has 'sizer_debug' => (is => 'rw', isa => 'Int',  lazy => 1, default => 0);

    has 'police' => (
        is          => 'rw',
        isa         => 'Maybe[Games::Lacuna::Client::Buildings::PoliceStation]',
        lazy_build  => 1,
    );

    has 'number_formatter'  => (
        is      => 'rw',
        isa     => 'Number::Format', 
        lazy    => 1,
        default => sub{ Number::Format->new }
    );

    has 'alert_record' => (
        is          => 'rw',
        isa         => 'LacunaWaX::Model::Schema::SSAlerts',
        lazy_build  => 1,
    );

    has 'planet_name'       => (is => 'rw', isa => 'Str',       required => 1);
    has 'planet_id'         => (is => 'rw', isa => 'Int',       lazy_build => 1);
    has 'szr_header'        => (is => 'rw', isa => 'Wx::Sizer', lazy_build => 1, documentation => 'vertical' );

    has 'lbl_header'        => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'lbl_instructions'  => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);

    has 'chk_enable_alert'  => (is => 'rw', isa => 'Wx::CheckBox',      lazy_build => 1);
    has 'lbl_enable_alert'  => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'szr_enable_alert'  => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => 'horizontal' );

    has 'lbl_min_res_pre'   => (is => 'rw', isa => 'Wx::StaticText', lazy_build => 1);
    has 'lbl_min_res_suf'   => (is => 'rw', isa => 'Wx::StaticText', lazy_build => 1);
    has 'szr_min_res'       => (is => 'rw', isa => 'Wx::Sizer',      lazy_build => 1, documentation => 'horizontal' );
    has 'txt_min_res'       => (is => 'rw', isa => 'Wx::TextCtrl',   lazy_build => 1);

    has 'szr_save' => (is => 'rw', isa => 'Wx::Sizer',  lazy_build => 1, documentation => 'vertical' );
    has 'btn_save' => (is => 'rw', isa => 'Wx::Button', lazy_build => 1);

    sub BUILD {
        my $self = shift;

        $self->szr_header->Add($self->lbl_header, 0, 0, 0);
        $self->szr_header->AddSpacer(5);
        $self->szr_header->Add($self->lbl_instructions, 0, 0, 0);

        $self->szr_enable_alert->Add($self->lbl_enable_alert, 0, 0, 0);
        $self->szr_enable_alert->AddSpacer(10);
        $self->szr_enable_alert->Add($self->chk_enable_alert, 0, 0, 0);

        $self->szr_min_res->Add($self->lbl_min_res_pre, 0, 0, 0);
        $self->szr_min_res->AddSpacer(10);
        $self->szr_min_res->Add($self->txt_min_res, 0, 0, 0);
        $self->szr_min_res->AddSpacer(10);
        $self->szr_min_res->Add($self->lbl_min_res_suf, 0, 0, 0);

        $self->szr_save->Add($self->btn_save, 0, 0, 0);

        $self->content_sizer->Add($self->szr_header, 0, 0, 0);
        $self->content_sizer->AddSpacer(20);
        $self->content_sizer->Add($self->szr_enable_alert, 0, 0, 0);
        $self->content_sizer->AddSpacer(0);
        $self->content_sizer->Add($self->szr_min_res, 0, 0, 0);
        $self->content_sizer->AddSpacer(20);
        $self->content_sizer->Add($self->szr_save, 0, 0, 0);
        return $self;
    }
    sub _build_alert_record {#{{{
        my $self = shift;
        
        my $schema = $self->get_main_schema;
        my $rec = $schema->resultset("SSAlerts")->find_or_create(
            {
                server_id   => $self->server->id,
                station_id  => $self->planet_id,
            },
            {
                key => 'one_alert_per_station',
            }
        );
        return $rec;
    }#}}}
    sub _build_btn_save {#{{{
        my $self = shift;
        my $v = Wx::Button->new($self->parent, -1, "Save Alert Preferences");
        $v->SetFont( $self->get_font('/para_text_1') );
        return $v;
    }#}}}
    sub _build_chk_enable_alert {#{{{
        my $self = shift;
        my $v = Wx::CheckBox->new(
            $self->parent, -1, 
            'Yes',
            wxDefaultPosition, 
            Wx::Size->new(-1,-1), 
        );

        $v->SetFont( $self->get_font('/para_text_2') );
        $v->SetValue( $self->alert_record->enabled );

        return $v;
    }#}}}
    sub _build_lbl_enable_alert {#{{{
        my $self = shift;
        my $v = Wx::StaticText->new(
            $self->parent, -1, 
            "Enable alerts for " . $self->planet_name . "?",
            wxDefaultPosition, 
            Wx::Size->new(-1, 20)
        );
        $v->SetFont( $self->get_font('/para_text_2') );
        return $v;
    }#}}}
    sub _build_lbl_header {#{{{
        my $self = shift;
        my $v = Wx::StaticText->new(
            $self->parent, -1, 
            "Monitor Health of " . $self->planet_name,
            wxDefaultPosition, 
            Wx::Size->new(-1, 80)
        );
        $v->SetFont( $self->get_font('/header_1') );
        $v->Wrap( $self->parent->GetSize->GetWidth - 130 ); # accounts for the vertical scrollbar
        return $v;
    }#}}}
    sub _build_lbl_instructions {#{{{
        my $self = shift;

        my $text = "Check the Enable Alerts checkbox to be alerted if Bad Things happen to this station.

If you want to be alerted, remember that you have to actually schedule the Schedule_ss_alerts.exe program!  Just setting preferences here and then not setting up a scheduled job will fail to ever warn you about anything.  See the Help documentation if you need help setting up a scheduled task.

Alerts will be sent to you in game mail, and will have the 'Correspondence' tag attached.  You should always filter your mail by Correspondence in the dropdown before deleting a bunch of mail, or you may miss alerts (not to mention actual messages sent by other players).
        
'Bad Things' that will be diagnosed include:
    - The station's star is unseized
    - The station's star becomes seized by any other station
    - Any non-allied ships are incoming
        - This will only work if there's a Police Station built.
    - Any spies are detected who are not on Counter Espionage
        - Again, this will only work if there's a Police Station.
    - Any of the station's resources per hour drop below the amount you set below.
";

        my $v = Wx::StaticText->new(
            $self->parent, -1, 
            $text,
            wxDefaultPosition, 
            Wx::Size->new(-1, 320)
        );
        $v->Wrap( $self->parent->GetSize->GetWidth - 130 ); # accounts for the vertical scrollbar
        $v->SetFont( $self->get_font('/para_text_2') );
        return $v;
    }#}}}
    sub _build_lbl_min_res_pre {#{{{
        my $self = shift;
        my $v = Wx::StaticText->new(
            $self->parent, -1, 
            "Alert if any res drops below: ",
            wxDefaultPosition, 
            Wx::Size->new(-1, 40)
        );
        $v->SetFont( $self->get_font('/para_text_2') );
        return $v;
    }#}}}
    sub _build_lbl_min_res_suf {#{{{
        my $self = shift;
        my $v = Wx::StaticText->new(
            $self->parent, -1, 
            "/ hr",
            wxDefaultPosition, 
            Wx::Size->new(-1, 40)
        );
        $v->SetFont( $self->get_font('/para_text_2') );
        return $v;
    }#}}}
    sub _build_planet_id {#{{{
        my $self = shift;
        return $self->game_client->planet_id( $self->planet_name );
    }#}}}
    sub _build_police {#{{{
        my $self = shift;

        my $police = try {
            $self->game_client->get_building($self->planet_id, 'Police Station');
        }
        catch {
            my $msg = (ref $_) ? $_->text : $_;
            $self->poperr($msg);
            return;
        };

        return( $police and ref $police eq 'Games::Lacuna::Client::Buildings::PoliceStation' ) ? $police : undef;
    }#}}}
    sub _build_szr_enable_alert {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxHORIZONTAL, 'Enable Alert');
    }#}}}
    sub _build_szr_header {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxVERTICAL, 'Header');
    }#}}}
    sub _build_szr_min_res {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxHORIZONTAL, 'Min Res');
    }#}}}
    sub _build_szr_save {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxVERTICAL, 'Save');
    }#}}}
    sub _build_txt_min_res {#{{{
        my $self = shift;

        my $v = Wx::TextCtrl->new(
            $self->parent, -1, 
            '', 
            wxDefaultPosition, 
            Wx::Size->new(100,25)
        );

        $v->SetValue(
            $self->number_formatter->format_number( $self->alert_record->min_res || 0 )
        );

        my $tt = Wx::ToolTip->new( "If any resource per hour drops below this number, send an alert." );
        $v->SetToolTip($tt);

        return $v;
    }#}}}
    sub _set_events {#{{{
        my $self = shift;
        EVT_TEXT(   $self->parent, $self->txt_min_res->GetId,   sub{$self->OnUpdateMinRes(@_)}  );
        EVT_BUTTON( $self->parent, $self->btn_save->GetId,      sub{$self->OnSave(@_)}  );
        return;
    }#}}}

    sub OnClose {#{{{
        my $self = shift;
        return 1;
    }#}}}
    sub OnSave {#{{{
        my $self    = shift;
        my $parent  = shift;    # Wx::ScrolledWindow
        my $event   = shift;    # Wx::CommandEvent

        my $enabled = ( $self->chk_enable_alert->IsChecked ) ? 1 : 0;
        my $min_res = $self->txt_min_res->GetValue || 0;
           $min_res =~ s/\D//g;

        if( $enabled and $min_res < 10_000_000 ) {
            if( wxNO == $self->popconf("You're alerting on less than ten million res/hour; that seems awfully low.  Are you sure that shouldn't be set higher?") ) {
                $self->popmsg("Don't feel bad, we all make mistakes.  Go fix your goofy number and try again.");
                return 0;
            }

            $self->popmsg("OK, it's your funeral.  But think hard about increasing that number or your station could get into trouble.");
        }

        $self->alert_record->enabled($enabled);
        $self->alert_record->min_res($min_res);
        $self->alert_record->update;

        my $msg = ($enabled)
            ? "Station alerts for " . $self->planet_name . " have been TURNED ON."
            : "Station alerts for " . $self->planet_name . " have been DISABLED.";

        $self->popmsg($msg);
        return 1;
    }#}}}
    sub OnUpdateMinRes {#{{{
        my $self    = shift;
        my $parent  = shift;    # Wx::ScrolledWindow
        my $event   = shift;    # Wx::CommandEvent

        my $orig_num = my $num = $self->txt_min_res->GetValue;
        $num =~ s/\D//g;
        $num = $self->number_formatter->format_number($num);

        unless( $num eq $orig_num ) {
            $self->txt_min_res->SetValue($num);
            $self->txt_min_res->SetInsertionPointEnd();
        }

        return 1;
    }#}}}

   no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;
