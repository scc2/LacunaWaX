
package LacunaWaX::Dialog::SitterManager {
    use v5.14;
    use Moose;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_BUTTON EVT_CLOSE);
    use LacunaWaX::Dialog::Scrolled;
    extends 'LacunaWaX::Dialog::Scrolled';

    use LacunaWaX::Dialog::SitterManager::SitterRow;

    has 'sizer_debug' => (is => 'rw', isa => 'Int',  lazy => 1, default => 0);

    has 'row_spacer_size'           => (is => 'rw', isa => 'Int',               lazy_build => 1                                 );
    has 'instructions_sizer'        => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1                                 );
    has 'add_sitter_button_sizer'   => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => 'horizontal'  );
    has 'header_sizer'              => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => 'vertical'    );
    has 'sitters_sizer'             => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => 'vertical'    );
    has 'lbl_header'                => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1                                 );
    has 'lbl_instructions'          => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1                                 );
    has 'btn_add_sitter'            => (is => 'rw', isa => 'Wx::Button',        lazy_build => 1                                 );

    sub BUILD {
        my $self = shift;
    
        $self->SetTitle( $self->title );
        $self->SetSize( $self->size );

        $self->header_sizer->Add($self->lbl_header, 0, 0, 0);
        $self->header_sizer->AddSpacer(10);
        $self->header_sizer->Add($self->instructions_sizer, 0, 0, 0);
        $self->header_sizer->AddSpacer(10);

        $self->main_sizer->AddSpacer(4);    # a little top margin
        $self->main_sizer->Add($self->header_sizer, 0, 0, 0);
        $self->main_sizer->AddSpacer(15);

        $self->fill_sitters_sizer();
        $self->main_sizer->Add($self->sitters_sizer, 0, 0, 0);

        $self->lbl_header->SetFocus();
        $self->init_screen();

        return $self;
    };
    sub _build_add_sitter_button_sizer {#{{{
        my $self = shift;

        my $v = $self->build_sizer($self->swindow, wxHORIZONTAL, 'Sitter Sizer');
        $v->AddSpacer(30);
        $v->Add($self->btn_add_sitter, 0, 0, 0);

        return $v;
    }#}}}
    sub _build_btn_add_sitter {#{{{
        my $self = shift;
        my $y = Wx::Button->new(
            $self->swindow, -1, 
            "Add New Sitter",
            wxDefaultPosition, 
            Wx::Size->new(400, 35)
        );
        return $y;
    }#}}}
    sub _build_header_sizer {#{{{
        my $self = shift;
        my $v = $self->build_sizer($self->swindow, wxVERTICAL, 'Header Sizer');
        return $v;
    }#}}}
    sub _build_lbl_header {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self->swindow, -1, 
            "Sitter Password Manager",
            wxDefaultPosition, 
            Wx::Size->new(400, 35)
        );
        $y->SetFont( $self->get_font('/header_1') );
        return $y;
    }#}}}
    sub _build_lbl_instructions {#{{{
        my $self = shift;

        my $text = "Your alliance leader should have your sitter.  Other than your alliance leader, only give your sitter out to players you trust.";
        my $size = Wx::Size->new(-1, -1);

        my $y = Wx::StaticText->new(
            $self->swindow, -1, 
            $text,
            wxDefaultPosition, $size
        );
        $y->Wrap( $self->size->GetWidth - 100 ); # - 255 accounts for the vertical scrollbar
        $y->SetFont( $self->get_font('/para_text_1') );

        return $y;
    }#}}}
    sub _build_instructions_sizer {#{{{
        my $self = shift;
        my $v = $self->build_sizer($self->swindow, wxHORIZONTAL, 'Instructions');
        $v->Add($self->lbl_instructions, 0, 0, 0);
        return $v;
    }#}}}
    sub _build_row_spacer_size {#{{{
        ### Pixel size of the space between rows
        return 1;
    }#}}}
    sub _build_sitters_sizer {#{{{
        my $self = shift;
        my $y = Wx::BoxSizer->new(wxVERTICAL);
        return $y;
    }#}}}
    sub _build_size {#{{{
        my $self = shift;
        ### 700 px high allows for 18 saved sitters.  Past 18, the screen will 
        ### need to be scrolled down to get to the button.
        my $s = wxDefaultSize;
        $s->SetWidth(600);
        $s->SetHeight(700);
        return $s;
    }#}}}
    sub _build_title {#{{{
        my $self = shift;
        return 'Sitter Manager';
    }#}}}
    sub _set_events {#{{{
        my $self = shift;
        EVT_CLOSE(  $self,                                          sub{$self->OnClose(@_)}     );
        EVT_BUTTON( $self->swindow, $self->btn_add_sitter->GetId,   sub{$self->OnAddSitter(@_)} );
        return 1;
    }#}}}

    sub fill_sitters_sizer {#{{{
        my $self = shift;

        my $schema = $self->get_main_schema;

        my $header = LacunaWaX::Dialog::SitterManager::SitterRow->new(
            app         => $self->app,
            ancestor    => $self,
            parent      => $self->swindow,
            is_header   => 1,
        );
        $self->sitters_sizer->Add($header->main_sizer, 0, 0, 0);
        $header->show;

        my $rs = $schema->resultset('SitterPasswords')->search(
            { server_id => $self->get_connected_server->id },
            ### LOWER(arg) works with SQLite.  May not work with another RDBMS.
            { order_by => { -asc => 'LOWER(player_name)' }, }
        );

        my $prev_row = undef;
        while(my $rec = $rs->next) {
            my $row = LacunaWaX::Dialog::SitterManager::SitterRow->new(
                app         => $self->app,
                ancestor    => $self,
                parent      => $self->swindow,
                player_rec  => $rec,
            );
            $self->sitters_sizer->Add($row->main_sizer, 0, 0, 0);
            $self->sitters_sizer->AddSpacer( $self->row_spacer_size );
            $self->yield;
            $row->show;

            if( $prev_row ) {
                $row->txt_name->MoveAfterInTabOrder($prev_row->btn_test);
            }

            $prev_row = $row;
        }

        ### Blank row to add new player info
        my $row = LacunaWaX::Dialog::SitterManager::SitterRow->new(
            app         => $self->app,
            ancestor    => $self,
            parent      => $self->swindow,
        );
        $self->sitters_sizer->Add($row->main_sizer, 0, 0, 0);
        $self->sitters_sizer->AddSpacer( $self->row_spacer_size );
        $row->show;

        $self->sitters_sizer->AddSpacer(5);
        $self->sitters_sizer->Add($self->add_sitter_button_sizer, 0, 0, 0);
        return 1;
    }#}}}

    sub OnAddSitter {#{{{
        my $self    = shift;
        my $dialog  = shift;    # Wx::ScrolledWindow
        my $event   = shift;    # Wx::CommandEvent

        my $row = LacunaWaX::Dialog::SitterManager::SitterRow->new(
            app         => $self->app,
            ancestor    => $self,
            parent      => $self->swindow,
        );
        
        ### We're going to insert a new, blank row into our sitter_sizer, but 
        ### need to know where to insert that row.
        ### 
        ### We don't know how many sitter rows already exist in our sizer in 
        ### total, but we do know how many items exist in the sizer after the 
        ### final row.
        ###
        ### Following the final SitterRow is:
        ###     - Horizontal spacer (appears after each row)
        ###     - Larger horizontal spacer (separates Sitter inputs from "Add New Row" sizer)
        ###     - "Add New Row" button sizer
        ###
        ### ...so we subtract 3 from $count.
        my @children = $self->sitters_sizer->GetChildren;
        my $count = scalar @children;
        $self->sitters_sizer->Insert( ($count - 3), $row->main_sizer );
        $self->sitters_sizer->InsertSpacer( ($count - 3), $self->row_spacer_size );
        $row->txt_name->SetFocus;

        $row->show;
        $self->swindow->FitInside();
        $self->Fit();
        $self->parent->Layout;

        ### On Windows XP (at least), adding a new row is leaving a very slight 
        ### artifact on the bottom border of the Player Name text control.  Just 
        ### mousing over that control removes the artifact.  It's not 
        ### interfering with anything, it's just ugly.
        ###
        ### Calling SetFocus on that txt_name control isn't just convenient (and 
        ### it is), it also removes that artifact.

        return 1;
    }#}}}
    sub OnClose {#{{{
        my $self    = shift;
        my $dialog  = shift;    # Wx::Dialog (NOT Wx::ScrolledWindow here!)
        my $event   = shift;    # Wx::CommandEvent
        #$dialog->Destroy;
        $self->Destroy;
        $event->Skip();
        return 1;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;
