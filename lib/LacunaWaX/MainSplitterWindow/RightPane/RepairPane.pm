
package LacunaWaX::MainSplitterWindow::RightPane::RepairPane {
    use v5.14;
    use Data::Dumper;
    use LacunaWaX::Generics::ResBar;
    use LacunaWaX::Model::Client;
    use List::Util qw(first);
    use Moose;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_BUTTON EVT_CLOSE EVT_LIST_COL_CLICK);
    with 'LacunaWaX::Roles::MainSplitterWindow::RightPane';

    has 'sizer_debug'   => (is => 'rw', isa => 'Int',                           lazy => 1,      default => 0    );
    has 'planet_id'     => (is => 'rw', isa => 'Int',                           lazy_build => 1                 );
    has 'planet_name'   => (is => 'rw', isa => 'Str',                                           required => 1   );
    has 'status'        => (is => 'rw', isa => 'LacunaWaX::Dialog::Status',     lazy_build => 1                 );
    has 'res_bar'       => (is => 'rw', isa => 'LacunaWaX::Generics::ResBar',   lazy_build => 1                 );

    has 'show_bldgs' => (
        is      => 'rw',
        isa     => 'Str',
        lazy    => 1,
        #default => 'all',
        default => 'flurble',
        documentation => q{
            Determines whether we show all buildings in the left ListCtrl, or 
            only damaged buildings.  If the value is anything other than 
            'all', we'll just display damaged buildings.  "Only damaged" seems 
            to make more sense for real use, but 'all' is easier to work on 
            and test.
            This should only be set to 'all' while developing (so you can see 
            contents in the left list without having to snark yourself).
        }
    );

    has 'flg_stop' => (
        is      => 'rw',
        isa     => 'Int',
        lazy    => 1,
        default => 0,
        documentation => q{
            If the user closes the status window while repairs are in progress, this flag will
            get turned on, and repairs will stop.  After the current loop ends, this flag will 
            get turned back off again.
        }
    );

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
        documentation => q{
            Keeps track of which row we're working on while inserting items into a list.
            Be careful with this.
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
        },
        documentation => q{
            Just a list of glyph buildings.  Spelling and spacing match the human names
            ("space port" rather than "spaceport"), but all lc().
        }
    );

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

    has 'btn_w' => (is => 'rw', isa => 'Int', lazy => 1, default => 50  );
    has 'btn_h' => (is => 'rw', isa => 'Int', lazy => 1, default => 30  );
    has 'lst_w' => (is => 'rw', isa => 'Int', lazy => 1, default => 25  );
    has 'lst_h' => (is => 'rw', isa => 'Int', lazy => 1, default => 500 );

    has 'szr_header'        => (is => 'rw', isa => 'Wx::BoxSizer', lazy_build => 1, documentation => 'vertical'     );
    has 'szr_btn_list'      => (is => 'rw', isa => 'Wx::BoxSizer', lazy_build => 1, documentation => 'vertical'     );
    has 'szr_lists'         => (is => 'rw', isa => 'Wx::BoxSizer', lazy_build => 1, documentation => 'horizontal'   );
    has 'szr_repair_out'    => (is => 'rw', isa => 'Wx::BoxSizer', lazy_build => 1, documentation => 'horizontal'   );
    has 'szr_repair_in'     => (is => 'rw', isa => 'Wx::BoxSizer', lazy_build => 1, documentation => 'horizontal'   );

    has 'btn_add'               => (is => 'rw', isa => 'Wx::Button',        lazy_build => 1     );
    has 'btn_add_all'           => (is => 'rw', isa => 'Wx::Button',        lazy_build => 1     );
    has 'btn_del'               => (is => 'rw', isa => 'Wx::Button',        lazy_build => 1     );
    has 'btn_del_all'           => (is => 'rw', isa => 'Wx::Button',        lazy_build => 1     );
    has 'btn_add_glyphs'        => (is => 'rw', isa => 'Wx::Button',        lazy_build => 1     );
    has 'btn_repair'            => (is => 'rw', isa => 'Wx::Button',        lazy_build => 1     );
    has 'lst_bldgs_onsite'      => (is => 'rw', isa => 'Wx::ListCtrl',      lazy_build => 1     );
    has 'lst_bldgs_to_repair'   => (is => 'rw', isa => 'Wx::ListCtrl',      lazy_build => 1     );
    has 'lbl_header'            => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1     );
    has 'lbl_instructions'      => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1     );

    sub BUILD {
        my $self = shift;

        $self->lst_bldgs_onsite();
        $self->populate_bldgs_list( $self->lst_bldgs_onsite );

        ### Header, instructions
        $self->szr_header->Add($self->lbl_header, 0, 0, 0);
        $self->szr_header->AddSpacer(5);
        $self->szr_header->Add($self->lbl_instructions, 0, 0, 0);

        ### Add/delete buildings buttons
        $self->szr_btn_list->AddStretchSpacer(6);
        $self->szr_btn_list->Add($self->btn_add, 1, 0, 0);
        $self->szr_btn_list->Add($self->btn_add_all, 1, 0, 0);
        $self->szr_btn_list->Add($self->btn_del, 1, 0, 0);
        $self->szr_btn_list->Add($self->btn_del_all, 1, 0, 0);
        $self->szr_btn_list->AddSpacer(4);
        $self->szr_btn_list->Add($self->btn_add_glyphs, 1, 0, 0);
        $self->szr_btn_list->AddStretchSpacer(1);

        ### Left & right lists, plus the buttons
        $self->szr_lists->Add($self->lst_bldgs_onsite, 10, 0, 0);
        $self->szr_lists->AddSpacer(5);
        $self->szr_lists->Add($self->szr_btn_list, 0, 0, 0);
        $self->szr_lists->AddSpacer(5);
        $self->szr_lists->Add($self->lst_bldgs_to_repair, 10, 0, 0);
        my $s = $self->parent->GetSize;
        $self->szr_lists->SetMinSize( Wx::Size->new($s->GetWidth - $self->btn_w, -1) );

        ### Repair button
        $self->szr_repair_in->AddStretchSpacer(8);
        $self->szr_repair_in->Add($self->btn_repair, 10, 0, 0);
        $self->szr_repair_in->AddStretchSpacer(6);
        $self->szr_repair_out->AddStretchSpacer();
        $self->szr_repair_out->Add($self->szr_repair_in, 1, wxALIGN_CENTER, 0);
        $self->szr_repair_out->AddStretchSpacer();

        ### Panel
        $self->content_sizer->Add($self->szr_header, 0, 0, 0);
        $self->content_sizer->AddSpacer(20);
        $self->content_sizer->Add($self->szr_lists, 0, 0, 0);
        $self->content_sizer->AddSpacer(20);
        $self->content_sizer->Add($self->szr_repair_out, 0, 0, 0);
        $self->content_sizer->AddSpacer(20);
        $self->content_sizer->Add($self->res_bar->szr_main, 0, 0, 0);

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
        my $tt = Wx::ToolTip->new("Glyph buildings are free to repair, so you usually want to do them first.");
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
    sub _build_btn_repair {#{{{
        my $self = shift;
        my $v = Wx::Button->new(
            $self->parent, -1, 
            q{Repair!},
            wxDefaultPosition,
            Wx::Size->new(100, 50),
        );
        $v->SetFont( $self->get_font('/bold_para_text_1') );
        my $tt = Wx::ToolTip->new("Repair all buildings listed on the right");
        $v->SetToolTip($tt);
        return $v;
    }#}}}
    sub _build_buildings {#{{{
        my $self  = shift;
        my $force = shift // 1; # default to a full refresh from the server.

=head2 _build_buildings

Pulls data on the buildings on the current planet from the server.

Avoids the cache, so every time this builder gets called, it's getting live 
data from the server, so the current and correct damage percentages can be 
shown.

If you decide you do want to call this and hit the cache for whatever reason, 
call it as

 $self->_build_buildings(0);

...this will pull the buildings data from the cache.

=cut

        my $bldgs = try {
            $self->game_client->get_buildings($self->planet_id, undef, $force);
        }
        catch {
            my $msg = (ref $_) ? $_->text : $_;
            $self->poperr($msg);
            return;
        };

        my $ret_bldgs = {};
        while( my($id, $hr) = each %{$bldgs} ) {

            next if ( $self->show_bldgs ne 'all' and $hr->{'efficiency'} == 100 );

            $hr->{'id'} = $id;
            $ret_bldgs->{$id} = $hr;
        }

        return $ret_bldgs;
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
        my $text = "Move the damaged buidings in the list on the left to the list on the right, then click Repair!

If many buildings are damaged, you may run out of resources before you can repair everything.  So it's recommended that you repair the most important buildings first, then check your resource status, then move on to the less important buidings.";

        my $y = Wx::StaticText->new(
            $self->parent, -1,
            $text,
            wxDefaultPosition, 
            Wx::Size->new(-1, 50)
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
    sub _build_res_bar {#{{{
        my $self = shift;
        my $res_bar = LacunaWaX::Generics::ResBar->new(
            app         => $self->app,
            ancestor    => $self->ancestor,
            parent      => $self->parent,
            planet_name => $self->planet_name,
            
        );
        return $res_bar;
    }#}}}
    sub _build_status {#{{{
        my $self = shift;

        my $v = LacunaWaX::Dialog::Status->new( 
            app         => $self->app,
            ancestor    => $self,
            title       => 'Repairing',
            recsep      => '-=-=-=-=-=-=-',
        );
        $v->hide;
        return $v;
    }#}}}
    sub _build_szr_header {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxVERTICAL, 'Header');
    }#}}}
    sub _build_szr_btn_list {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxVERTICAL, 'Buttons');
    }#}}}
    sub _build_szr_lists {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxHORIZONTAL, 'Lists');
    }#}}}
    sub _build_szr_repair_out {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxHORIZONTAL, 'Repair Outside');
    }#}}}
    sub _build_szr_repair_in {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxHORIZONTAL, 'Repair Inside');
    }#}}}
    sub _set_events {#{{{
        my $self = shift;
        EVT_BUTTON(         $self->parent, $self->btn_add->GetId,               sub{$self->OnAddSingle(@_)}             );
        EVT_BUTTON(         $self->parent, $self->btn_add_all->GetId,           sub{$self->OnAddAll(@_)}                );
        EVT_BUTTON(         $self->parent, $self->btn_del->GetId,               sub{$self->OnDelSingle(@_)}             );
        EVT_BUTTON(         $self->parent, $self->btn_del_all->GetId,           sub{$self->OnDelAll(@_)}                );
        EVT_BUTTON(         $self->parent, $self->btn_add_glyphs->GetId,        sub{$self->OnAddGlyphs(@_)}             );
        EVT_BUTTON(         $self->parent, $self->btn_repair->GetId,            sub{$self->OnRepair(@_)}                );
        EVT_CLOSE(          $self->parent,                                      sub{$self->OnClose(@_)}                 );
        EVT_LIST_COL_CLICK( $self->parent, $self->lst_bldgs_onsite->GetId,      sub{$self->OnLeftLstHeaderClick(@_)}    );
        EVT_LIST_COL_CLICK( $self->parent, $self->lst_bldgs_to_repair->GetId,   sub{$self->OnRightLstHeaderClick(@_)}   );
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

Inserts a properly-formated row to the indicated list.  Remember that "insert" 
means "adds to the top of the list".

 $self->add_row(
    $self->some_ListCtrl,
    "building name",
    "x coord",
    "y coord",
    "damage (integer percent)",
 );

Note that you must send damage, not efficiency.  The game server hands us back 
efficiency percent (eg "percent undamaged").  So if you're working with a 
server reply, get damage by:

  $damage = 100 - $bldg_hr->{'efficiency'}

All strings passed in will be trimmed of whitespace (front and back).  $damage 
will also have any % signs stripped.

Returns the index of the row just added, which will always be 0 since we're 
inserting.

=cut

        $name   = $self->str_trim($name);
        $x      = $self->str_trim($x);
        $y      = $self->str_trim($y);
        $damage = $self->str_trim($damage);
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
    sub clear_list {#{{{
        my $self = shift;
        my $list = shift;

=head2 clear_list 

Removes all elements from a list, leaving it empty.  Unlike ListCtrl's ClearAll 
method, which completely clears the thing, including its headers and column 
assignments, this simply removes the list items, leaving the headers and column 
assignments intact.

 $self->clear_list( $self->lst_object );

=cut

        while( 1 ) {
            my $row = -1;
            $row = $list->GetNextItem($row, wxLIST_NEXT_ALL, wxLIST_STATE_DONTCARE);
            last if $row == -1;
            $list->DeleteItem( $row );
        }
        return 1;
    }#}}}
    sub list_sort_alpha {#{{{
        my $self = shift;
        my $ay   = shift;
        my $bee  = shift;
        my $list = shift;
        my $col  = shift;

        ### Since there's a good chance for lots of dupes (mainly spaceports), 
        ### include secondary and tertiary sorts on x and y coords.
        ###
        ### Passing in $col is a bit silly here, since there's only a single 
        ### column that can be sorted alpha.

        my $i1_off = $list->FindItemData(-1, $ay);
        my $i2_off = $list->FindItemData(-1, $bee);
        my $i1 = $list->GetItem($i1_off, $col);
        my $i2 = $list->GetItem($i2_off, $col);
        my $n1 = $self->str_trim( $i1->GetText );
        my $n2 = $self->str_trim( $i2->GetText );

        my $ix1 = $list->GetItem($i1_off, 1);
        my $ix2 = $list->GetItem($i2_off, 1);
        my $nx1 = $self->str_trim( $ix1->GetText );
        my $nx2 = $self->str_trim( $ix2->GetText );

        my $iy1 = $list->GetItem($i1_off, 2);
        my $iy2 = $list->GetItem($i2_off, 2);
        my $ny1 = $self->str_trim( $iy1->GetText );
        my $ny2 = $self->str_trim( $iy2->GetText );

        my $rv = ( ($n1 cmp $n2) or ($nx1 <=> $nx2) or ($ny2 <=> $ny2) );
        return $rv;
    }#}}}
    sub list_sort_num {#{{{
        my $self = shift;
        my $ay   = shift;
        my $bee  = shift;
        my $list = shift;
        my $col  = shift;
        my $rev  = shift;   # flag - if true, reverse sort.

        ### If we're sorting by either the x or y coordinate, we want to do a 
        ### secondary sort on the other coordinate.  But it's also possible to 
        ### enter this sort on the damage column, in which case we want no 
        ### secondary sort.
        my $col2 = ($col == 1)
            ? 2 :  ($col == 2)
            ? 1 :  undef;

        my $i1_off = $list->FindItemData(-1, $ay);
        my $i2_off = $list->FindItemData(-1, $bee);
        my $i1 = $list->GetItem($i1_off, $col);
        my $i2 = $list->GetItem($i2_off, $col);
        my $n1 = $self->str_trim( $i1->GetText );
        my $n2 = $self->str_trim( $i2->GetText );

        my $dat_1_1 = $n1 =~ s/[\s%]+//gr;
        my $dat_1_2 = $n2 =~ s/[\s%]+//gr;

        ### NOTE
        ### Damage is the only column that needs to do a reverse sort, and it 
        ### doesn't do a sub-sort.  So there's nothing in the sub-sort 
        ### condition below that's even looking at the $rev flag.

        my $rv;
        if( defined $col2 ) {
            $i1 = $list->GetItem($i1_off, $col2);
            $i2 = $list->GetItem($i2_off, $col2);
            $n1 = $self->str_trim( $i1->GetText );
            $n2 = $self->str_trim( $i2->GetText );
            my $dat_2_1 = $n1 =~ s/[\s%]+//gr;
            my $dat_2_2 = $n2 =~ s/[\s%]+//gr;
            $rv = ( ($dat_1_1 <=> $dat_1_2) or ($dat_2_1 <=> $dat_2_2) );
        }
        else {
            if( $rev ) {
                ($dat_1_1, $dat_1_2) = ($dat_1_2, $dat_1_1);
            }
            $rv = $dat_1_1 <=> $dat_1_2;
        }

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
    sub repair {#{{{
        my $self = shift;
        my($name, $x, $y) = @_;

=head2 repair

Attempts to repair the given building.  Throws exception if the building was 
not found or if it was found but the repair attempt failed (probably because 
of a lack of resources).

CHECK
I have not tested the "fails if we're out of res" yet.

 $self->repair( $name, $x, $y );

=cut

        foreach my $id( $self->bldg_ids ) {
            my $hr = $self->get_bldg($id);
            next unless ($hr->{'name'} eq $name and $hr->{'x'} eq $x and $hr->{'y'} eq $y);

            my $obj = $self->game_client->get_building_object(
                $self->planet_id,
                $hr,
            );

            ### This should explode if we're out of res.  That's OK - this 
            ### method should be in a try/catch.
            my $rv = $obj->repair;
            return $rv;
        }

        die "Building '$name' was not found!\n";
    }#}}}
    sub status_say {#{{{
        my $self = shift;
        my $msg  = shift;
        if( $self->has_status ) {
            try{ $self->status->say($msg) };
        }
        return 1;
    }#}}}
    sub status_say_recsep {#{{{
        my $self = shift;
        if( $self->has_status ) {
            try{ $self->status->say_recsep };
        }
        return 1;
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

        my @glyph_rows = ();

        my $row = -1;
        while( 1 ) {
            $row = $self->lst_bldgs_onsite->GetNextItem($row, wxLIST_NEXT_ALL, wxLIST_STATE_DONTCARE);
            last if $row == -1;

            my $itm = $self->lst_bldgs_onsite->GetItem($row);
            my $name = $self->str_trim( $itm->GetText );
            if( $self->find_glyph_bldg(sub{$_ eq lc $name}) ) {
                my $x = $self->str_trim( $self->lst_bldgs_onsite->GetItem($row, 1)->GetText );
                my $y = $self->str_trim( $self->lst_bldgs_onsite->GetItem($row, 2)->GetText );
                my $d = $self->str_trim( $self->lst_bldgs_onsite->GetItem($row, 3)->GetText );
                unshift @glyph_rows, [$name, $x, $y, $d];

                $self->lst_bldgs_onsite->DeleteItem( $row );
                $row--; # since we just deleted one, back up or we'll skip the next one if two are consecutive.
            }
        }

        foreach my $r(@glyph_rows) {
            $self->add_row( $self->lst_bldgs_to_repair, @{$r} );
        }
            
        return 1;
    }#}}}
    sub OnClose {#{{{
        my $self = shift;

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

        $self->clear_list($self->lst_bldgs_to_repair);
        $self->populate_bldgs_list( $self->lst_bldgs_onsite );
        return 1;
    }#}}}
    sub OnLeftLstHeaderClick {#{{{
        my $self    = shift;
        my $parent  = shift;    # Wx::ScrolledWindow
        my $event   = shift;    # Wx::ListEvent

        given($event->GetColumn) {  # zero-based integer offset
            when(0) {   # name
                $self->lst_bldgs_onsite->SortItems( sub{$self->list_sort_alpha(@_, $self->lst_bldgs_onsite, 0)} );
            }
            when(1) {   # X
                my $rv = $self->lst_bldgs_onsite->SortItems( sub{$self->list_sort_num(@_, $self->lst_bldgs_onsite, 1)} );
            }
            when(2) {   # Y
                my $rv = $self->lst_bldgs_onsite->SortItems( sub{$self->list_sort_num(@_, $self->lst_bldgs_onsite, 2)} );
            }
            when(3) {   # Damage (reverse sort)
                my $rv = $self->lst_bldgs_onsite->SortItems( sub{$self->list_sort_num(@_, $self->lst_bldgs_onsite, 3, 1)} );
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
            when(0) {   # name
                $self->lst_bldgs_to_repair->SortItems( sub{$self->list_sort_alpha(@_, $self->lst_bldgs_to_repair, 0)} );
            }
            when(1) {   # x
                my $rv = $self->lst_bldgs_to_repair->SortItems( sub{$self->list_sort_num(@_, $self->lst_bldgs_to_repair, 1)} );
            }
            when(2) {   # y
                my $rv = $self->lst_bldgs_to_repair->SortItems( sub{$self->list_sort_num(@_, $self->lst_bldgs_to_repair, 2)} );
            }
            when(3) {   # Damage (reverse sort)
                my $rv = $self->lst_bldgs_to_repair->SortItems( sub{$self->list_sort_num(@_, $self->lst_bldgs_to_repair, 3, 1)} );
            }
            default {
                my $rv = $self->lst_bldgs_to_repair->SortItems( sub{$self->list_sort_alpha(@_, $self->lst_bldgs_to_repair, 0)} );
            }
        }

        $event->Skip;
    }#}}}
    sub OnRepair {#{{{
        my $self    = shift;
        my $parent  = shift;    # Wx::ScrolledWindow
        my $event   = shift;    # Wx::CommandEvent

        ### Reset this on each re-entry to this handler.
        $self->flg_stop(0);

        my $partial = 0;
        $self->status->show;
        while( 1 ) {
            my $row = -1;
            $row = $self->lst_bldgs_to_repair->GetNextItem($row, wxLIST_NEXT_ALL, wxLIST_STATE_DONTCARE);
            last if $row == -1;
            last if $self->flg_stop;

            my $name = $self->str_trim( $self->lst_bldgs_to_repair->GetItem($row)->GetText );
            my $x    = $self->str_trim( $self->lst_bldgs_to_repair->GetItem($row, 1)->GetText );
            my $y    = $self->str_trim( $self->lst_bldgs_to_repair->GetItem($row, 2)->GetText );

            $self->lst_bldgs_to_repair->DeleteItem( $row );
            $self->status_say("Repairing $name ($x,$y)...");

            my $rv = try {
                $self->repair($name, $x, $y);
            }
            catch {
                my $msg = (ref $_) ? $_->text : $_;

                unless( $msg =~ /Not enough resources/ ) {
                    ### The 'not enough resources' is something we're 
                    ### expecting and dealing with below.  If we get any other 
                    ### error, we want it displayed.
                    $self->status_say("Attempt to repair '$name' at ($x, $y) failed: $msg");
                }

                return;
            };

            if( ! $rv ) {
                $self->status_say("...$name could not be repaired at all - not enough resources.");
                $partial = 1;
            }
            else {
                my $eff = $rv->{'building'}{'efficiency'};
                if( $eff < 100 ) {
                    $self->status_say("...$name partially repaired to ${eff}%.  Not enough resources for a full repair.");
                    $partial = 1;
                }
                else {
                    $self->status_say("...$name repaired!");
                }
            }
            $self->status_say("");
        }

        ### If the user canceled the repair loop by closing the status window, 
        ### this flag will be on.  Turn it off so the next run of the loop 
        ### will continue until it finishes or the user cancels it again.
        $self->flg_stop(0);

        $self->clear_list($self->lst_bldgs_to_repair);
        $self->clear_list($self->lst_bldgs_onsite);
        $self->clear_buildings;
        $self->_build_buildings(1); 
        $self->populate_bldgs_list( $self->lst_bldgs_onsite );
        $self->res_bar->update_res;

        $self->status_say_recsep;
        $self->status_say("");

        if( $partial ) {
            $self->status_say("We've repaired as much as possible before running out of resources.  You'll need to return later after your res builds back up to complete all repairs.");
        }
        else {
            $self->status_say("All requested buildings have been repaired.");
        }
        $self->status_say("");
        $self->status_say("You may close this window.");

        return 1;
    }#}}}
    sub OnDialogStatusClose {#{{{
        my $self    = shift;
        my $status  = shift;    # LacunaWaX::Dialog::Status

        ### This is not a true event.  It gets called explicitly by 
        ### Dialog::Status's OnClose event.
        ###
        ### I'd prefer to set some sort of an event, but am not sure exactly how 
        ### to do that.  So for now, the sitter voting loop just has many "if 
        ### $self->stop_voting ..." conditions to emulate an event.

        if( $self->has_status ) {
            $self->clear_status;
        }
        $self->flg_stop(1);
        return 1;
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

