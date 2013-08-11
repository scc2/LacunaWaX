
package LacunaWaX::Dialog::Mail {
    use v5.14;
    use Data::Dumper; $Data::Dumper::Indent = 1;
    use Moose;
    use Regexp::Common;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_BUTTON EVT_CHECKBOX EVT_CHOICE EVT_CLOSE EVT_SIZE);
    use LacunaWaX::Dialog::NonScrolled;
    extends 'LacunaWaX::Dialog::NonScrolled';

    has 'sizer_debug' => (is => 'rw', isa => 'Int',  lazy => 1, default => 0);

    has 'addy_height'   => (is => 'rw', isa => 'Int',                           lazy => 1,      default => 25   );
    has 'ally_members'  => (is => 'rw', isa => 'ArrayRef',                      lazy_build => 1                 );
    has 'inbox'         => (is => 'rw', isa => 'Games::Lacuna::Client::Inbox',  lazy_build => 1                 );

    has 'btn_clear_inbox'   => (is => 'rw', isa => 'Wx::Button',        lazy_build => 1);
    has 'btn_clear_to'      => (is => 'rw', isa => 'Wx::Button',        lazy_build => 1);
    has 'btn_send'          => (is => 'rw', isa => 'Wx::Button',        lazy_build => 1);
    has 'chc_ally'          => (is => 'rw', isa => 'Wx::Choice',        lazy_build => 1);
    has 'chk_alert'         => (is => 'rw', isa => 'Wx::CheckBox',      lazy_build => 1);
    has 'chk_attacks'       => (is => 'rw', isa => 'Wx::CheckBox',      lazy_build => 1);
    has 'chk_corr'          => (is => 'rw', isa => 'Wx::CheckBox',      lazy_build => 1);
    has 'chk_excav'         => (is => 'rw', isa => 'Wx::CheckBox',      lazy_build => 1);
    has 'chk_parl'          => (is => 'rw', isa => 'Wx::CheckBox',      lazy_build => 1);
    has 'chk_probe'         => (is => 'rw', isa => 'Wx::CheckBox',      lazy_build => 1);
    has 'chk_cust'			=> (is => 'rw', isa => 'Wx::CheckBox',      lazy_build => 1);
    has 'chk_read'          => (is => 'rw', isa => 'Wx::CheckBox',      lazy_build => 1);
    has 'lbl_ally'          => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'lbl_body'          => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'lbl_btn_send'      => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1, documentation => 'blank string');
    has 'lbl_hdr_clear'     => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'lbl_hdr_page'      => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'lbl_hdr_send'      => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'lbl_instructions'  => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'lbl_subject'       => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'lbl_to'            => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'szr_ally'          => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => 'horizontal');
    has 'szr_body'          => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => 'horizontal');
    has 'szr_btn_send'      => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => 'horizontal');
    has 'szr_clear'         => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => 'vertical'    );
    has 'szr_cust'			=> (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => 'horizontal'  );	
    has 'szr_check'         => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => 'horizontal'  );
    has 'szr_header'        => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => 'vertical'    );
    has 'szr_instructions'  => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1);
    has 'szr_send'          => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1);
    has 'szr_subject'       => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => 'horizontal');
    has 'szr_to'            => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => 'horizontal');
    has 'txt_cust'          => (is => 'rw', isa => 'Wx::TextCtrl',      lazy_build => 1);
    has 'txt_to'            => (is => 'rw', isa => 'Wx::TextCtrl',      lazy_build => 1);
    has 'txt_subject'       => (is => 'rw', isa => 'Wx::TextCtrl',      lazy_build => 1);
    has 'txt_body'          => (is => 'rw', isa => 'Wx::TextCtrl',      lazy_build => 1);

    sub BUILD {
        my $self = shift;

        $self->SetTitle( $self->title );
        $self->SetSize( $self->size );

        ### header
        $self->szr_header->AddSpacer(5);
        $self->szr_header->Add($self->lbl_hdr_page, 0, 0, 0);
        $self->szr_header->AddSpacer(10);

        ### clear mail checkboxes
        $self->szr_check->Add($self->chk_alert, 0, 0, 0);
        $self->szr_check->AddSpacer(2);
        $self->szr_check->Add($self->chk_attacks, 0, 0, 0);
        $self->szr_check->AddSpacer(2);
        $self->szr_check->Add($self->chk_corr, 0, 0, 0);
        $self->szr_check->AddSpacer(2);
        $self->szr_check->Add($self->chk_excav, 0, 0, 0);
        $self->szr_check->AddSpacer(2);
        $self->szr_check->Add($self->chk_parl, 0, 0, 0);
        $self->szr_check->AddSpacer(2);
        $self->szr_check->Add($self->chk_probe, 0, 0, 0);
        $self->szr_check->AddSpacer(2);
        $self->szr_check->Add($self->chk_cust, 0, 0, 0);		
        $self->szr_check->AddSpacer(20);
        $self->szr_check->Add($self->chk_read, 0, 0, 0);		
		
        ### clear mail block
        $self->szr_clear->Add($self->lbl_hdr_clear, 0, 0, 0);
        $self->szr_clear->AddSpacer(5);
        $self->szr_clear->Add($self->szr_check, 0, 0, 0);
		
		### custom text entry	
        $self->szr_clear->AddSpacer(5);
        $self->szr_clear->Add($self->szr_cust, 0, 0, 0);
        $self->szr_cust->AddSpacer(5);
        $self->szr_cust->Add($self->btn_clear_inbox, 0, 0, 0);		
        $self->szr_cust->AddSpacer(20);
        $self->szr_cust->Add($self->txt_cust, 0, 0, 0);		
		
        ### send mail form sizers
        $self->szr_ally->Add($self->lbl_ally, 0, 0, 0);
        $self->szr_ally->Add($self->chc_ally, 0, 0, 0);
        $self->szr_to->Add($self->lbl_to, 0, 0, 0);
        $self->szr_to->Add($self->txt_to, 0, 0, 0);
        $self->szr_to->AddSpacer(2);
        $self->szr_to->Add($self->btn_clear_to, 0, 0, 0);
        $self->szr_subject->Add($self->lbl_subject, 0, 0, 0);
        $self->szr_subject->Add($self->txt_subject, 0, 0, 0);
        $self->szr_body->Add($self->lbl_body, 0, 0, 0);
        $self->szr_body->Add($self->txt_body, 0, 0, 0);
        $self->szr_btn_send->Add($self->lbl_btn_send, 0, 0, 0);
        $self->szr_btn_send->Add($self->btn_send, 0, 0, 0);

        ### send mail form
        $self->szr_send->Add($self->lbl_hdr_send, 0, 0, 0);
        $self->szr_send->AddSpacer(2);
        $self->szr_send->Add($self->szr_ally, 0, 0, 0);
        $self->szr_send->AddSpacer(2);
        $self->szr_send->Add($self->szr_to, 0, 0, 0);
        $self->szr_send->AddSpacer(2);
        $self->szr_send->Add($self->szr_subject, 0, 0, 0);
        $self->szr_send->AddSpacer(2);
        $self->szr_send->Add($self->szr_body, 0, 0, 0);
        $self->szr_send->AddSpacer(2);
        $self->szr_send->Add($self->szr_btn_send, 0, 0, 0);
    
        ### combine the above
        $self->main_sizer->Add($self->szr_header, 0, 0, 0);
        $self->main_sizer->AddSpacer(20);
        $self->main_sizer->Add($self->szr_clear, 0, 0, 0);	
        $self->main_sizer->AddSpacer(40);
        $self->main_sizer->Add($self->szr_send, 0, 0, 0);

		
        $self->btn_clear_inbox->SetFocus;
        $self->init_screen();

        return $self;
    }
    sub _build_ally_members {#{{{
        my $self = shift;

        my @members = sort{ uc $a->{name} cmp uc $b->{name} } @{$self->game_client->get_alliance_members('As an arrayref, please')};
        ### [
        ###     { id => 1, name => 'tmtowtdi'},
        ###     { id => 2, name => 'Infinate Ones'},
        ###     ...
        ###     { id => N, name => 'Last member'},
        ### ]
        return [ ({id => 0, name => '@ally'}, @members) ];
    }#}}}
    sub _build_btn_clear_inbox {#{{{
        my $self = shift;
        my $v = Wx::Button->new(
            $self, -1, 
            "Clear Selected Messages",
            wxDefaultPosition, 
            Wx::Size->new(200, 35)
        );
        return $v;
    }#}}}
    sub _build_btn_clear_to {#{{{
        my $self = shift;
        my $v = Wx::Button->new(
            $self, -1, 
            "Clear",
            wxDefaultPosition, 
            Wx::Size->new(50, $self->addy_height)
        );
        return $v;
    }#}}}
    sub _build_btn_send {#{{{
        my $self = shift;
        my $v = Wx::Button->new(
            $self, -1, 
            "Send Message",
            wxDefaultPosition, 
            Wx::Size->new(120, 40)
        );
        return $v;
    }#}}}
    sub _build_chk_alert {#{{{
        my $self = shift;
        return Wx::CheckBox->new(
            $self, -1, 
            'Alert',
            wxDefaultPosition, 
            Wx::Size->new(-1,-1), 
        );
    }#}}}
    sub _build_chc_ally {#{{{
        my $self = shift;

        my @allies = map{ $_->{'name'} }@{$self->ally_members};

        return Wx::Choice->new(
            $self, -1, 
            wxDefaultPosition, 
            Wx::Size->new(200, $self->addy_height), 
            \@allies,
        );
    }#}}}
    sub _build_chk_attacks {#{{{
        my $self = shift;
        return Wx::CheckBox->new(
            $self, -1, 
            'Attacks',
            wxDefaultPosition, 
            Wx::Size->new(-1,-1), 
        );
    }#}}}
    sub _build_chk_corr {#{{{
        my $self = shift;
        return Wx::CheckBox->new(
            $self, -1, 
            'Corresp.',
            wxDefaultPosition, 
            Wx::Size->new(-1,-1), 
        );
    }#}}}
    sub _build_chk_excav {#{{{
        my $self = shift;
        return Wx::CheckBox->new(
            $self, -1, 
            'Excavator',
            wxDefaultPosition, 
            Wx::Size->new(-1,-1), 
        );
    }#}}}
    sub _build_chk_parl {#{{{
        my $self = shift;
        return Wx::CheckBox->new(
            $self, -1, 
            'Parliament',
            wxDefaultPosition, 
            Wx::Size->new(-1,-1), 
        );
    }#}}}
    sub _build_chk_probe {#{{{
        my $self = shift;
        return Wx::CheckBox->new(
            $self, -1, 
            'Probe',
            wxDefaultPosition, 
            Wx::Size->new(-1,-1), 
        );
    }#}}}
    sub _build_chk_cust {#{{{
        my $self = shift;
        return Wx::CheckBox->new(
            $self, -1, 
            'Custom',
            wxDefaultPosition, 
            Wx::Size->new(-1,-1), 
        );
    }#}}}	
    sub _build_chk_read {#{{{
        my $self = shift;
        my $v = Wx::CheckBox->new(
            $self, -1, 
            'Only read',
            wxDefaultPosition, 
            Wx::Size->new(-1,-1), 
        );
        $v->SetValue(0);
        return $v;
    }#}}}
    sub _build_txt_cust {#{{{
        my $self = shift;
        my $v = Wx::TextCtrl->new(
            $self, -1, 
            q{},
            wxDefaultPosition, 
            Wx::Size->new(200, $self->addy_height)
        );
        $v->SetToolTip("Optional - choose the 'Custom' checkbox and type a subject here; all mails with that exact subject will be deleted regardless of tag.  Setting the Custom checkbox will override all other checkboxes.");
        return $v;
    }#}}}
    sub _build_inbox {#{{{
        my $self = shift;
        my $inbox = try {
            $self->game_client->inbox;
        }
        catch {
            my $msg = (ref $_) ? $_->text : $_;
            $self->poperr("GONNGG!  Unable to open your inbox: $msg");
        };
        return $inbox;
    }#}}}
    sub _build_lbl_ally {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self, -1, 
            "Allies: ",
            wxDefaultPosition, 
            Wx::Size->new(50, $self->addy_height)
        );
        $y->SetFont( $self->get_font('/bold_para_text_1') );
        return $y;
    }#}}}
    sub _build_lbl_body {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self, -1, 
            "Body: ",
            wxDefaultPosition, 
            Wx::Size->new(50, $self->addy_height)
        );
        $y->SetFont( $self->get_font('/bold_para_text_1') );
        return $y;
    }#}}}
    sub _build_lbl_btn_send {#{{{
        my $self = shift;
        ### This exists simply to move the 'Send Message' button directly under 
        ### the other inputs that have actual labels.  The button doesn't need 
        ### any string label, so this is essentially just a shim.
        my $y = Wx::StaticText->new(
            $self, -1, 
            q{},
            wxDefaultPosition, 
            Wx::Size->new(50, $self->addy_height)
        );
        $y->SetFont( $self->get_font('/bold_para_text_1') );
        return $y;
    }#}}}
    sub _build_lbl_instructions {#{{{
        my $self = shift;

        my $text = "This clears your mail and needs more instructions.  Lorem ipsumLorem ipsumLorem ipsumLorem ipsumLorem ipsumLorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum ";
        my $size = Wx::Size->new(-1, -1);

        my $y = Wx::StaticText->new(
            $self, -1, 
            $text,
            wxDefaultPosition, $size
        );
        $y->Wrap( $self->size->GetWidth - 35 ); # - 35 accounts for the vertical scrollbar
        $y->SetFont( $self->get_font('/bold_para_text_1') );

        return $y;
    }#}}}
    sub _build_lbl_hdr_clear {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self, -1, 
            "Clear Junk Mail",
            wxDefaultPosition, 
            Wx::Size->new(400, 30)
        );
        $y->SetFont( $self->get_font('/header_2') );
        return $y;
    }#}}}
    sub _build_lbl_hdr_page {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self, -1, 
            "Mail Tool",
            wxDefaultPosition, 
            Wx::Size->new(400, 35)
        );
        $y->SetFont( $self->get_font('/header_1') );
        return $y;
    }#}}}
    sub _build_lbl_hdr_send {#{{{
        my $self = shift;
        my $v = Wx::StaticText->new(
            $self, -1,
            "Intra-Alliance Mail",
            wxDefaultPosition, 
            Wx::Size->new(400, 30)
        );
        $v->SetFont( $self->get_font('/header_2') );
        $v->SetToolTip(
"Messages sent by this form are doing an end-run around the profanity filter.  Use your head."
        );
        return $v;
    }#}}}
    sub _build_lbl_subject {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self, -1, 
            "Subject: ",
            wxDefaultPosition, 
            Wx::Size->new(50, $self->addy_height)
        );
        $y->SetFont( $self->get_font('/bold_para_text_1') );
        return $y;
    }#}}}
    sub _build_lbl_to {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self, -1, 
            "To: ",
            wxDefaultPosition, 
            Wx::Size->new(50, $self->addy_height)
        );
        $y->SetFont( $self->get_font('/bold_para_text_1') );
        return $y;
    }#}}}
    sub _build_size {#{{{
        my $self = shift;
        my $s = Wx::Size->new(600, 700);
        return $s;
    }#}}}
    sub _build_szr_ally {#{{{
        my $self = shift;
        return $self->build_sizer($self, wxHORIZONTAL, 'Allies:');
    }#}}}
    sub _build_szr_body {#{{{
        my $self = shift;
        return $self->build_sizer($self, wxHORIZONTAL, 'Body:');
    }#}}}
    sub _build_szr_btn_send {#{{{
        my $self = shift;
        return $self->build_sizer($self, wxHORIZONTAL, 'Send Button');
    }#}}}
    sub _build_szr_clear {#{{{
        my $self = shift;
        return $self->build_sizer($self, wxVERTICAL, 'Clear Sizer');
    }#}}}
    sub _build_szr_cust {#{{{
        my $self = shift;
        return $self->build_sizer($self, wxHORIZONTAL, 'Custom Text Sizer');
    }#}}}	
    sub _build_szr_check {#{{{
        my $self = shift;
        return $self->build_sizer($self, wxHORIZONTAL, 'Checkbox Sizer');
    }#}}}
    sub _build_szr_header {#{{{
        my $self = shift;
        return $self->build_sizer($self, wxVERTICAL, 'Header Sizer');
    }#}}}
    sub _build_szr_instructions {#{{{
        my $self = shift;
        return $self->build_sizer($self, wxVERTICAL, 'Instructions Sizer');
    }#}}}
    sub _build_szr_send {#{{{
        my $self = shift;
        return $self->build_sizer($self, wxVERTICAL, 'Send Message Sizer');
    }#}}}
    sub _build_szr_subject {#{{{
        my $self = shift;
        return $self->build_sizer($self, wxHORIZONTAL, 'Subject:');
    }#}}}
    sub _build_szr_to {#{{{
        my $self = shift;
        return $self->build_sizer($self, wxHORIZONTAL, 'To:');
    }#}}}
    sub _build_title {#{{{
        my $self = shift;
        return 'Mail Tool';
    }#}}}
    sub _build_txt_body {#{{{
        my $self = shift;
        ### The 300 width wraps the body just a hair before the game's client 
        ### does.  So a 'line' typed in this text box should also be a line in 
        ### the game client.
        return Wx::TextCtrl->new(
            $self, -1, 
            q{},
            wxDefaultPosition, Wx::Size->new(300,300),
            wxTE_MULTILINE
        );
    }#}}}
    sub _build_txt_subject {#{{{
        my $self = shift;
        return Wx::TextCtrl->new(
            $self, -1, 
            q{},
            wxDefaultPosition, 
            Wx::Size->new(300, $self->addy_height)
        );
    }#}}}
    sub _build_txt_to {#{{{
        my $self = shift;
        return Wx::TextCtrl->new(
            $self, -1, 
            q{},
            wxDefaultPosition, 
            Wx::Size->new(300, $self->addy_height),
            wxTE_READONLY
        );
    }#}}}
    sub _set_events {#{{{
        my $self = shift;
        EVT_BUTTON(     $self, $self->btn_clear_inbox->GetId,   sub{$self->OnClearMail(@_)} );
        EVT_BUTTON(     $self, $self->btn_clear_to->GetId,      sub{$self->OnClearTo(@_)} );
        EVT_BUTTON(     $self, $self->btn_send->GetId,          sub{$self->OnSendMail(@_)} );
        EVT_CHECKBOX(   $self, $self->chk_corr->GetId,          sub{$self->OnCorrespondenceCheckbox(@_)} );
        EVT_CHOICE(     $self, $self->chc_ally->GetId,          sub{$self->OnAllyChoice(@_)} );
        EVT_CLOSE(      $self,                                  sub{$self->OnClose(@_)});
        return 1;
    }#}}}

    sub clear_mail_form {#{{{
        my $self = shift;
        $self->txt_to->SetValue(q{});
        $self->txt_subject->SetValue(q{});
        $self->txt_body->SetValue(q{});
        return 1;
    }#}}}
    sub fix_profanity {#{{{
        my $self = shift;
        my $body = shift;

=head2 fix_profanity

Accepts a chunk of text (multiline is fine) and checks it for profanity, 
determined by Regexp::Common's profanity filter, which is what the server is 
using to check for mail profanity.

Any profane words are passed through sacren(), which renders them non-profane, 
though they'll still display the same way.

NOTE
This should really only be used for in-alliance mail.  We don't want people to 
(eg) start F-bombing non alliance members with this.

=cut

        my @bad_lines = split /[\r\n]/, $body;
        my @good_lines = ();

        LINE:
        for my $line( @bad_lines ) {
            if( $RE{profanity}->matches($line) ) {
                my @bad_words = split /\s/, $line;
                my @good_words = ();

                WORD:
                foreach my $word(@bad_words) {
                    if( $RE{profanity}->matches($word) ) {
                        $word = $self->sacren($word);
                    }
                    push @good_words, $word;
                }

                $line = join q{ }, @good_words;
            }
            push @good_lines, $line;
        }

        $body = join qq{\n}, @good_lines;
        return $body;
    }#}}}
    sub sacren {#{{{
        my $self = shift;
        my $word = shift;

=pod

sacren
    Middle English
    To consecrate; to sanctify; to make holy

Accepts a string, assumed to be a profane word.  Inserts an ASCII 001 SOH (start 
of heading), which is non-printable, after the first letter of the word, 
transforming the word from profane to sacrosanct.  More or less.  Too bad Larry 
already used 'bless'.

=cut

        substr $word, 1, 0, chr(1);
        return $word;
    }#}}}
    sub trim {#{{{
        my $self = shift;
        my $str  = shift;
        $str =~ s/^\s+//;
        $str =~ s/\s+$//;
        return $str;
    }#}}}

    sub OnAllyChoice {#{{{
        my $self   = shift;

        my $name = $self->ally_members->[ $self->chc_ally->GetCurrentSelection ]->{'name'};
        my $to   = $self->txt_to->GetLineText(0);

        my $to_hash = {};
        for my $n( ((split /,/, $to), $name) ) {
            $to_hash->{$self->trim($n)}++;
        }

        if( defined $to_hash->{'@ally'} ) {
            ### Message is being sent to all.  No need to include individual 
            ### names on top of that.
            $to_hash = {'@ally' => 1};
        }

        my $to_out = join q{, }, sort keys %{$to_hash};
        $self->txt_to->SetValue($to_out);
        return 1;
    }#}}}
	
    sub _get_trash_messages {#{{{
        my $self            = shift;
		my $go_cust			= shift;
        my $tags_to_trash   = shift;
        my $status          = shift;
        my $trash_these     = [];

        my $created_own_status = 0;
        unless( $status ) {
            $created_own_status = 1;
            $status = LacunaWaX::Dialog::Status->new(
                app      => $self->app,
                ancestor => $self,
                title    => 'Clear Mail',
            );
            $status->show;
        }

        ### We always have to get the first page of messages, which will tell 
        ### us how many messages (and therefore pages) there are in total.
        $status->say("Reading page 01");
		
		#Add section for custom text handling
		my $scc_test 	= $go_cust; 
		my $scc_str		= $self->txt_cust->GetValue;
		
		if ($scc_test eq 'Y') {
			my $contents = try {
				$self->inbox->view_inbox({page_number => 1});
			}
			catch {
				my $msg = (ref $_) ? $_->text : $_;
				$self->poperr("Unable to get page 1: $msg");
				return;
			} or return;
			my $msg_count   = $contents->{'message_count'};
			my $msgs        = $contents->{'messages'};
			
			foreach my $m(@{$msgs}) {
				next if $self->chk_read->GetValue and not $m->{'has_read'};
				
				#print Dumper $m->{'subject'};
				
				if ($scc_str eq $m->{'subject'}) {
					#$status->say($m->{'subject'} . ' will be deleted');
					push @{$trash_these}, $m->{'id'};
				}
			}

			### Get subsequent pages if necessary.
			my $max_page = int($msg_count / 25);
			$max_page++ if $msg_count % 25;
			for my $page(2..$max_page) {    # already got page 1
				$status->say("Reading page $page");
				my $contents = try {
					$self->inbox->view_inbox({page_number => $page});
				}
				catch {
					my $msg = (ref $_) ? $_->text : $_;
					$self->poperr("Unable to get page $page: $msg");
					return;
				} or return;
				my $msgs = $contents->{'messages'};
				my $found_count = 0;
				foreach my $m(@{$msgs}) {
					next if $self->chk_read->GetValue and not $m->{'has_read'};
					if ($scc_str eq $m->{'subject'}) {
						#$status->say($m->{'subject'} . ' will be deleted');
						push @{$trash_these}, $m->{'id'};
					}
				}
			}

		} else {
			my $contents = try {
				$self->inbox->view_inbox({page_number => 1, tags => $tags_to_trash});
			}
			catch {
				my $msg = (ref $_) ? $_->text : $_;
				$self->poperr("Unable to get page 1: $msg");
				return;
			} or return;
			my $msg_count   = $contents->{'message_count'};
			my $msgs        = $contents->{'messages'};
			
			
			#print $msg_count;
			#print $m->{'subject'};
			
			foreach my $m(@{$msgs}) {
				next if $self->chk_read->GetValue and not $m->{'has_read'};
				
				#print Dumper $m;
				
				push @{$trash_these}, $m->{'id'};
			}

			### Get subsequent pages if necessary.
			my $max_page = int($msg_count / 25);
			$max_page++ if $msg_count % 25;
			for my $page(2..$max_page) {    # already got page 1
				$status->say("Reading page $page");
				my $contents = try {
					$self->inbox->view_inbox({page_number => $page, tags => $tags_to_trash});
				}
				catch {
					my $msg = (ref $_) ? $_->text : $_;
					$self->poperr("Unable to get page $page: $msg");
					return;
				} or return;
				my $msgs = $contents->{'messages'};
				my $found_count = 0;
				foreach my $m(@{$msgs}) {
					next if $self->chk_read->GetValue and not $m->{'has_read'};
					push @{$trash_these}, $m->{'id'};
				}
			}

		}
		
        if( $created_own_status ) {
            $status->close();
        }

        return $trash_these;
    }#}}}
    sub OnClearMail {#{{{
        my $self            = shift;
        my $dialog          = shift;
        my $event           = shift;
        my $tags_to_trash   = [];
		my $go_cust			= 'N';
		
        foreach my $checkbox( $self->chk_alert, $self->chk_attacks, $self->chk_corr, $self->chk_excav, $self->chk_parl, $self->chk_probe,  $self->chk_cust) {
			if ($checkbox->GetLabel eq 'Custom' and $checkbox->GetValue) {
				#say($checkbox->GetLabel);
				#say($checkbox->GetValue);
				$go_cust = 'Y';
				last;
			} else {
				push @{$tags_to_trash}, $checkbox->GetLabel if $checkbox->GetValue;
			}
        }
		
		if ($go_cust ne 'Y') {
		
			unless( @{$tags_to_trash} ) {
				$self->poperr(
					"I should remove nothing?  You got it.",
					"No checkboxes checked",
				);
				$self->btn_clear_inbox->SetFocus;
				return;
			}
		}
		
		
		#say('Cust Val : ' . $go_cust);

        my $status = LacunaWaX::Dialog::Status->new(
            app      => $self->app,
            ancestor => $self,
            title    => 'Clear Mail',
        );
        $status->show;


        my $trash_these = $self->_get_trash_messages($go_cust, $tags_to_trash, $status);

		#SCC:
		#print Dumper $trash_these;
		
		
        $status->say("Deleting selected messages");
        my $rv = try {
            $self->inbox->trash_messages($trash_these);
        }
        catch {
            my $msg = (ref $_) ? $_->text : $_;
            $self->poperr("Unable to delete messages: $msg");
            return;
        } or return;
        my $trashed     = scalar @{$rv->{'success'}} || 0;
        my $not_trashed = scalar @{$rv->{'failure'}} || 0;

        my $t_pl  = ($trashed == 1) ? q{ was} : q{s were};
        my $nt_pl = ($not_trashed == 1) ? q{} : q{s};
        my $msg  = "$trashed message${t_pl} moved to the trash.";
           $msg .= "\n\n$not_trashed message${nt_pl} could not be moved to the trash." if $not_trashed;
        $status->say($msg);
        $status->say_recsep;
        $status->say("Mail clearing complete.");
        return 1;
    }#}}}
	
    sub OnClearTo {#{{{
        my $self = shift;
        $self->txt_to->SetValue(q{});
        return 1;
    }#}}}
    sub OnClose {#{{{
        my($self, $dialog, $event) = @_;
        $self->Destroy;
        $event->Skip();
        return 1;
    }#}}}
    sub OnCorrespondenceCheckbox {#{{{
        my $self = shift;
        if( $self->chk_corr->IsChecked ) {
            unless( wxYES == $self->popconf("You're about to delete mail sent by other players!  Are you sure?") ) {
                $self->chk_corr->SetValue(0);
            }
        }
        return 1;
    }#}}}
    sub OnSendMail {#{{{
        my $self   = shift;

        my $to   = $self->txt_to->GetLineText(0);
        my $subj = $self->txt_subject->GetLineText(0) || 'No subject';
        my $body = $self->txt_body->GetValue;
        $body = $self->fix_profanity($body);

        unless( $to and $subj and $body ) {
            $self->poperr("The To and Body fields must not be blank.  Try again.");
            return;
        }

        my $rv = try { $self->inbox->send_message( $to, $subj, $body ) };
        if( ref $rv eq 'HASH' ) {
            $self->popmsg("Your message has been sent.");
            $self->clear_mail_form;
        }
        else {
            $self->poperr("Unknown error sending message.");
        }
        return 1;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;
