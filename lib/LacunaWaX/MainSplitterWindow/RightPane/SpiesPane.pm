
package LacunaWaX::MainSplitterWindow::RightPane::SpiesPane {
    use v5.14;
    use LacunaWaX::Model::Client;
    use Moose;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_CHOICE EVT_BUTTON);
    with 'LacunaWaX::Roles::MainSplitterWindow::RightPane';

    use LacunaWaX::MainSplitterWindow::RightPane::SpiesPane::SpyRow;
    use LacunaWaX::MainSplitterWindow::RightPane::SpiesPane::BatchRenameForm;

    has 'sizer_debug'   => (is => 'rw', isa => 'Int', lazy => 1, default => 0);

    has 'planet_name'   => (is => 'rw', isa => 'Str',                   required => 1   );
    has 'planet_id'     => (is => 'rw', isa => 'Int', lazy_build => 1                   );

    has 'int_min' => (is => 'rw', isa => 'Maybe[Games::Lacuna::Client::Buildings::Intelligence]', lazy_build => 1);

    has 'stop_renaming' => (is => 'rw', isa => 'Int', lazy => 1, default => 0,
        documentation => q{
            If the user closes the status window, this will be set to True, in which 
            case the renaming loop will quit.
        }
    );

    has 'screen_width'  => (is => 'rw', isa => 'Int', lazy => 1, default => 640 );

    has 'dialog_status' => (is => 'rw', isa => 'LacunaWaX::Dialog::Status', lazy_build => 1);

    has 'width_chc'  => (is => 'rw', isa => 'Int', lazy => 1, default => 80     );
    has 'height_chc' => (is => 'rw', isa => 'Int', lazy => 1, default => 25     );
    has 'text_none'  => (is => 'rw', isa => 'Str', lazy => 1, default => 'None' );

    has 'szr_buttons'  => (is => 'rw', isa => 'Wx::BoxSizer',  lazy_build => 1, documentation => 'horizontal');
    has 'szr_header'   => (is => 'rw', isa => 'Wx::BoxSizer',  lazy_build => 1, documentation => 'vertical');
    has 'szr_train'    => (is => 'rw', isa => 'Wx::BoxSizer',  lazy_build => 1, documentation => 'horizontal');
    has 'szr_batch'    => (is => 'rw', isa => 'Wx::BoxSizer',  lazy_build => 1, documentation => 'horizontal');

    has 'szr_bottom_center'   => (is => 'rw', isa => 'Wx::BoxSizer',  lazy_build => 1, documentation => 'horizontal');
    has 'szr_bottom_right'    => (is => 'rw', isa => 'Wx::BoxSizer',  lazy_build => 1, documentation => 'vertical'  );
    has 'szr_batch_center'    => (is => 'rw', isa => 'Wx::BoxSizer',  lazy_build => 1, documentation => 'horizontal');

    has 'lbl_header'                => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'lbl_instructions_box'      => (is => 'rw', isa => 'Wx::BoxSizer',      lazy_build => 1);
    has 'lbl_instructions'          => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'lbl_save_button_reminder'  => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);

    has 'lbl_train_1'       => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'lbl_train_2'       => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'lbl_train_3'       => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'lbl_train_4'       => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'chc_train_1'       => (is => 'rw', isa => 'Wx::Choice',        lazy_build => 1);
    has 'chc_train_2'       => (is => 'rw', isa => 'Wx::Choice',        lazy_build => 1);
    has 'chc_train_3'       => (is => 'rw', isa => 'Wx::Choice',        lazy_build => 1);
    has 'chc_train_4'       => (is => 'rw', isa => 'Wx::Choice',        lazy_build => 1);
    has 'btn_clear'         => (is => 'rw', isa => 'Wx::Button',        lazy_build => 1);
    has 'btn_rename'        => (is => 'rw', isa => 'Wx::Button',        lazy_build => 1);
    has 'btn_save'          => (is => 'rw', isa => 'Wx::Button',        lazy_build => 1);

    has 'spy_table' => (is => 'rw', isa => 'ArrayRef', lazy => 1, default => sub{[]});
    has 'batch_form' => (
        is          => 'rw',
        isa         => 'LacunaWaX::MainSplitterWindow::RightPane::SpiesPane::BatchRenameForm',
        lazy_build  => 1,
    );

    sub BUILD {
        my $self = shift;

        return unless $self->int_min_exists_here;

        $self->szr_header->Add($self->lbl_header, 0, 0, 0);
        $self->szr_header->AddSpacer(5);
        $self->szr_header->Add($self->lbl_save_button_reminder, 0, 0, 0);
        $self->szr_header->Add($self->lbl_instructions_box, 0, 0, 0);
        $self->content_sizer->Add($self->szr_header, 0, 0, 0);
        $self->content_sizer->AddSpacer(20);

        $self->szr_train->Add($self->lbl_train_1, 0, 0, 0);
        $self->szr_train->Add($self->chc_train_1, 0, 0, 0);
        $self->szr_train->AddSpacer(5);
        $self->szr_train->Add($self->lbl_train_2, 0, 0, 0);
        $self->szr_train->Add($self->chc_train_2, 0, 0, 0);
        $self->szr_train->AddSpacer(5);
        $self->szr_train->Add($self->lbl_train_3, 0, 0, 0);
        $self->szr_train->Add($self->chc_train_3, 0, 0, 0);
        $self->szr_train->AddSpacer(5);
        $self->szr_train->Add($self->lbl_train_4, 0, 0, 0);
        $self->szr_train->Add($self->chc_train_4, 0, 0, 0);
        $self->szr_train->AddSpacer(5);
        $self->szr_train->Add($self->btn_clear, 0, 0, 0);
        $self->content_sizer->Add($self->szr_train, 0, 0, 0);
        $self->content_sizer->AddSpacer(10);

        my $spies = try {
            $self->app->game_client->get_spies($self->planet_id);
        }
        catch {
            my $msg = (ref $_) ? $_->text : $_;
            $self->app->poperr($msg);
            return;
        };
        $spies or return;

        ### Spy list header
        my $header = LacunaWaX::MainSplitterWindow::RightPane::SpiesPane::SpyRow->new(
            app         => $self->app,
            ancestor    => $self,
            parent      => $self->parent,
            is_header   => 1,
        );
        $self->content_sizer->Add($header->szr_main, 0, 0, 0);
        $self->content_sizer->AddSpacer(5);

        ### Actual spy list
        foreach my $hr( @{$spies} ) {
            $self->app->Yield;
            my $spy = LacunaWaX::Model::Client::Spy->new(hr => $hr);
            my $row = LacunaWaX::MainSplitterWindow::RightPane::SpiesPane::SpyRow->new(
                app         => $self->app,
                ancestor    => $self,
                parent      => $self->parent,
                spy         => $spy,
            );
            push @{ $self->spy_table }, $row;
            $self->content_sizer->Add($row->szr_main, 0, 0, 0);
            $self->content_sizer->AddSpacer(5);

            unless( scalar @{$self->spy_table} % 20 ) {
                ### Add another header every 20 rows
                my $header = LacunaWaX::MainSplitterWindow::RightPane::SpiesPane::SpyRow->new(
                    app         => $self->app,
                    ancestor    => $self,
                    parent      => $self->parent,
                    is_header   => 1,
                );
                $self->content_sizer->Add($header->szr_main, 0, 0, 0);
                $self->content_sizer->AddSpacer(5);
            }
        }

        $self->szr_buttons->Add($self->btn_save, 0, 0, 0);
        $self->szr_buttons->AddSpacer(10);
        $self->szr_buttons->Add($self->btn_rename, 0, 0, 0);

=head2 BOTTOM SIZERS {#{{{

The buttons and batch rename form at the bottom of the screen have a somewhat 
complicated sizer setup in an effort to keep those sets of items MorL centered.

The setup described below appears inside the Content Sizer after the list of 
spies.

If you need to fiddle these sizers at all, please turn on sizer_debug so you can 
see what you're doing.

=begin rawtext

                                                                                                  
 ___ Bottom Centering ______________________________________________________                                                                                               
|                                                                           |                     
|                 __ Bottom Right _________________________________________ |                     
|                | __ Bottom Buttons _____________________________________ ||                     
|                ||                                                       |||                     
|                ||   SAVE SPY ASSIGNMENTS      RENAME SPIES              |||                     
|                ||                                                       |||                     
|                ||                                                       |||                     
|                ||_______________________________________________________|||                     
|      S         |                                                         ||                     
|      P         |            SPACER                                       ||                     
|      A         |                                                         ||                     
|      C         | __ Batch Centering ______________________________       ||                     
|      E         ||            __ Batch Rename ____________________ |      ||                     
|      R         ||           |                                    ||      ||                     
|                ||     S     |   NEW NAME TEXT BOX                ||      ||                     
|                ||     P     |                                    ||      ||                     
|                ||     A     |                                    ||      ||                     
|                ||     C     |   PRE- SUF- FIX RADIO BOX          ||      ||                     
|                ||     E     |                                    ||      ||                     
|                ||     R     |                                    ||      ||                     
|                ||           |____________________________________||      ||                     
|                ||_________________________________________________|      ||                     
|                |_________________________________________________________||                     
|___________________________________________________________________________|                                                                                            

=end rawtext

=cut # }#}}}

        $self->szr_batch_center->AddSpacer(50);
        $self->szr_batch_center->Add($self->batch_form->szr_main, 0, 0, 0); # probably needs to be in another horiz sizer with a spacer first

        $self->szr_bottom_right->Add($self->szr_buttons, 0, 0, 0);
        $self->szr_bottom_right->AddSpacer(40);
        $self->szr_bottom_right->Add($self->szr_batch_center, 0, 0, 0);
        $self->szr_bottom_right->AddSpacer(40);

        $self->szr_bottom_center->AddSpacer(160);
        $self->szr_bottom_center->Add($self->szr_bottom_right, 0, 0, 0);

        $self->content_sizer->AddSpacer(10);
        $self->content_sizer->Add($self->szr_bottom_center, 0, 0, 0);

        $self->lbl_header->SetFocus();  # make sure we're scrolled to the top

        return $self;
    }
    sub _build_batch_form {#{{{
        my $self = shift;
        return LacunaWaX::MainSplitterWindow::RightPane::SpiesPane::BatchRenameForm->new(
            app         => $self->app,
            ancestor    => $self,
            parent      => $self->parent,
        );
    }#}}}
    sub _build_btn_clear {#{{{
        my $self = shift;
        my $v = Wx::Button->new($self->parent, -1, "Clear Spy Assignments");
        $v->SetFont($self->app->wxbb->resolve(service => '/Fonts/para_text_2'));
        return $v;
    }#}}}
    sub _build_btn_rename {#{{{
        my $self = shift;
        my $v = Wx::Button->new($self->parent, -1, "Rename Spies");
        $v->SetFont($self->app->wxbb->resolve(service => '/Fonts/para_text_2'));
        return $v;
    }#}}}
    sub _build_btn_save {#{{{
        my $self = shift;
        my $v = Wx::Button->new($self->parent, -1, "Save Spy Assignments");
        $v->SetFont($self->app->wxbb->resolve(service => '/Fonts/para_text_2'));
        return $v;
    }#}}}
    sub _build_chc_train_1 {#{{{
        my $self = shift;
        my $v = Wx::Choice->new(
            $self->parent, -1, 
            wxDefaultPosition, 
            Wx::Size->new($self->width_chc, $self->height_chc), 
            [$self->text_none, @{$self->app->game_client->spy_training_choices}],
        );
        $v->SetSelection(0);
        $v->SetFont($self->app->wxbb->resolve(service => '/Fonts/para_text_2'));
        return $v;
    }#}}}
    sub _build_chc_train_2 {#{{{
        my $self = shift;
        my $v = Wx::Choice->new(
            $self->parent, -1, 
            wxDefaultPosition, 
            Wx::Size->new($self->width_chc, $self->height_chc), 
            [$self->text_none, @{$self->app->game_client->spy_training_choices}],
        );
        $v->SetSelection(0);
        $v->SetFont($self->app->wxbb->resolve(service => '/Fonts/para_text_2'));
        return $v;
    }#}}}
    sub _build_chc_train_3 {#{{{
        my $self = shift;
        my $v = Wx::Choice->new(
            $self->parent, -1, 
            wxDefaultPosition, 
            Wx::Size->new($self->width_chc, $self->height_chc), 
            [$self->text_none, @{$self->app->game_client->spy_training_choices}],
        );
        $v->SetSelection(0);
        $v->SetFont($self->app->wxbb->resolve(service => '/Fonts/para_text_2'));
        return $v;
    }#}}}
    sub _build_chc_train_4 {#{{{
        my $self = shift;
        my $v = Wx::Choice->new(
            $self->parent, -1, 
            wxDefaultPosition, 
            Wx::Size->new($self->width_chc, $self->height_chc), 
            [$self->text_none, @{$self->app->game_client->spy_training_choices}],
        );
        $v->SetSelection(0);
        $v->SetFont($self->app->wxbb->resolve(service => '/Fonts/para_text_2'));
        return $v;
    }#}}}
    sub _build_dialog_status {#{{{
        my $self = shift;

        my $v = LacunaWaX::Dialog::Status->new( 
            app         => $self->app,
            ancestor    => $self,
            title       => 'Rename Spies',
            recsep      => '-=-=-=-=-=-=-',
        );
        $v->hide;
        return $v;
    }#}}}
    sub _build_int_min {#{{{
        my $self = shift;
        my $im = try {
            $self->app->game_client->get_building($self->planet_id, 'Intelligence Ministry');
        }
        catch {
            my $msg = (ref $_) ? $_->text : $_;
            $self->app->poperr($msg);
            return;
        };

        return( $im and ref $im eq 'Games::Lacuna::Client::Buildings::Intelligence' ) ? $im : undef;
    }#}}}
    sub _build_lbl_train_1 {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self->parent, -1, 
            '1st: ',
            wxDefaultPosition, 
            Wx::Size->new(25, 40)
        );
        $y->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_1') );
        return $y;
    }#}}}
    sub _build_lbl_train_2 {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self->parent, -1, 
            '2nd: ',
            wxDefaultPosition, 
            Wx::Size->new(25, 40)
        );
        $y->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_1') );
        return $y;
    }#}}}
    sub _build_lbl_train_3 {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self->parent, -1, 
            '3rd: ',
            wxDefaultPosition, 
            Wx::Size->new(25, 40)
        );
        $y->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_1') );
        return $y;
    }#}}}
    sub _build_lbl_train_4 {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self->parent, -1, 
            '4th: ',
            wxDefaultPosition, 
            Wx::Size->new(25, 40)
        );
        $y->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_1') );
        return $y;
    }#}}}
    sub _build_lbl_header {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self->parent, -1, 
            "Spies on " . $self->planet_name, 
            wxDefaultPosition, 
            Wx::Size->new($self->screen_width, 40)
        );
        $y->SetFont( $self->app->wxbb->resolve(service => '/Fonts/header_1') );
        return $y;
    }#}}}
    sub _build_lbl_save_button_reminder {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self->parent, -1, 
            "Don't forget to click the Save button at the bottom when you're finished.",
            wxDefaultPosition, 
            Wx::Size->new($self->screen_width, 28)
        );
        $y->SetFont( $self->app->wxbb->resolve(service => '/Fonts/bold_para_text_2') );
        $y->SetForegroundColour( Wx::Colour->new(255,0,0) );    # Not 'color'.  Silly brits.
        return $y;
    }#}}}
    sub _build_lbl_instructions {#{{{
        my $self = shift;

        my $text = "    The four dropdown boxes ('1st' - '4th') are just a convenience feature to help you with assigning tasks to your spies.  Without them, you'd have to individually assign up to 90 spies per planet.  When you chose a skill from one of those four dropdown boxes, that skill will be assigned to every spy who:

            1) Currently has no assignment ('None')
                                   AND
            2) Is below the max score (2600) for the skill you just chose.

    So assume you want this planet's spies to specialize first in Intel.  If any of them already have max Intel, you want them to instead train in Poli.  Chose Intel in the 1st box.  The spies who already have max Intel will remain unassigned, but everybody else will get assigned to Intel.  Next, choose Poli from the 2nd box, and the spies who had max Intel, and are therefore still assigned to None, will get assigned to Poli (unless they also already have max Poli).  etc.
    The switch from Intel training to Poli training will _not_ be automatic.  So you'll need to come back here periodically to re-assign any spies who were set to train in Intel, but who have maxed that out, to now train in Poli.  
    
    You can rename spies individually by clicking their name and then typing the desired new name, then clicking the Rename Spies button under the list of spies.  Or, you can use the Batch Rename form at the very bottom of the screen to rename all of your spies at once.
    ";

        my $y = Wx::StaticText->new(
            $self->parent, -1, 
            $text,
            wxDefaultPosition, 
            Wx::Size->new(-1, 370)
        );
        $y->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_2') );
        $y->Wrap($self->screen_width);

        return $y;
    }#}}}
    sub _build_lbl_instructions_box {#{{{
        my $self = shift;
        my $y = Wx::BoxSizer->new(wxHORIZONTAL);
        $y->Add($self->lbl_instructions, 0, 0, 0);
        return $y;
    }#}}}
    sub _build_planet_id {#{{{
        my $self = shift;
        return $self->app->game_client->planet_id( $self->planet_name );
    }#}}}
    sub _build_szr_batch {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxHORIZONTAL, 'Batch Spy Rename');
    }#}}}
    sub _build_szr_batch_center {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxHORIZONTAL, 'Batch Centering');
    }#}}}
    sub _build_szr_bottom_center {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxHORIZONTAL, 'Bottom Centering');
    }#}}}
    sub _build_szr_bottom_right {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxVERTICAL, 'Bottom Right');
    }#}}}
    sub _build_szr_buttons {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxHORIZONTAL, 'Bottom Buttons');
    }#}}}
    sub _build_szr_header {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxVERTICAL, 'Header');
    }#}}}
    sub _build_szr_train {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxHORIZONTAL, 'Training');
    }#}}}

    sub _set_events {#{{{
        my $self = shift;
        EVT_CHOICE( $self->parent, $self->chc_train_1->GetId,   sub{$self->OnAllTrainChoice($self->chc_train_1,@_)} );
        EVT_CHOICE( $self->parent, $self->chc_train_2->GetId,   sub{$self->OnAllTrainChoice($self->chc_train_2,@_)} );
        EVT_CHOICE( $self->parent, $self->chc_train_3->GetId,   sub{$self->OnAllTrainChoice($self->chc_train_3,@_)} );
        EVT_CHOICE( $self->parent, $self->chc_train_4->GetId,   sub{$self->OnAllTrainChoice($self->chc_train_4,@_)} );
        EVT_BUTTON( $self->parent, $self->btn_clear->GetId,     sub{$self->OnClearButton(@_)}   );
        EVT_BUTTON( $self->parent, $self->btn_rename->GetId,    sub{$self->OnRenameButton(@_)}    );
        EVT_BUTTON( $self->parent, $self->btn_save->GetId,      sub{$self->OnSaveButton(@_)}    );

        ### When the user clicks on the instructions text at the top of the 
        ### screen, this will cause that text to gain focus, thereby enabling 
        ### the user's mousewheel to scroll the long spies list as they'd 
        ### expect.
        $self->lbl_instructions->Connect(
            $self->lbl_instructions->GetId,
            wxID_ANY,
            wxEVT_LEFT_DOWN,
            sub{$self->OnStaticTextClick(@_)},
        );

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

    sub OnAllTrainChoice {#{{{
        my $self    = shift;
        my $choice  = shift;  # $self->chc_train_ 1, 2, 3, or 4
        my $panel   = shift;  # Wx::ScrolledWindow
        my $event   = shift;  # Wx::CommandEvent

        my $chosen_training_idx = $choice->GetSelection;
        my $chosen_training_str = lc $choice->GetString( $chosen_training_idx );

        ROW:
        foreach my $row( @{$self->spy_table} ) {
            my $spy = $row->spy;

            if( $chosen_training_str =~ /none/ ) {
                $row->chc_train->SetSelection(0);
                next ROW;
            }

            if( $spy->$chosen_training_str < 2600 ) {
                if( $row->chc_train->GetString($row->chc_train->GetSelection) eq $self->text_none ) {
                    $row->chc_train->SetSelection($chosen_training_idx);
                }
            }
        }
        return 1;
    }#}}}
    sub OnClearButton {#{{{
        my $self    = shift;
        my $panel   = shift;    # Wx::ScrolledWindow
        my $event   = shift;    # Wx::CommandEvent

        $self->app->throb();
        my $schema = $self->app->bb->resolve( service => '/Database/schema' );

        foreach my $row( @{$self->spy_table} ) {
            $self->app->Yield;
            my $selection = $row->chc_train->FindString( $row->text_none );
            $row->chc_train->SetSelection( $selection );
        }
        $self->app->endthrob();
        return 1;
    }#}}}
    sub OnRenameButton {#{{{
        my $self    = shift;
        my $panel   = shift;    # Wx::ScrolledWindow
        my $event   = shift;    # Wx::CommandEvent

        $self->dialog_status->erase;
        $self->dialog_status->show;
        $self->app->Yield;

        my $cnt = 0;
        SPY_ROW:
        foreach my $row( @{$self->spy_table} ) {
            next SPY_ROW if( $row->new_name and $row->new_name eq $row->spy->name );

            if( $self->stop_renaming ) {
                ### User closed the status dialog box, so get out.
                $self->stop_renaming(0);
                last SPY_ROW;
            }

            $self->dialog_status_say("Renaming " . $row->spy->name . " to " . $row->new_name);
            my $rv = try {
                $self->int_min->name_spy($row->spy->id, $row->new_name);
            }
            catch {
                my $msg = (ref $_) ? $_->text : $_;
                $self->app->poperr($msg);
                $self->clear_dialog_status;
                return;
            };
            if( $rv ) {
                $row->change_name( $row->new_name );
                $cnt++;
            }
            $self->app->Yield;
        }

        $self->dialog_status->close;
        $self->clear_dialog_status;

        if( $cnt >= 1 ) {
            ### Spies have been renamed, so expire the spies currently in the 
            ### cache so the new names show up on the next screen load.
            if( $self->app->wxbb ) {
                my $chi  = $self->app->wxbb->resolve( service => '/Cache/raw_memory' );
                my $key  = join q{:}, ('BODIES', 'SPIES', $self->planet_id);
                $chi->remove($key);
            }
        }

        $self->app->popmsg(
            "$cnt spies have been renamed.",
            "Success!"
        );
        return 1;
    }#}}}
    sub OnSaveButton {#{{{
        my $self    = shift;
        my $panel   = shift;    # Wx::ScrolledWindow
        my $event   = shift;    # Wx::CommandEvent

        $self->app->throb();
        my $schema = $self->app->bb->resolve( service => '/Database/schema' );
        foreach my $row( @{$self->spy_table} ) {
            $self->app->Yield;
            my $spy = $row->spy;
            my $chosen_training_str = lc $row->chc_train->GetString( $row->chc_train->GetSelection );
            my $rec = $schema->resultset('SpyTrainPrefs')->find_or_create({
                spy_id => $spy->id, 
                server_id => $self->app->server->id
            });
            $rec->train( $chosen_training_str );
            $rec->update;
        }
        $self->app->endthrob();

        $self->app->popmsg(
            "Your spy training preferences have been saved.",
            "Success!"
        );
        return 1;
    }#}}}
    sub OnStaticTextClick {#{{{
        my $self   = shift;
        my $lbl    = shift;    # Wx::StaticText
        my $event  = shift;    # Wx::MouseEvent

        $lbl->SetFocus();
        return 1;
    }#}}}
    sub OnDialogStatusClose {#{{{
        my $self    = shift;
        my $status  = shift;    # LacunaWaX::Dialog::Status

        ### This is not a true event.  It gets called explicitly by 
        ### Dialog::Status's OnClose event.
        $self->clear_dialog_status;
        $self->stop_renaming(1);
        return 1;
    }#}}}

    sub int_min_exists_here {#{{{
        my $self = shift;

        ### Calls int_min's lazy builder, which returns undef if no int_min
        my $v = $self->int_min;

        ### Yeah, we could just test if $v is undef.  Calling the 
        ### auto-generated has_int_min() is just more Moosey.
        return unless $self->has_int_min;
        return 1;
    };#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;
