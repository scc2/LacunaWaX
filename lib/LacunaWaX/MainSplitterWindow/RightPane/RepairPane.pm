

=pod

I haven't sussed out ListCtrl sorting yet.  The general take online appears to 
be that, not only is sorting difficult, but the entire ListCtrl control is 
awul to deal with (I'm glad I'm not alone).

There's a directory of Python examples on the desktop at work.  There should 
be an example of ListCtrl sorting in there that I can use to figure out.

If not, I'm going to need my own sorting methods that don't use ListCtrl's 
SortItems.

Instead, it'll have to:
    - Read all the items into an AoH
    - Clear out the ListCtrl
    - Sort the AoH as needed
    - REVERSE the Array
    - Add (insert) the items back into the ListCtrl

    This might end up being easier than farting around with SortItems.

=cut



package LacunaWaX::MainSplitterWindow::RightPane::RepairPane {
    use v5.14;
    use Data::Dumper;
    use LacunaWaX::Model::Client;
    use List::Util qw(first);
    use Moose;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_BUTTON);
    with 'LacunaWaX::Roles::MainSplitterWindow::RightPane';

    has 'sizer_debug'   => (is => 'rw', isa => 'Int', lazy => 1, default => 0);

    has 'status' => (
        is => 'rw',
        isa => 'LacunaWaX::Dialog::Status', 
        lazy_build => 1,
        documentation => q{
            This is just for debugging and can go away.
        }
    );

    has 'show_buildings' => (
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

    has 'damaged_sort_state' => (
        is      => 'rw',
        isa     => 'Str',
        lazy    => 1,
        default => 'name',
        documentation => q{
            Determines how the list is currently sorted
        },
    );

    has 'repair_sort_state' => (
        is      => 'rw',
        isa     => 'Str',
        lazy    => 1,
        default => 'name',
        documentation => q{
            Determines how the list is currently sorted
        },
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

    has 'btn_w' => (is => 'rw', isa => 'Int', lazy => 1, default => 40);
    has 'btn_h' => (is => 'rw', isa => 'Int', lazy => 1, default => 20);
    has 'lst_w' => (is => 'rw', isa => 'Int', lazy => 1, default => 25);
    has 'lst_h' => (is => 'rw', isa => 'Int', lazy => 1, default => 500);

    has 'szr_header'    => (is => 'rw', isa => 'Wx::BoxSizer', lazy_build => 1, documentation => 'vertical'     );
    has 'szr_btn_list'  => (is => 'rw', isa => 'Wx::BoxSizer', lazy_build => 1, documentation => 'vertical'     );
    has 'szr_lists'     => (is => 'rw', isa => 'Wx::BoxSizer', lazy_build => 1, documentation => 'horizontal'   );

    has 'btn_add'               => (is => 'rw', isa => 'Wx::Button',        lazy_build => 1     );
    has 'btn_add_all'           => (is => 'rw', isa => 'Wx::Button',        lazy_build => 1     );
    has 'btn_del'               => (is => 'rw', isa => 'Wx::Button',        lazy_build => 1     );
    has 'btn_del_all'           => (is => 'rw', isa => 'Wx::Button',        lazy_build => 1     );
    has 'lst_bldgs_onsite'      => (is => 'rw', isa => 'Wx::ListCtrl',      lazy_build => 1     );
    has 'lst_bldgs_to_repair'   => (is => 'rw', isa => 'Wx::ListCtrl',      lazy_build => 1     );
    has 'lbl_header'            => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1     );
    has 'lbl_instructions'      => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1     );

    sub BUILD {
        my $self = shift;

        $self->lst_bldgs_onsite();
        $self->populate_bldgs_list();

        $self->szr_header->Add($self->lbl_header, 0, 0, 0);
        $self->szr_header->AddSpacer(5);
        $self->szr_header->Add($self->lbl_instructions, 0, 0, 0);

        $self->szr_btn_list->AddStretchSpacer(6);
        $self->szr_btn_list->Add($self->btn_add, 1, 0, 0);
        $self->szr_btn_list->Add($self->btn_add_all, 1, 0, 0);
        $self->szr_btn_list->Add($self->btn_del, 1, 0, 0);
        $self->szr_btn_list->Add($self->btn_del_all, 1, 0, 0);
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

        unless( $self->show_buildings eq 'all' ) {
            my $ret_bldgs = {};
            while( my($id, $hr) = each %{$bldgs} ) {
                $ret_bldgs->{$id} = $hr if( $hr->{'efficiency'} < 100 );
            }
            $bldgs = $ret_bldgs;
        }

        return $bldgs;
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
        EVT_BUTTON( $self->parent, $self->btn_add->GetId,       sub{$self->OnAddSingle(@_)}  );
        EVT_BUTTON( $self->parent, $self->btn_add_all->GetId,   sub{$self->OnAddAll(@_)}  );
        EVT_BUTTON( $self->parent, $self->btn_del->GetId,       sub{$self->OnDelSingle(@_)}  );
        EVT_BUTTON( $self->parent, $self->btn_del_all->GetId,   sub{$self->OnDelAll(@_)}  );
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

        my $itm_name = Wx::ListItem->new();
        $itm_name->SetText( $name );
        my $row_idx = $list->InsertItem($itm_name);
        $list->SetItem( $row_idx, 1, sprintf("%2d", $x) );
        $list->SetItem( $row_idx, 2, sprintf("%2d", $y) );
        $list->SetItem( $row_idx, 3, sprintf("%3d%%", $damage) );
        return $row_idx;
    }#}}}
    sub byname_rev {#{{{
        my $self = shift;
        $self->buildings->{$b}->{'name'} cmp $self->buildings->{$a}->{'name'};
    }#}}}
    sub populate_bldgs_list {#{{{
        my $self = shift;

        ### Each insert goes _above_ the previous item, so start with a 
        ### reverse sort.
        foreach my $bldg_id( sort{$self->byname_rev}$self->bldg_ids ) {
            my $bldg_hr = $self->get_bldg($bldg_id);
            $self->add_row(
                $self->lst_bldgs_onsite,
                $bldg_hr->{'name'},
                $bldg_hr->{'x'},
                $bldg_hr->{'y'},
                (100 - $bldg_hr->{'efficiency'}),
            );
        }
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

        my @rows = ();

        while( 1 ) {
            my $row = -1;
            $row = $self->lst_bldgs_onsite->GetNextItem($row, wxLIST_NEXT_ALL, wxLIST_STATE_DONTCARE);
            last if $row == -1;

            my $name    = $self->lst_bldgs_onsite->GetItem($row, 0)->GetText;
            my $x       = $self->lst_bldgs_onsite->GetItem($row, 1)->GetText;
            my $y       = $self->lst_bldgs_onsite->GetItem($row, 2)->GetText;
            my $damage  = $self->lst_bldgs_onsite->GetItem($row, 3)->GetText;

            ### Unshift so they'll be in @rows backwards
            unshift( @rows, [$name, $x, $y, $damage] );

            $self->lst_bldgs_onsite->DeleteItem( $row );
        }

        ### Each new row gets added ABOVE the previous row.  Since @rows is 
        ### currently the reverse of what's showing in the left ListCtrl, this 
        ### will display correctly.
        for my $row(@rows) {
            $self->add_row(
                $self->lst_bldgs_to_repair,
                $row->[0],
                $row->[1],
                $row->[2],
                $row->[3],
            );
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

        my @rows = ();

        while( 1 ) {
            my $row = -1;
            $row = $self->lst_bldgs_to_repair->GetNextItem($row, wxLIST_NEXT_ALL, wxLIST_STATE_DONTCARE);
            last if $row == -1;

            my $name    = $self->lst_bldgs_to_repair->GetItem($row, 0)->GetText;
            my $x       = $self->lst_bldgs_to_repair->GetItem($row, 1)->GetText;
            my $y       = $self->lst_bldgs_to_repair->GetItem($row, 2)->GetText;
            my $damage  = $self->lst_bldgs_to_repair->GetItem($row, 3)->GetText;

            unshift( @rows, [$name, $x, $y, $damage] );
            $self->lst_bldgs_to_repair->DeleteItem( $row );
        }

        for my $row(@rows) {
            $self->add_row(
                $self->lst_bldgs_onsite,
                $row->[0],
                $row->[1],
                $row->[2],
                $row->[3],
            );
        }

        return 1;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;
