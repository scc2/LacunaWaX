
### Search for CHECK



=pod

Everything that's here works.


Need an acutal repair button to fix the stuff in the right list.  Anything not 
fully repaired needs to end up back in the left list with its Damage column 
updated.

I'm also thinking about a text box where the user can enter the lowest they 
want their resources to go (but this is only after everything else works.)

=cut



package LacunaWaX::MainSplitterWindow::RightPane::RepairPane {
    use v5.14;
    use Data::Dumper;
    use LacunaWaX::Model::Client;
    use List::Util qw(first);
    use Moose;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_BUTTON EVT_LIST_COL_CLICK);
    with 'LacunaWaX::Roles::MainSplitterWindow::RightPane';

    has 'sizer_debug'   => (is => 'rw', isa => 'Int', lazy => 1, default => 0);

    has 'row' => (
        is => 'rw',
        isa => 'Int',
        traits      => ['Counter'],
        handles => {
            inc_row   => 'inc',
            dec_row   => 'dec',
            reset_row => 'reset',
        },
        default => 0,
    );

    has 'status' => (
        is => 'rw',
        isa => 'LacunaWaX::Dialog::Status', 
        lazy_build => 1,
        documentation => q{
            This is just for debugging and can go away.
        }
    );

    has 'show_bldgs' => (
        is      => 'rw',
        isa     => 'Str',
        lazy    => 1,
        default => 'all',
        documentation => q{
            Determines whether we show all buildings in the left ListCtrl, or only damaged buildings.

            If the value is anything other than 'all', we'll just display damaged buildings.

            "Only damaged" seems to make more sense for real use, but 'all' is easier to work on and test.
        }
    );

    has 'glyph_bldgs' => (
        is          => 'rw',
        isa         => 'ArrayRef[Str]',
        lazy_build  => 1,
        traits      => ['Array'],
        handles     => {
            all_glyph_bldgs     => 'elements',
            add_glyph_bldg      => 'push',
            find_glyph_bldg     => 'first',
        }
    );

    has 'planet_id'     => (is => 'rw', isa => 'Int', lazy_build => 1);
    has 'planet_name'   => (is => 'rw', isa => 'Str', required => 1);

    has 'buildings' => (    # id => bldg_hashref
        is          => 'rw',
        isa         => 'HashRef',
        traits      => ['Hash'],
        handles => {
            bldg_ids => 'keys',
            get_bldg => 'get',
        },
        lazy_build  => 1,
    );

    has 'btn_w' => (is => 'rw', isa => 'Int', lazy => 1, default => 50);
    has 'btn_h' => (is => 'rw', isa => 'Int', lazy => 1, default => 30);
    has 'lst_w' => (is => 'rw', isa => 'Int', lazy => 1, default => 25);
    has 'lst_h' => (is => 'rw', isa => 'Int', lazy => 1, default => 500);

    has 'szr_header'    => (is => 'rw', isa => 'Wx::BoxSizer', lazy_build => 1, documentation => 'vertical'     );
    has 'szr_btn_list'  => (is => 'rw', isa => 'Wx::BoxSizer', lazy_build => 1, documentation => 'vertical'     );
    has 'szr_lists'     => (is => 'rw', isa => 'Wx::BoxSizer', lazy_build => 1, documentation => 'horizontal'   );

    has 'btn_add'               => (is => 'rw', isa => 'Wx::Button',        lazy_build => 1     );
    has 'btn_add_all'           => (is => 'rw', isa => 'Wx::Button',        lazy_build => 1     );
    has 'btn_del'               => (is => 'rw', isa => 'Wx::Button',        lazy_build => 1     );
    has 'btn_del_all'           => (is => 'rw', isa => 'Wx::Button',        lazy_build => 1     );
    has 'btn_add_glyphs'        => (is => 'rw', isa => 'Wx::Button',        lazy_build => 1     );
    has 'lst_bldgs_onsite'      => (is => 'rw', isa => 'Wx::ListCtrl',      lazy_build => 1     );
    has 'lst_bldgs_to_repair'   => (is => 'rw', isa => 'Wx::ListCtrl',      lazy_build => 1     );
    has 'lbl_header'            => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1     );
    has 'lbl_instructions'      => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1     );

    sub BUILD {
        my $self = shift;

        $self->lst_bldgs_onsite();
        $self->populate_bldgs_list( $self->lst_bldgs_onsite );

        $self->szr_header->Add($self->lbl_header, 0, 0, 0);
        $self->szr_header->AddSpacer(5);
        $self->szr_header->Add($self->lbl_instructions, 0, 0, 0);

        $self->szr_btn_list->AddStretchSpacer(6);
        $self->szr_btn_list->Add($self->btn_add, 1, 0, 0);
        $self->szr_btn_list->Add($self->btn_add_all, 1, 0, 0);
        $self->szr_btn_list->Add($self->btn_del, 1, 0, 0);
        $self->szr_btn_list->Add($self->btn_del_all, 1, 0, 0);
        $self->szr_btn_list->AddSpacer(4);
        $self->szr_btn_list->Add($self->btn_add_glyphs, 1, 0, 0);
        $self->szr_btn_list->AddStretchSpacer(1);

        $self->szr_lists->Add($self->lst_bldgs_onsite, 10, 0, 0);
        $self->szr_lists->AddSpacer(5);
        $self->szr_lists->Add($self->szr_btn_list, 0, 0, 0);
        $self->szr_lists->AddSpacer(5);
        $self->szr_lists->Add($self->lst_bldgs_to_repair, 10, 0, 0);
        my $s = $self->parent->GetSize;
        $self->szr_lists->SetMinSize( Wx::Size->new($s->GetWidth - $self->btn_w, -1) );

        $self->content_sizer->Add($self->szr_header, 0, 0, 0);
        $self->content_sizer->AddSpacer(20);
        $self->content_sizer->Add($self->szr_lists, 0, 0, 0);
        return $self;
    }
    sub _build_btn_add {#{{{
        my $self = shift;
        my $v = Wx::Button->new(
            $self->parent, -1, 
            q{>},
            wxDefaultPosition,
            Wx::Size->new($self->btn_w, $self->btn_h),
        );
        $v->SetFont( $self->get_font('/bold_para_text_1') );
        my $tt = Wx::ToolTip->new("Add");
        $v->SetToolTip($tt);
        return $v;
    }#}}}
    sub _build_btn_add_all {#{{{
        my $self = shift;
        my $v = Wx::Button->new(
            $self->parent, -1, 
            q{>>},
            wxDefaultPosition,
            Wx::Size->new($self->btn_w, $self->btn_h),
        );
        $v->SetFont( $self->get_font('/bold_para_text_1') );
        my $tt = Wx::ToolTip->new("Add All");
        $v->SetToolTip($tt);
        return $v;
    }#}}}
    sub _build_btn_add_glyphs {#{{{
        my $self = shift;
        my $v = Wx::Button->new(
            $self->parent, -1, 
            q{Glyphs},
            wxDefaultPosition,
            Wx::Size->new($self->btn_w, $self->btn_h),
        );
        $v->SetFont( $self->get_font('/para_text_1') );
        my $tt = Wx::ToolTip->new("Glyph buildings are free to repair.");
        $v->SetToolTip($tt);
        return $v;
    }#}}}
    sub _build_btn_del {#{{{
        my $self = shift;
        my $v = Wx::Button->new(
            $self->parent, -1, 
            q{<},
            wxDefaultPosition,
            Wx::Size->new($self->btn_w, $self->btn_h),
        );
        $v->SetFont( $self->get_font('/bold_para_text_1') );
        my $tt = Wx::ToolTip->new("Remove");
        $v->SetToolTip($tt);
        return $v;
    }#}}}
    sub _build_btn_del_all {#{{{
        my $self = shift;
        my $v = Wx::Button->new(
            $self->parent, -1, 
            q{<<},
            wxDefaultPosition,
            Wx::Size->new($self->btn_w, $self->btn_h),
        );
        $v->SetFont( $self->get_font('/bold_para_text_1') );
        my $tt = Wx::ToolTip->new("Remove All");
        $v->SetToolTip($tt);
        return $v;
    }#}}}
    sub _build_buildings {#{{{
        my $self  = shift;
        my $force = shift || 0;

        my $bldgs = try {
            $self->game_client->get_buildings($self->planet_id, undef, $force);
        }
        catch {
            my $msg = (ref $_) ? $_->text : $_;
            $self->poperr($msg);
            return;
        };

        unless( $self->show_bldgs eq 'all' ) {
            my $ret_bldgs = {};
            while( my($id, $hr) = each %{$bldgs} ) {
                $ret_bldgs->{$id} = $hr if( $hr->{'efficiency'} < 100 );
            }
            $bldgs = $ret_bldgs;
        }

    ### CHECK
    while(my($id, $hr) = each %$bldgs ) {
        if( $hr->{'name'} =~ /Beach/ ) {
            say Dumper $hr;
        }
    }

        return $bldgs;
    }#}}}
    sub _build_glyph_bldgs {#{{{
        my $self  = shift;

### CHECK
### I'm not 100% positive that the junk buildings repair FOC.

        my $v = [
            'algae pond',
            'amalgus meadow',
            'beach [1]',
            'beach [2]',
            'beach [3]',
            'beach [4]',
            'beach [5]',
            'beach [6]',
            'beach [7]',
            'beach [8]',
            'beach [9]',
            'beach [10]',
            'beach [11]',
            'beach [12]',
            'beach [13]',
            'beeldeban nest',
            'black hole generator',
            'citadel of knope',
            'crashed ship site',
            'crater',
            'denton brambles',
            'geo thermal vent',
            "gratch's gauntlet",
            'great ball of junk',
            'grove',
            'interdimensional rift',
            'junk henge sculpture',
            'kalavian ruins',
            'kasterns keep',
            'lapis forest',
            'library of jith',
            'malcud field',
            'massads henge',
            'metal junk arches',
            'natural spring',
            'oracle of anid',
            'pantheon of hagness',
            'pyramid junk sculpture',
            'ravine',
            'space junk park',
            'temple of the drajilites',
            'the dillon forge',
            'volcano',
        ];

        return $v;
    }#}}}
    sub _build_lbl_header {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self->parent, -1, 
            "Repair Damaged Buildings on " . $self->planet_name,
            wxDefaultPosition, Wx::Size->new(-1, 40)
        );
        $y->SetFont( $self->get_font('/header_1') );
        return $y;
    }#}}}
    sub _build_lbl_instructions {#{{{
        my $self = shift;

        my $indent = q{ }x4;
        my $text = "This is where the instructions go.";

        my $y = Wx::StaticText->new(
            $self->parent, -1,
            $text,
            wxDefaultPosition, 
            Wx::Size->new(-1, 20)
        );
        $y->SetFont( $self->get_font('/para_text_2') );
        $y->Wrap( 560 );

        return $y;
    }#}}}
    sub _build_lst_bldgs_onsite {#{{{
        my $self = shift;
        my $v = Wx::ListCtrl->new(
            $self->parent, -1, 
            wxDefaultPosition, 
            Wx::Size->new($self->lst_w,$self->lst_h), 
            wxLC_REPORT
            |wxSUNKEN_BORDER
            |wxLC_SINGLE_SEL
        );
        $v->InsertColumn(0, 'Name');
        $v->InsertColumn(1, 'X');
        $v->InsertColumn(2, 'Y');
        $v->InsertColumn(3, 'Damaged');
        $v->SetColumnWidth(0,150);
        $v->SetColumnWidth(1,40);
        $v->SetColumnWidth(2,40);
        $v->SetColumnWidth(3,100);
        $v->Arrange(wxLIST_ALIGN_TOP);
        $self->yield;

        return $v;
    }#}}}
    sub _build_lst_bldgs_to_repair {#{{{
        my $self = shift;
        my $v = Wx::ListCtrl->new(
            $self->parent, -1, 
            wxDefaultPosition, 
            Wx::Size->new($self->lst_w,$self->lst_h), 
            wxLC_REPORT
            |wxSUNKEN_BORDER
            |wxLC_SINGLE_SEL
        );
        $v->InsertColumn(0, 'Name');
        $v->InsertColumn(1, 'X');
        $v->InsertColumn(2, 'Y');
        $v->InsertColumn(3, 'Damaged');
        $v->SetColumnWidth(0,150);
        $v->SetColumnWidth(1,40);
        $v->SetColumnWidth(2,40);
        $v->SetColumnWidth(3,100);
        $v->Arrange(wxLIST_ALIGN_TOP);
        $self->yield;
        return $v;
    }#}}}
    sub _build_planet_id {#{{{
        my $self = shift;
        return $self->game_client->planet_id( $self->planet_name );
    }#}}}
    sub _build_status {#{{{
        my $self = shift;
        my $s = LacunaWaX::Dialog::Status->new(
            app      => $self->app,
            ancestor => $self,
            title    => 'Status',
        );
        return $s;
    }#}}}
    sub _build_szr_header {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxVERTICAL, 'Header');
    }#}}}
    sub _build_szr_btn_list {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxVERTICAL, 'Lists');
    }#}}}
    sub _build_szr_lists {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxHORIZONTAL, 'Lists');
    }#}}}
    sub _set_events {#{{{
        my $self = shift;
        EVT_BUTTON(         $self->parent, $self->btn_add->GetId,               sub{$self->OnAddSingle(@_)}  );
        EVT_BUTTON(         $self->parent, $self->btn_add_all->GetId,           sub{$self->OnAddAll(@_)}  );
        EVT_BUTTON(         $self->parent, $self->btn_del->GetId,               sub{$self->OnDelSingle(@_)}  );
        EVT_BUTTON(         $self->parent, $self->btn_del_all->GetId,           sub{$self->OnDelAll(@_)}  );
        EVT_BUTTON(         $self->parent, $self->btn_add_glyphs->GetId,        sub{$self->OnAddGlyphs(@_)}  );
        EVT_LIST_COL_CLICK( $self->parent, $self->lst_bldgs_onsite->GetId,      sub{$self->OnLeftLstHeaderClick(@_)}  );
        EVT_LIST_COL_CLICK( $self->parent, $self->lst_bldgs_to_repair->GetId,   sub{$self->OnRightLstHeaderClick(@_)}  );
        return 1;
    }#}}}

    sub add_row {#{{{
        my $self    = shift;
        my $list    = shift;
        my $name    = shift;
        my $x       = shift;
        my $y       = shift;
        my $damage  = shift;

=pod

Inserts a properly-formated row into the TOP of the indicated list.

Note that you must send damage, not efficiency.  The game server hands us back 
efficiency percent (eg "percent undamaged").  So if you're working with a 
server reply, get damage by:

  $damage = 100 - $bldg_hr->{'efficiency'}

All strings passed in will be trimmed of whitespace (front and back).  $damage 
will also have any % signs stripped.

Returns the index of the row just added.

=cut

        $name   = $self->trim($name);
        $x      = $self->trim($x);
        $y      = $self->trim($y);
        $damage = $self->trim($damage);
        $damage =~ s/[%]//g;

        ### Set the current zero-based row number as the item's data.  We have 
        ### to remember to reset that row number after creating our first list 
        ### if we plan to use it again.  Hacky and nasty.
        my $itm_name = Wx::ListItem->new();
        $itm_name->SetText( $name );
        $itm_name->SetData( $self->row );

        my $row_idx = $list->InsertItem($itm_name);
        $list->SetItem( $row_idx, 1, sprintf("%2d", $x) );
        $list->SetItem( $row_idx, 2, sprintf("%2d", $y) );
        $list->SetItem( $row_idx, 3, sprintf("%3d%%", $damage) );

        $self->inc_row;
        return $row_idx;
    }#}}}
    sub byname_rev {#{{{
        my $self = shift;
        $self->buildings->{$b}->{'name'} cmp $self->buildings->{$a}->{'name'};
    }#}}}
    sub list_sort_alpha {#{{{
        my $self = shift;
        my $ay   = shift;
        my $bee  = shift;
        my $list = shift;
        my $col  = shift;

        my $i1_off = $list->FindItemData(-1, $ay);
        my $i2_off = $list->FindItemData(-1, $bee);
        my $i1 = $list->GetItem($i1_off, $col);
        my $i2 = $list->GetItem($i2_off, $col);
        my $n1 = $i1->GetText;
        my $n2 = $i2->GetText;

        my $rv = $n1 cmp $n2;
        return $rv;
    }#}}}
    sub list_sort_num {#{{{
        my $self = shift;
        my $ay   = shift;
        my $bee  = shift;
        my $list = shift;
        my $col  = shift;

        my $i1_off = $list->FindItemData(-1, $ay);
        my $i2_off = $list->FindItemData(-1, $bee);
        my $i1 = $list->GetItem($i1_off, $col);
        my $i2 = $list->GetItem($i2_off, $col);
        my $n1 = $i1->GetText;
        my $n2 = $i2->GetText;

        my $dat_1 = $n1 =~ s/[\s%]+//gr;
        my $dat_2 = $n2 =~ s/[\s%]+//gr;

        my $rv = $dat_1 <=> $dat_2;
        return $rv;
    }#}}}
    sub populate_bldgs_list {#{{{
        my $self = shift;
        my $list = shift;

        ### Each insert goes _above_ the previous item, so start with a 
        ### reverse sort.
        foreach my $bldg_id( sort{$self->byname_rev}$self->bldg_ids ) {
            my $bldg_hr = $self->get_bldg($bldg_id);

            $self->add_row(
                $list,
                $bldg_hr->{'name'},
                $bldg_hr->{'x'},
                $bldg_hr->{'y'},
                (100 - $bldg_hr->{'efficiency'}),
            );
        }

        $self->reset_row;
    }#}}}
    sub trim {#{{{
        my $self = shift;
        my $str  = shift;
        $str =~ s/^\s+//;
        $str =~ s/\s+$//;
        return $str;
    }#}}}

    sub OnAddSingle {#{{{
        my $self    = shift;
        my $parent  = shift;    # Wx::ScrolledWindow
        my $event   = shift;    # Wx::CommandEvent

        ### Despite the name of this method, if the lefthand ListCtrl is set 
        ### to Multiple select, this should work just fine to add all selected 
        ### rows.

        while( 1 ) {
            my $row = -1;
            $row = $self->lst_bldgs_onsite->GetNextItem($row, wxLIST_NEXT_ALL, wxLIST_STATE_SELECTED);
            last if $row == -1;

            my $name    = $self->lst_bldgs_onsite->GetItem($row, 0);
            my $x       = $self->lst_bldgs_onsite->GetItem($row, 1);
            my $y       = $self->lst_bldgs_onsite->GetItem($row, 2);
            my $damage  = $self->lst_bldgs_onsite->GetItem($row, 3);

            $self->add_row(
                $self->lst_bldgs_to_repair,
                $name->GetText,
                $x->GetText,
                $y->GetText,
                $damage->GetText,
            );
            $self->lst_bldgs_onsite->DeleteItem( $row );
        }

        return 1;
    }#}}}
    sub OnAddAll {#{{{
        my $self    = shift;
        my $parent  = shift;    # Wx::ScrolledWindow
        my $event   = shift;    # Wx::CommandEvent

        while( 1 ) {
            my $row = -1;
            $row = $self->lst_bldgs_onsite->GetNextItem($row, wxLIST_NEXT_ALL, wxLIST_STATE_DONTCARE);
            last if $row == -1;
            $self->lst_bldgs_onsite->DeleteItem( $row );
        }

        $self->populate_bldgs_list( $self->lst_bldgs_to_repair );
        return 1;
    }#}}}
    sub OnAddGlyphs {#{{{
        my $self    = shift;
        my $parent  = shift;    # Wx::ScrolledWindow
        my $event   = shift;    # Wx::CommandEvent

        my $row = -1;
        while( 1 ) {
            $row = $self->lst_bldgs_onsite->GetNextItem($row, wxLIST_NEXT_ALL, wxLIST_STATE_DONTCARE);
            last if $row == -1;

            my $itm = $self->lst_bldgs_onsite->GetItem($row);
            my $name = $itm->GetText;
            if( $self->find_glyph_bldg(sub{$_ eq lc $name}) ) {
                $self->lst_bldgs_onsite->DeleteItem( $row );
                $row--; # since we just deleted one, back up or we'll skip the next one if two are consecutive.
            }
        }

        foreach my $id( $self->bldg_ids ) {
            my $bldg = $self->get_bldg($id);
            ### The stripping is to make Gratch's match - the ' is messing up 
            ### the match without the strip.  Don't know why - it doesn't 
            ### cause problems above.
            if( $self->find_glyph_bldg(sub{my $it = $_; my $n = $bldg->{'name'}; $it =~ s/\W//g; $n =~ s/\W//g; return($it eq lc $n)}) ) {
                $self->add_row(
                    $self->lst_bldgs_to_repair,
                    $bldg->{'name'},
                    $bldg->{'x'},
                    $bldg->{'y'},
                    (100 - $bldg->{'efficiency'}),
                )
            }
            else {
                if( $bldg->{'name'} =~ /gratch/i ) {
                    say Dumper $bldg;
                }
            }
        }
            
        return 1;
    }#}}}
    sub OnDelSingle {#{{{
        my $self    = shift;
        my $parent  = shift;    # Wx::ScrolledWindow
        my $event   = shift;    # Wx::CommandEvent

        ### Despite the name of this method, if the lefthand ListCtrl is set 
        ### to Multiple select, this should work just fine to add all selected 
        ### rows.

        while( 1 ) {
            my $row = -1;
            $row = $self->lst_bldgs_to_repair->GetNextItem($row, wxLIST_NEXT_ALL, wxLIST_STATE_SELECTED);
            last if $row == -1;

            my $name    = $self->lst_bldgs_to_repair->GetItem($row, 0);
            my $x       = $self->lst_bldgs_to_repair->GetItem($row, 1);
            my $y       = $self->lst_bldgs_to_repair->GetItem($row, 2);
            my $damage  = $self->lst_bldgs_to_repair->GetItem($row, 3);

            $self->add_row(
                $self->lst_bldgs_onsite,
                $name->GetText,
                $x->GetText,
                $y->GetText,
                $damage->GetText,
            );
            $self->lst_bldgs_to_repair->DeleteItem( $row );
        }

        return 1;
    }#}}}
    sub OnDelAll {#{{{
        my $self    = shift;
        my $parent  = shift;    # Wx::ScrolledWindow
        my $event   = shift;    # Wx::CommandEvent

        while( 1 ) {
            my $row = -1;
            $row = $self->lst_bldgs_to_repair->GetNextItem($row, wxLIST_NEXT_ALL, wxLIST_STATE_DONTCARE);
            last if $row == -1;
            $self->lst_bldgs_to_repair->DeleteItem( $row );
        }

        $self->populate_bldgs_list( $self->lst_bldgs_onsite );
        return 1;
    }#}}}

    sub OnLeftLstHeaderClick {#{{{
        my $self    = shift;
        my $parent  = shift;    # Wx::ScrolledWindow
        my $event   = shift;    # Wx::ListEvent

        given($event->GetColumn) {  # zero-based integer offset
            when(0) {
                $self->lst_bldgs_onsite->SortItems( sub{$self->list_sort_alpha(@_, $self->lst_bldgs_onsite, 0)} );
            }
            when(1) {
                my $rv = $self->lst_bldgs_onsite->SortItems( sub{$self->list_sort_num(@_, $self->lst_bldgs_onsite, 1)} );
            }
            when(2) {
                my $rv = $self->lst_bldgs_onsite->SortItems( sub{$self->list_sort_num(@_, $self->lst_bldgs_onsite, 2)} );
            }
            when(3) {
                my $rv = $self->lst_bldgs_onsite->SortItems( sub{$self->list_sort_num(@_, $self->lst_bldgs_onsite, 3)} );
            }
            default {
                my $rv = $self->lst_bldgs_onsite->SortItems( sub{$self->list_sort_alpha(@_, $self->lst_bldgs_onsite, 0)} );
            }
        }

        $event->Skip;
    }#}}}
    sub OnRightLstHeaderClick {#{{{
        my $self    = shift;
        my $parent  = shift;    # Wx::ScrolledWindow
        my $event   = shift;    # Wx::ListEvent

        given($event->GetColumn) {  # zero-based integer offset
            when(0) {
                $self->lst_bldgs_to_repair->SortItems( sub{$self->list_sort_alpha(@_, $self->lst_bldgs_to_repair, 0)} );
            }
            when(1) {
                my $rv = $self->lst_bldgs_to_repair->SortItems( sub{$self->list_sort_num(@_, $self->lst_bldgs_to_repair, 1)} );
            }
            when(2) {
                my $rv = $self->lst_bldgs_to_repair->SortItems( sub{$self->list_sort_num(@_, $self->lst_bldgs_to_repair, 2)} );
            }
            when(3) {
                my $rv = $self->lst_bldgs_to_repair->SortItems( sub{$self->list_sort_num(@_, $self->lst_bldgs_to_repair, 3)} );
            }
            default {
                my $rv = $self->lst_bldgs_to_repair->SortItems( sub{$self->list_sort_alpha(@_, $self->lst_bldgs_to_repair, 0)} );
            }
        }

        $event->Skip;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;

__END__

=head2 ListCtrls

These are a freaking mess.

In Report mode, which is what's mostly being used in LacunaWaX, an "item" is a 
row.  The thingies in the columns are "sub-items".

To set up a ListCtrl:
    - Create a variable, initialized to 0.  This keeps track of what row 
      you're on.
        - We're going to call it just "$row".
    - Create the ListCtrl object
    - Define its columns (and set their widths).

To populate the list with data:
    - Create a ListItem and insert it
        - $item = Wx::ListItem->new();
        - $item->SetText("This goes in column 0 of this row");
        - $item->SetData($row++);
            - An item's data must be an integer.
        - $row_index = $list->InsertItem($item);
            - InsertItem is like unshift - it's going to jam your new item at 
              the top of your list, not the bottom.
            - There is not, STUPIDLY, any sort of AppendItem() method.
            - So the $row_index is going to be zero every freaking time, since 
              you're inserting at position 0.  It does not tell you how many 
              rows there are in your ListCtrl (hence the existence of $row).
            - If you're presorting your list items before adding them to the 
              ListCtrl, sort them backwards, as they're being added from the 
              bottom to the top, not vice versa.

    - For each additional column in that same row, you must call SetItem (NOT 
      InsertItem again!)
        - $list->SetItem( $row_index, 1, "this goes in column 1 (the second column)" );
        - $list->SetItem( $row_index, 1, "this goes in column 2 (the third column)" );
        - ...

To get at a specific "field":
    - This is where things start getting tricksy.  You can find an item by 
      either its string or its data.
        - I haven't tried doing it by string yet, but I tend to assume that 
          the string you have to search for is the string in the first column, 
          EVEN if what you're looking for is the sub-item in column > 0.


    - I _have_ tried finding the item by its data, and that works.  This is 
      why I'm storing the row offset as each item's data.

    - So if you want to find the text held in the third row, fifth column:

        - We're looking for the third row (so offset 2).  Earlier, we set each 
          item's data to be the same as its row offset, that data is actually 
          what we're searching for:

            - $find_data = 2;   # offset for row 3
            - $column = 4;      # offset for column 5

            - my $itm_offset = $list->FindItemData(-1, $find_data);
                - "-1" means "search from the beginning".

            - my $itm = $list->GetItem($itm_offset, $column);

            - my $str = $itm->GetText;  # There it is!


I am not seeing any reasonable way to specify what row we're dealing with 
other than preserving that information ourselves in each item's user data with 
SetData().

=cut

