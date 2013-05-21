
package LacunaWaX::MainSplitterWindow::RightPane::SpiesPane::SpyRow {
    use v5.14;
    use DateTime;
    use DateTime::Duration;
    use Moose;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_TEXT EVT_LEAVE_WINDOW);
    with 'LacunaWaX::Roles::GuiElement';

    has 'sizer_debug'   => (is => 'rw', isa => 'Int', lazy => 1, default => 0);

    has 'spy' => (is => 'rw', isa => 'LacunaWaX::Model::Client::Spy',
        documentation => q{
            Not required so we can generate a header, but othewise it's needed.
        }
    );

    has 'text_none'     => (is => 'rw', isa => 'Str', lazy => 1, default => 'None',
        documentation => q{
            Simply the string value used to indicate 'no training' in the training select box.
        }
    );

    has 'is_header'     => (is => 'rw', isa => 'Int', lazy => 1, default => 0,
        documentation => q{
            If true, the produced Row will be a simple header with no input
            controls and no events.  The advantage is that the header's size will 
            match the size of the rest of the rows you're about to produce.
        }
    );

    has 'new_name' => ( is => 'rw', isa => 'Str',
        documentation => q{
            If the user wants to change the name of the spy, that new name goes in here.  Upon 
            clicking the "rename" button, any spy rows that have a new_name that's not equal to 
            $row->spy->name need to have their spies actually renamed.
        }
    );

    has 'row_width'     => (is => 'rw', isa => 'Int', lazy => 1,    default => 650      );
    has 'row_height'    => (is => 'rw', isa => 'Int', lazy => 1,    default => 25       );

    has 'name_width'    => (is => 'rw', isa => 'Int', lazy => 1, default => 100 );
    has 'loc_width'     => (is => 'rw', isa => 'Int', lazy => 1, default => 100 );
    has 'task_width'    => (is => 'rw', isa => 'Int', lazy => 1, default => 70  );
    has 'skill_width'   => (is => 'rw', isa => 'Int', lazy => 1, default => 50  );
    has 'level_width'   => (is => 'rw', isa => 'Int', lazy => 1, default => 50  );
    has 'train_width'   => (is => 'rw', isa => 'Int', lazy => 1, default => 90  );

    has 'name_header'       => (is => 'rw', isa => 'Wx::StaticText');
    has 'loc_header'        => (is => 'rw', isa => 'Wx::StaticText');
    has 'task_header'       => (is => 'rw', isa => 'Wx::StaticText');
    has 'intel_header'      => (is => 'rw', isa => 'Wx::StaticText');
    has 'mayhem_header'     => (is => 'rw', isa => 'Wx::StaticText');
    has 'politics_header'   => (is => 'rw', isa => 'Wx::StaticText');
    has 'theft_header'      => (is => 'rw', isa => 'Wx::StaticText');
    has 'train_header'      => (is => 'rw', isa => 'Wx::StaticText');

    has 'szr_main'      => (is => 'rw', isa => 'Wx::BoxSizer',      lazy_build => 1     );
    has 'szr_name'      => (is => 'rw', isa => 'Wx::BoxSizer',      lazy_build => 1     );
    has 'szr_task'      => (is => 'rw', isa => 'Wx::BoxSizer',      lazy_build => 1     );
    has 'szr_level'     => (is => 'rw', isa => 'Wx::BoxSizer',      lazy_build => 1     );
    has 'szr_loc'       => (is => 'rw', isa => 'Wx::BoxSizer',      lazy_build => 1     );
    has 'szr_offense'   => (is => 'rw', isa => 'Wx::BoxSizer',      lazy_build => 1     );
    has 'szr_defense'   => (is => 'rw', isa => 'Wx::BoxSizer',      lazy_build => 1     );
    has 'szr_intel'     => (is => 'rw', isa => 'Wx::BoxSizer',      lazy_build => 1     );
    has 'szr_mayhem'    => (is => 'rw', isa => 'Wx::BoxSizer',      lazy_build => 1     );
    has 'szr_politics'  => (is => 'rw', isa => 'Wx::BoxSizer',      lazy_build => 1     );
    has 'szr_theft'     => (is => 'rw', isa => 'Wx::BoxSizer',      lazy_build => 1     );
    has 'szr_train'     => (is => 'rw', isa => 'Wx::BoxSizer',      lazy_build => 1     );

    has 'lbl_name'          => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1                             );
    has 'lbl_placeholder'   => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1                             );
    has 'tt_name'           => (is => 'rw', isa => 'Str',               lazy_build => 1, documentation => 'ToolTip' );
    has 'txt_name'          => (is => 'rw', isa => 'Wx::TextCtrl',      lazy_build => 1                             );
    has 'lbl_task'          => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1                             );
    has 'lbl_level'         => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1                             );
    has 'lbl_loc'           => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1                             );
    has 'lbl_offense'       => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1                             );
    has 'lbl_defense'       => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1                             );
    has 'lbl_intel'         => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1                             );
    has 'lbl_mayhem'        => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1                             );
    has 'lbl_politics'      => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1                             );
    has 'lbl_theft'         => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1                             );
    has 'chc_train'         => (is => 'rw', isa => 'Wx::Choice',        lazy_build => 1                             );

    sub BUILD {
        my $self = shift;

        if( $self->is_header ) {#{{{
            ### Don't forget to return from set_events when is_header is true 
            ### also
            my $headers_order = [qw(name loc task intel mayhem politics theft train)];
            my $headers = {#{{{
                name        => { w => $self->name_width,  l => 'Name: '     },
                loc         => { w => $self->loc_width,   l => 'Location: ' },
                task        => { w => $self->task_width,  l => 'Task: '     },
                intel       => { w => $self->skill_width, l => 'Intel: '    },
                mayhem      => { w => $self->skill_width, l => 'Myhm: '     },
                politics    => { w => $self->skill_width, l => 'Poli: '     },
                theft       => { w => $self->skill_width, l => 'Theft: '    },
                train       => { w => $self->train_width, l => 'Training: ' },
            };#}}}

            foreach my $head_type( @{$headers_order} ) {
                my $header = $head_type . '_header';
                my $hr     = $headers->{$head_type};

                $self->$header(
                    Wx::StaticText->new(
                        $self->parent, -1, $hr->{'l'},
                        wxDefaultPosition, Wx::Size->new($hr->{'w'},$self->row_height)
                    )
                );

                $self->$header->SetFont( $self->app->wxbb->resolve(service => '/Fonts/header_7') );
                $self->szr_main->Add($self->$header, 0, 0, 0);
            }
            return;
        }#}}}

        $self->lbl_name->SetToolTip( $self->tt_name );

        $self->szr_name->Add(       $self->lbl_name, 0, 0, 0            );
        $self->szr_name->Add(       $self->lbl_placeholder, 0, 0, 0     );
        $self->szr_loc->Add(        $self->lbl_loc, 0, 0, 0             );
        $self->szr_task->Add(       $self->lbl_task, 0, 0, 0            );
        $self->szr_intel->Add(      $self->lbl_intel, 0, 0, 0           );
        $self->szr_mayhem->Add(     $self->lbl_mayhem, 0, 0, 0          );
        $self->szr_politics->Add(   $self->lbl_politics, 0, 0, 0        );
        $self->szr_theft->Add(      $self->lbl_theft, 0, 0, 0           );
        $self->szr_train->Add(      $self->chc_train, 0, 0, 0           );

        $self->szr_main->Add($self->szr_name, 0, 0, 0);
        $self->szr_main->Add($self->szr_loc, 0, 0, 0);
        $self->szr_main->Add($self->szr_task, 0, 0, 0);
        $self->szr_main->Add($self->szr_intel, 0, 0, 0);
        $self->szr_main->Add($self->szr_mayhem, 0, 0, 0);
        $self->szr_main->Add($self->szr_politics, 0, 0, 0);
        $self->szr_main->Add($self->szr_theft, 0, 0, 0);
        $self->szr_main->Add($self->szr_train, 0, 0, 0);

        $self->app->Yield;
        return $self;
    }
    sub _build_chc_train {#{{{
        my $self = shift;
        my $v = Wx::Choice->new(
            $self->parent, -1, 
            wxDefaultPosition, 
            Wx::Size->new($self->train_width, $self->row_height), 
            [$self->text_none, @{$self->app->game_client->spy_training_choices} ]
        );

        my $selection = 0;
        my $schema = $self->app->bb->resolve( service => '/Database/schema' );
        if( my $rec = $schema->resultset('SpyTrainPrefs')->find({spy_id => $self->spy->id}) ) {
            $selection = $v->FindString( ucfirst $rec->train );
        }
        $v->SetSelection($selection);
        $v->SetFont($self->app->wxbb->resolve(service => '/Fonts/para_text_1'));
        return $v;
    }#}}}
    sub _build_int_min {#{{{
        my $self = shift;
        my $im = try {
            $self->app->game_client->get_building($self->planet_id, 'Intelligence Ministry');
        }
        catch {
            $self->app->poperr($_->text);
            return;
        };

        return( $im and ref $im eq 'Games::Lacuna::Client::Buildings::Intelligence' ) ? $im : undef;
    }#}}}
    sub _build_lbl_defense {#{{{
        my $self = shift;
        ### Still available but not being used right now.
        my $y = Wx::StaticText->new(
            $self->parent, -1, 
            'Def: ' . $self->spy->defense,
            wxDefaultPosition, 
            Wx::Size->new(60, $self->row_height)
        );
        $y->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_1') );
        return $y;
    }#}}}
    sub _build_lbl_intel {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self->parent, -1, 
            $self->spy->intel,
            wxDefaultPosition, 
            Wx::Size->new($self->skill_width, $self->row_height - 10)
        );
        $y->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_1') );
        return $y;
    }#}}}
    sub _build_lbl_level {#{{{
        my $self = shift;
        ### Still available but not being used right now.
        my $y = Wx::StaticText->new(
            $self->parent, -1, 
            'Lvl: ' . $self->spy->level,
            wxDefaultPosition, 
            Wx::Size->new($self->level_width, $self->row_height)
        );
        $y->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_1') );
        return $y;
    }#}}}
    sub _build_lbl_loc {#{{{
        my $self = shift;

        my($loc, $tooltip);
        if( $loc = $self->app->game_client->planet_name($self->spy->assigned_to_id) ) {
            substr $loc, 12, (length $loc), '...' if(length $loc > 15);
            $tooltip = Wx::ToolTip->new('Location ID: ' . $self->spy->assigned_to_id);
        }
        else {
            $loc = "Body ID: " . $self->spy->assigned_to_id;
            $tooltip = Wx::ToolTip->new("This spy is on a remote colony; name currently unknown to LacunaWaX.");
        }

        my $y = Wx::StaticText->new(
            $self->parent, -1, 
            $loc,
            wxDefaultPosition, 
            Wx::Size->new($self->loc_width, $self->row_height)
        );
        $y->SetToolTip($tooltip);

        $y->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_1') );
        return $y;
    }#}}}
    sub _build_lbl_mayhem {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self->parent, -1, 
            $self->spy->mayhem,
            wxDefaultPosition, 
            Wx::Size->new($self->skill_width, $self->row_height - 10)
        );
        $y->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_1') );
        return $y;
    }#}}}
    sub _build_lbl_name {#{{{
        my $self = shift;

        my $n = $self->spy->name;
        substr $n, 12, (length $n), '...' if(length $n > 15);
        my $y = Wx::StaticText->new(
            $self->parent, -1, 
            $n,
            wxDefaultPosition, 
            ### Actual name input must be a bit shorter than the name column
            ### If you change the 12 below, also change it in txt_name's 
            ### builder.
            Wx::Size->new($self->name_width - 12, $self->row_height)
        );

        $y->SetFont( $self->app->wxbb->resolve(service => '/Fonts/bold_para_text_1') );
        return $y;
    }#}}}
    sub _build_lbl_task {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self->parent, -1, 
            $self->spy->assignment,
            wxDefaultPosition, 
            Wx::Size->new($self->task_width, $self->row_height)
        );

        if($self->spy->seconds_remaining) {
            my $now     = DateTime->now();
            my $dur     = DateTime::Duration->new( seconds => $self->spy->seconds_remaining );
            my $avail   = $now + $dur;
            my $tt      = Wx::ToolTip->new("Available " . $avail->ymd . q{ } . $avail->hms );
            $y->SetToolTip($tt);
        }

        $y->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_1') );
        return $y;
    }#}}}
    sub _build_lbl_offense {#{{{
        my $self = shift;
        ### Still available but not being used right now.
        my $y = Wx::StaticText->new(
            $self->parent, -1, 
            'Off: ' . $self->spy->offense,
            wxDefaultPosition, 
            Wx::Size->new(60, $self->row_height)
        );
        $y->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_1') );
        return $y;
    }#}}}
    sub _build_lbl_politics {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self->parent, -1, 
            $self->spy->politics,
            wxDefaultPosition, 
            Wx::Size->new($self->skill_width, $self->row_height - 10)
        );
        $y->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_1') );
        return $y;
    }#}}}
    sub _build_lbl_placeholder {#{{{
        my $self = shift;

        ### When we replace the lbl_name with the txt_name, the szr_name is 
        ### briefly empty and so it briefly collapses.
        ### Adding this placeholder into szr_name and then not touching it keeps 
        ### szr_name from ever being empty and therefore it never collapses.
        return Wx::StaticText->new(
            $self->parent, -1, 
            q{},
            wxDefaultPosition, 
            Wx::Size->new(1, 1)
        );
    }#}}}
    sub _build_lbl_theft {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self->parent, -1, 
            $self->spy->theft,
            wxDefaultPosition, 
            Wx::Size->new($self->skill_width, $self->row_height - 10)
        );
        $y->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_1') );
        return $y;
    }#}}}
    sub _build_szr_task {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxHORIZONTAL, 'Task');
    }#}}}
    sub _build_szr_level {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxHORIZONTAL, 'Level');
    }#}}}
    sub _build_szr_loc {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxHORIZONTAL, 'Loc');
    }#}}}
    sub _build_szr_offense {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxHORIZONTAL, 'Offense');
    }#}}}
    sub _build_szr_defense {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxHORIZONTAL, 'Defense');
    }#}}}
    sub _build_szr_intel {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxHORIZONTAL, 'Intel');
    }#}}}
    sub _build_szr_main {#{{{
        my $self = shift;
        my $v = $self->build_sizer($self->parent, wxHORIZONTAL, 'Spy Row');
        $v->SetMinSize( Wx::Size->new($self->row_width, $self->row_height) );
        return $v;
    }#}}}
    sub _build_szr_mayhem {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxHORIZONTAL, 'Mayhem');
    }#}}}
    sub _build_szr_name {#{{{
        my $self = shift;
        my $v = $self->build_sizer($self->parent, wxHORIZONTAL, 'Name');
        my $size = Wx::Size->new($self->name_width, $self->row_height);
        $v->SetMinSize($size);
        return $v;
    }#}}}
    sub _build_szr_politics {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxHORIZONTAL, 'Politics');
    }#}}}
    sub _build_szr_theft {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxHORIZONTAL, 'Theft');
    }#}}}
    sub _build_szr_train {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxHORIZONTAL, 'Train');
    }#}}}
    sub _build_tt_name {#{{{
        my $self = shift;
        my $tt_text = "Name: "    . $self->spy->name . "\n"
                    . "ID: "      . $self->spy->id . "\n"
                    . "Level: "   . $self->spy->level . "\n"
                    . "Offense: " . $self->spy->offense . "\n"
                    . "Defense: " . $self->spy->defense;
        return $tt_text;
    }#}}}
    sub _build_txt_name {#{{{
        my $self = shift;

        my $v = Wx::TextCtrl->new(
            $self->parent, -1, 
            $self->spy->name, 
            wxDefaultPosition, 
            ### Actual name input must be a bit shorter than the name column
            ### If you change the 12 below, also change it in lbl_name's 
            ### builder.
            Wx::Size->new($self->name_width - 12, $self->row_height)
        );
        $v->Show(0);    # this must start hidden
        return $v;
    }#}}}
    sub _set_events {#{{{
        my $self = shift;
        return if $self->is_header;

        ### Clicking on the name label changes it to a text box for renaming
        $self->lbl_name->Connect(
            $self->lbl_name->GetId,
            wxID_ANY,
            wxEVT_LEFT_DOWN,
            sub{$self->OnNameLabelClick(@_)},
        );

        ### Clicking on any other control on the row reverts the name text box 
        ### (if it's shown) back to the label.
        foreach my $control( qw(lbl_loc lbl_task lbl_intel lbl_mayhem lbl_politics lbl_theft chc_train) ) {
            $self->$control->Connect(
                $self->$control->GetId,
                wxID_ANY,
                wxEVT_LEFT_DOWN,
                sub{$self->OnNonNameClick(@_)},
            );
        }

        return 1;

        ### The OnChange event for the txt_name is set up in OnNameLabelClick, 
        ### /after/ the txt_name is created.  Doing it here would cause 
        ### txt_name's lazy builder to be called, which would end up putting 
        ### it in the wrong place if the screen has been scrolled.
    }#}}}

    sub change_name {#{{{
        my $self = shift;
        my $name = shift;

        $self->spy->name( $name );
        $self->lbl_name->SetLabel( $name );
        $self->txt_name->SetValue( $name );

        ### Clear the current tooltip, then recreate and reassign it.
        $self->clear_tt_name;
        $self->lbl_name->SetToolTip( $self->tt_name );
        return 1;
    }#}}}

    sub OnNameLabelClick {#{{{
        my $self     = shift;
        my $lbl_name = shift;    # Wx::StaticText
        my $event    = shift;    # Wx::MouseEvent

        $self->lbl_name->Show(0);
        $self->szr_name->Replace( $self->lbl_name, $self->txt_name );
        EVT_TEXT( $self->parent, $self->txt_name->GetId,     sub{$self->OnSpyNameChanged(@_)}   );
        $self->txt_name->MoveAfterInTabOrder( $self->lbl_name );

        ### The user has very likely scrolled their window, which confuses 
        ### sizers and positions.
        ### So Layout() has to be called on the ScrolledWindow, which 
        ### understands how to deal with its own scrolling.
        my $grandparent = $self->ancestor->ancestor;
        $grandparent->main_panel->Layout();

        $self->txt_name->Show(1);
        $self->txt_name->SetFocus();
        $self->txt_name->SetSelection(-1, -1);
        $self->szr_name->Layout();
        $self->szr_main->Layout();
        return 1;
    }#}}}
    sub OnNonNameClick {#{{{
        my $self     = shift;
        my $lbl_name = shift;    # Wx::StaticText
        my $event    = shift;    # Wx::MouseEvent

        unless( $self->txt_name->IsShown ) {
            $event->Skip;   # Must Skip or the select boxes won't work
            return;
        }
        $self->txt_name->Show(0);
        $self->szr_name->Replace( $self->txt_name, $self->lbl_name );

        ### The user has very likely scrolled their window, which confuses 
        ### sizers and positions.
        ### So Layout() has to be called on the ScrolledWindow, which 
        ### understands how to deal with its own scrolling.
        my $grandparent = $self->ancestor->ancestor;
        $grandparent->main_panel->Layout();

        $self->lbl_name->Show(1);
        $self->szr_name->Layout();
        $self->szr_main->Layout();

        $event->Skip;
        return 1;
    }#}}}
    sub OnSpyNameChanged {#{{{
        my $self    = shift;
        my $parent  = shift;
        my $event   = shift;
    
        my $new_name = $self->txt_name->GetValue;
        $self->new_name( $new_name );
        $self->lbl_name->SetLabel($new_name);

        $event->Skip;
        return 1;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;
