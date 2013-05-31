
### Lineage:
###     ancestor: RightPane.pm
###     ancestor->ancestor: MainSplitterWindow.pm

package LacunaWaX::MainSplitterWindow::RightPane::GlyphsPane {
    use v5.14;
    use Moose;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_BUTTON EVT_LIST_ITEM_SELECTED EVT_ENTER_WINDOW);
    with 'LacunaWaX::Roles::MainSplitterWindow::RightPane';

    use LacunaWaX::MainSplitterWindow::RightPane::GlyphsPane::RecipeForm;

    has 'sizer_debug' => (is => 'rw', isa => 'Int',  lazy => 1, default => 0);

    has 'planet_name'   => (is => 'rw', isa => 'Str', required => 1     );
    has 'planet_id'     => (is => 'rw', isa => 'Int', lazy_build => 1   );

    has 'has_arch_min'  => (is => 'rw', isa => 'Int', lazy => 1,        default => 1,
        documentation => q{Set to false by call to _build_list_glyphs if no AM is found}
    );

    has 'prefs_rec'     => (is => 'rw', isa => 'Maybe[LacunaWaX::Model::Schema::ArchMinPrefs]', lazy_build => 1,
        documentation => q{
            The DBIC record object from the ArchMinPrefs table for this body on this server.
            Undef if the user hasn't set up preferences for this body yet.
        }
    );

    has 'dialog_status' => (
        is          => 'rw',
        isa         => 'LacunaWaX::Dialog::Status',
        predicate   => 'has_dialog_status',
        clearer     => 'clear_dialog_status',
        documentation => q{
            This attribute is a bit of an odd case, and cannot be lazy or have a 
            builder method defined.
            See the explanation in _make_dialog_status(), below.
        }
    );

    has 'halls_btn_sizer'   => (is => 'rw', isa => 'Wx::BoxSizer',  lazy_build => 1, documentation => 'horizontal');
    has 'header_sizer'      => (is => 'rw', isa => 'Wx::BoxSizer',  lazy_build => 1, documentation => 'vertcal');
    has 'list_sizer'        => (is => 'rw', isa => 'Wx::BoxSizer',  lazy_build => 1, documentation => 'vertcal');
    has 'lbl_planet_name'   => (is => 'rw', isa => 'Wx::StaticText',        lazy_build => 1);
    has 'list_glyphs'       => (is => 'rw', isa => 'Maybe[Wx::ListCtrl]',   lazy_build => 1);
    has 'glyph_pusher_box'  => (is => 'rw', isa => 'Wx::BoxSizer', lazy_build => 1);
    has 'chc_glyph_home'    => (is => 'rw', isa => 'Wx::Choice',   lazy_build => 1);
    has 'txt_pusher_ship'   => (is => 'rw', isa => 'Wx::TextCtrl', lazy_build => 1);
    has 'btn_push_glyphs'   => (is => 'rw', isa => 'Wx::Button',   lazy_build => 1);
    has 'auto_search_box'   => (is => 'rw', isa => 'Wx::BoxSizer',  lazy_build => 1);
    has 'chc_auto_search'   => (is => 'rw', isa => 'Wx::Choice',    lazy_build => 1);
    has 'btn_auto_search'   => (is => 'rw', isa => 'Wx::Button',    lazy_build => 1);
    has 'btn_build_all_halls' => (is => 'rw', isa => 'Wx::Button', lazy_build => 1);

    has 'recipe_box'    => (is => 'rw', isa => 'Wx::BoxSizer',  lazy_build => 1);
    has 'recipe_forms'  => (is => 'rw', isa => 'ArrayRef',      lazy_build => 1);

    sub BUILD {
        my $self = shift;

        ### See comments in the method as to why it's '_make', not '_build'.
        $self->dialog_status( $self->_make_dialog_status );

        $self->header_sizer->Add($self->lbl_planet_name, 0, 0, 0);
        $self->list_sizer->Add($self->list_glyphs, 0, 0, 0);

        $self->content_sizer->Add($self->header_sizer, 0, 0, 0);
        $self->content_sizer->Add($self->list_sizer, 0, 0, 0);
        $self->content_sizer->AddSpacer(20);

        $self->content_sizer->Add($self->glyph_pusher_box, 0, 0, 0);
        $self->content_sizer->AddSpacer(20);

        $self->content_sizer->Add($self->auto_search_box, 0, 0, 0);
        $self->content_sizer->AddSpacer(20);

        $self->prep_halls_btn_sizer;
        $self->recipe_box->AddSpacer(10);
        $self->recipe_box->Add($self->halls_btn_sizer, 0, 0, 0);
        $self->recipe_box->AddSpacer(20);

        foreach my $rname( sort keys %{$self->game_client->glyph_recipes} ) {
            my $form = LacunaWaX::MainSplitterWindow::RightPane::GlyphsPane::RecipeForm->new(
                app                 => $self->app,
                parent              => $self->parent,
                ancestor            => $self,
                recipe_name         => $rname,
                recipe_ingredients  => $self->game_client->glyph_recipes->{$rname},
            );
            $self->recipe_box->Add($form->main_sizer, 0, 0, 0);
        }
        $self->content_sizer->Add($self->recipe_box, 0, 0, 0);
        $self->refocus_window_name( 'lbl_planet_name' );
        return $self;
    }
    sub _build_auto_search_box {#{{{
        my $self = shift;

        my $box = Wx::StaticBox->new(
            $self->parent, -1, 
            'ArchMin Should Auto Search For', 
            wxDefaultPosition, 
            #wxDefaultSize, 
            Wx::Size->new(-1, 40)
        );
        my $sizer = Wx::StaticBoxSizer->new($box, wxHORIZONTAL);

        $sizer->Add($self->chc_auto_search, 0, 0, 0);
        $sizer->AddSpacer(10);
        $sizer->Add($self->btn_auto_search, 0, 0, 0);

        return $sizer;
    }#}}}
    sub _build_btn_auto_search {#{{{
        my $self = shift;
        my $v = Wx::Button->new($self->parent, -1, "Set Auto Search");
        $v->SetFont( $self->get_font('/para_text_1') );
        return $v;
    }#}}}
    sub _build_btn_build_all_halls {#{{{
        my $self = shift;
        my $v = Wx::Button->new($self->parent, -1, "Build as Many Halls as Possible");
        $v->SetFont( $self->get_font('/para_text_1') );
        return $v;
    }#}}}
    sub _build_btn_push_glyphs {#{{{
        my $self = shift;
        my $v = Wx::Button->new($self->parent, -1, "Set Glyph Push");
        $v->SetFont( $self->get_font('/para_text_1') );
        return $v;
    }#}}}
    sub _build_chc_auto_search {#{{{
        my $self = shift;

        my $ore_types = $self->game_client->ore_types;
        my $selection_ss = 0;

        my $schema = $self->get_main_schema;
        if( $self->prefs_rec ) {
            my $cnt = 0;
            for my $o(@{$ore_types}) {
                ### Yeah, increment first.  The selection subscript has to be 
                ### one greater than the position in @sorted_planets, because 
                ### we're hardcoding 'None' on the front of the select box.
                $cnt++;
                if( $self->prefs_rec and $self->prefs_rec->auto_search_for and $o eq $self->prefs_rec->auto_search_for ) {
                    $selection_ss = $cnt;
                }
            }
        }

        my $v = Wx::Choice->new(
            $self->parent, -1, 
            wxDefaultPosition, 
            Wx::Size->new(110, 25), 
            ['None', @{$ore_types}],
        );
        $v->SetSelection($selection_ss);
        $v->SetFont( $self->get_font('/para_text_1') );
        return $v;
    }#}}}
    sub _build_chc_glyph_home {#{{{
        my $self = shift;

        my %planets_by_id = reverse %{$self->game_client->planets};

        my $schema = $self->get_main_schema;
        foreach my $id( keys %planets_by_id ) {
            ### Get SSs out of the dropdown
            if( my $rec = $schema->resultset('BodyTypes')->find({body_id => $id, type_general => 'space station'}) ) {
                delete $planets_by_id{$id};
            }
        }
        my @sorted_planets = sort values %planets_by_id;

        my $selection_ss = 0;
        if( $self->prefs_rec ) {
            my $glyph_home_name;
            if( $self->prefs_rec->glyph_home_id ) {
                $glyph_home_name = $planets_by_id{ $self->prefs_rec->glyph_home_id };
            }

            my $cnt = 0;
            for my $p(@sorted_planets) {
                ### Yeah, increment first.  The selection subscript has to be 
                ### one greater than the position in @sorted_planets, because 
                ### we're hardcoding 'None' on the front of the select box.
                $cnt++;
                if( $glyph_home_name and $p eq $glyph_home_name ) {
                    $selection_ss = $cnt;
                }
            }
        }

        my $v = Wx::Choice->new(
            $self->parent, -1, 
            wxDefaultPosition, 
            Wx::Size->new(110, 25), 
            ['None', @sorted_planets],
        );
        $v->SetSelection($selection_ss);
        $v->SetFont( $self->get_font('/para_text_1') );
        return $v;
    }#}}}
    sub _build_glyph_pusher_box {#{{{
        my $self = shift;

        my $box = Wx::StaticBox->new(
            $self->parent, -1, 
            'Push Collected Glyphs', 
            wxDefaultPosition, 
            Wx::Size->new(-1, 40),
        );
        my $sizer = Wx::StaticBoxSizer->new($box, wxHORIZONTAL);

        my $lbl_glyph_home = Wx::StaticText->new(
            $self->parent, -1, 
            "Destination planet: ",
            wxDefaultPosition, 
            Wx::Size->new(120, 30)
        );
        $lbl_glyph_home->SetFont( $self->get_font('/para_text_1') );

        my $lbl_pusher_ship = Wx::StaticText->new(
            $self->parent, -1, 
            "Ship name: ",
            wxDefaultPosition, 
            Wx::Size->new(90, 30)
        );
        $lbl_pusher_ship->SetFont( $self->get_font('/para_text_1') );

        $sizer->Add($lbl_glyph_home, 0, 0, 0);
        $sizer->Add($self->chc_glyph_home, 0, 0, 0);
        $sizer->AddSpacer(15);
        $sizer->Add($lbl_pusher_ship, 0, 0, 0);
        $sizer->Add($self->txt_pusher_ship, 0, 0, 0);
        $sizer->AddSpacer(10);
        $sizer->Add($self->btn_push_glyphs, 0, 0, 0);

        return $sizer;
    }#}}}
    sub _build_halls_btn_sizer {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxHORIZONTAL, 'All Halls');
    }#}}}
    sub _build_header_sizer {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxVERTICAL, 'Header');
    }#}}}
    sub _build_lbl_planet_name {#{{{
        my $self = shift;
        my $v = Wx::StaticText->new(
            $self->parent, -1, 
            'Glyphs on ' . $self->planet_name, 
            wxDefaultPosition, 
            Wx::Size->new(640, 40)
        );
        $v->SetFont( $self->get_font('/header_1') );
        return $v;
    }#}}}
    sub _build_list_glyphs {#{{{
        my $self = shift;
        $self->throb();
        $self->yield;

        my $sorted_glyphs = try {
            $self->game_client->get_glyphs($self->planet_id);
        }
        catch {
            $self->poperr($_->text);
            return;
        };

        unless($sorted_glyphs) {
            ### False return means no arch min.
            $self->has_arch_min(0);
            return;
        }

        ### Create glyphs list ctrl
        my $list_ctrl = Wx::ListCtrl->new(
            $self->parent, -1, 
            wxDefaultPosition, 
            Wx::Size->new(350,400), 
            wxLC_REPORT
            |wxSUNKEN_BORDER
            |wxLC_SINGLE_SEL
        );
        $list_ctrl->InsertColumn(0, q{});
        $list_ctrl->InsertColumn(1, 'Name');
        $list_ctrl->InsertColumn(2, 'Quantity');
        $list_ctrl->SetColumnWidth(0,75);
        $list_ctrl->SetColumnWidth(1,125);
        $list_ctrl->SetColumnWidth(2,100);
        $list_ctrl->Arrange(wxLIST_ALIGN_TOP);
        $list_ctrl->AssignImageList( $self->app->build_img_list_glyphs, wxIMAGE_LIST_SMALL );
        $self->yield;

        ### Add glyphs to the listctrl
        my $row = 0;
        foreach my $hr( @{$sorted_glyphs} ) {#{{{
            ### $row is also the offset of the image in the ImageList, provided 
            ### @sorted_glyphs is a sorted list of all glyphs.
            my $row_idx = $list_ctrl->InsertImageItem($row, $row);
            $list_ctrl->SetItem($row_idx, 1, $hr->{name});
            $list_ctrl->SetItem($row_idx, 2, $hr->{quantity});
            $row++;
            $self->yield;
        }#}}}

        $list_ctrl->SetFont( $self->get_font('/para_text_1') );

        $self->endthrob();
        return $list_ctrl;
    }#}}}
    sub _build_list_sizer {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxVERTICAL, 'Glyphs List');
    }#}}}
    sub _build_planet_id {#{{{
        my $self = shift;
        return $self->game_client->planet_id( $self->planet_name );
    }#}}}
    sub _build_prefs_rec {#{{{
        my $self = shift;

        my $schema = $self->get_main_schema;
        if( my $rec = $schema->resultset('ArchMinPrefs')->find_or_create(
            {
                server_id   => $self->get_connected_server->id,
                body_id     => $self->planet_id,
            },
            {
                key => 'one_per_body'
            }
        )) {
            return $rec;
        }

        return 0;
    }#}}}
    sub _build_recipe_box {#{{{
        my $self = shift;

        my $box = Wx::StaticBox->new(
            $self->parent, -1, 
            'Cook Glyph Recipes', 
            wxDefaultPosition, 
            wxDefaultSize, 
        );
        return Wx::StaticBoxSizer->new($box, wxVERTICAL);
    }#}}}
    sub _build_txt_pusher_ship {#{{{
        my $self = shift;

        my $shipname = ( $self->prefs_rec and $self->prefs_rec->pusher_ship_name ) ? $self->prefs_rec->pusher_ship_name : q{};
        my $v = Wx::TextCtrl->new(
            $self->parent, -1, 
            $shipname, 
            wxDefaultPosition, 
            Wx::Size->new(150,25)
        );

        my $tt = Wx::ToolTip->new( "A ship with whatever name you type here must exist on this planet and be available, or the push will simply not happen.  Capitalization and spelling DO matter here!");
        $v->SetToolTip($tt);

        return $v;
    }#}}}
    sub _make_dialog_status {#{{{
        my $self = shift;

=head2 _make_dialog_status

Not a true Moose builder.

The problem here is:
    - This cannot be a regular builder, as that would be called before the 
      GlyphsPane object is fully built, and before that GlyphsPane object has 
      its ->app attribute set.  Since that attribute is required by this method, 
      making this a regular builder blows up.

    - So make this lazy!
        - I had it that way originally.

        - The problem with that is, if the user closes the dialog status window 
          during the Glyph cooking loop (during build all halls), $something is 
          re-referencing dialog_status, causing its lazy build sub to be 
          re-called and creating a brand new (un-shown) dialog status window.  I 
          can't find what's making that call.  But the result is that, after the 
          user closes the window, the Glyph cooking loop just continues doing 
          what it was doing, and I want that to stop.

            - That loop _is_ checking $self->has_dialog_status, but since that 
              $something is re-creating dialog_status, has_dialog_status always 
              returns true.

            - Note that the whole OnClose chain is being followed properly, and 
              the original dialog_status attribute is being disposed of as it 
              should; that's not the problem.

            - The problem is that, after the original dialog_status attribute is 
              cleared, something else is touching $self->dialog_status, calling 
              its lazy_build method and recreating the @%$ thing where I don't 
              want it recreated.

    - So what I need is a semi-lazy builder method.
        - this semi-lazy method needs to be called after $self (the GlyphsPane 
          object) is fully created, but NOT auto-called every time somebody 
          mentions $self->dialog_status.
          
          - I found some forum postings indicating this sort of thing may be in 
            a future version of Moose, but it's not there now.

    - SO, what I've ended up with is:
        - The dialog_status attribute is defined but with no builder method.  
        - This pseudo-builder (_make_dialog_status), which you're reading about 
          right now, must therefore be called explicitly when you want to create 
          a Dialog::Status window.
        - And since this is not a true builder, you must assign the rv of this 
          method to the dialog_status attribute.

    - So I named this /^_make/ rather than /^_build/ since this method works 
      differently from real builders and I'm trying to cut down on confusion.

    - True Builder:
        - $obj->_build_dialog_status;
            - $obj->dialog_status now contains the rv of _build_dialog_status().

    - This ersatz builder:
        - $obj->_make_dialog_status;
            - $obj->dialog_status CONTAINS NOTHING - doing this is WRONG.

        - $obj->dialog_status( $obj->_make_dialog_status );
            - NOW $obj->dialog_status contains the rv of _make_dialog_status().
            - doing it this way is RIGHT.

=cut

        return LacunaWaX::Dialog::Status->new( 
            app         => $self->app,
            ancestor    => $self,
            title       => 'Building all halls',
            recsep      => '-=-=-=-=-=-=-',
        );
    }#}}}
    sub _set_events {#{{{
        my $self = shift;
        if( $self->list_glyphs ) {
            ### This won't hit on a body w/o an arch min.
            EVT_LIST_ITEM_SELECTED( $self->parent, $self->list_glyphs->GetId,   sub{$self->OnListSelect(@_)} );
        }
        EVT_BUTTON(         $self->parent, $self->btn_push_glyphs->GetId,       sub{$self->OnSetGlyphPush(@_)}  );
        EVT_BUTTON(         $self->parent, $self->btn_auto_search->GetId,       sub{$self->OnSetAutoSearch(@_)} );
        EVT_BUTTON(         $self->parent, $self->btn_build_all_halls->GetId,   sub{$self->OnBuildAllHalls(@_)} );
        EVT_ENTER_WINDOW(   $self->list_glyphs,                                 sub{$self->OnMouseEnterGlyphsList(@_)}    );
        return 1;
    }#}}}

    before 'clear_dialog_status' => sub {#{{{
        my $self = shift;
        
        ### Call the dialog_status object's own close method, which removes its 
        ### wxwidgets, before clearing this object's dialog_status attribute.
        if($self->has_dialog_status) {
            $self->dialog_status->close;
        }
        return 1;
    };#}}}

    sub prep_halls_btn_sizer {#{{{
        my $self = shift;

        ### Jiggers the sizer containing the "Build all halls" button, and adds 
        ### the button, centered inside the sizer.
        ###
        ### Hardcoding the sizer's min size here is hacky, but it saves me from 
        ### having to derive the width of the recipe rows which I haven't 
        ### generated yet.
        $self->halls_btn_sizer->SetMinSize(Wx::Size->new(550,-1));
        $self->halls_btn_sizer->AddStretchSpacer;
        $self->halls_btn_sizer->Add($self->btn_build_all_halls, 0, 0, 0);
        $self->halls_btn_sizer->AddStretchSpacer;
        return 1;
    }#}}}

    ### Pseudo events
    sub OnClose {#{{{
        my $self = shift;
        ### Called by RightPane.pm's OnClose event
        $self->clear_dialog_status;
        return 1;
    }#}}}
    sub OnSwitch {#{{{
        my $self = shift;
        ### Called by RightPane.pm's show_right_pane event when the user 
        ### selects a different right pane.
        $self->clear_dialog_status;
        return 1;
    }#}}}
    sub OnDialogStatusClose {#{{{
        my $self = shift;
        if($self->has_dialog_status) {
            $self->clear_dialog_status;
        }
        return 1;
    }#}}}

    sub OnListSelect {#{{{
        my $self    = shift;
        my $parent  = shift;    # Wx::ScrolledWindow
        my $event   = shift;    # Wx::ListEvent

        my $item_idx  = $self->list_glyphs->GetNextItem(-1, wxLIST_NEXT_ALL, wxLIST_STATE_SELECTED);
        my $glyph_idx = $self->list_glyphs->GetItemData($item_idx);
        return 1;
    }#}}}
    sub OnSetGlyphPush {#{{{
        my $self    = shift;
        my $parent  = shift;    # Wx::ScrolledWindow
        my $event   = shift;    # Wx::CommandEvent

        my $pusher_ship_name    = $self->txt_pusher_ship->GetLineText(0);
        my $glyph_home_idx      = $self->chc_glyph_home->GetSelection;
        my $glyph_home_str      = $self->chc_glyph_home->GetString( $glyph_home_idx );
        my $glyph_home_id       = (lc $glyph_home_str ne 'none') ? $self->game_client->planet_id($glyph_home_str) : undef;

        $self->prefs_rec->glyph_home_id($glyph_home_id);
        $self->prefs_rec->pusher_ship_name($pusher_ship_name);
        $self->prefs_rec->update;

        if( lc $glyph_home_str eq 'none' or not $pusher_ship_name ) {
            $self->popmsg("Your glyphs will not be pushed anywhere.");
        }
        else {
            $self->popmsg("Your glyphs will be pushed to $glyph_home_str onboard $pusher_ship_name.");
        }
        return 1;
    }#}}}
    sub OnSetAutoSearch {#{{{
        my $self    = shift;
        my $parent  = shift;    # Wx::ScrolledWindow
        my $event   = shift;    # Wx::CommandEvent

        my $search_idx  = $self->chc_auto_search->GetSelection;
        my $search_str  = lc $self->chc_auto_search->GetString($search_idx);

        $search_str eq 'none' and $search_str = undef;
        $self->prefs_rec->auto_search_for($search_str);
        $self->prefs_rec->update;

        if( $search_str ) {
            $self->popmsg("Your Arch Min will search for $search_str glyphs.");
        }
        else {
            $self->popmsg("Your Arch Min will not search for glyphs.");
        }
        return 1;
    }#}}}
    sub OnBuildAllHalls {#{{{
        my $self    = shift;
        my $parent  = shift;    # Wx::ScrolledWindow
        my $event   = shift;    # Wx::CommandEvent

        unless($self->has_dialog_status) {
            $self->dialog_status( $self->_make_dialog_status );
        }
        $self->dialog_status->show;
        my $total_built = 0;
        RECIPE:
        foreach my $rname( sort keys %{$self->game_client->glyph_recipes} ) {
            $self->yield;
            ### If the user closes the status dialog, calling ->say on it will 
            ### segfault.  So we're checking for its existence, and stopping 
            ### halls builds if it's gone.
            ###
            ### This is a race condition; the window could be closed in between 
            ### checking for it and calling ->say, which is why the ->say calls 
            ### are in try blocks.
            if( $rname =~ /Halls of Vrbansk \((\d)\)/ ) {

                if( $self->has_dialog_status ) {
                    try{ $self->dialog_status->say("Attempting $rname") };
                }
                else {
                    last RECIPE;
                }

                my $ingredients = $self->game_client->glyph_recipes->{$rname};
                my $rv = try {
                    $self->game_client->cook_glyphs($self->planet_id, $ingredients);   # no quantity sent; make the max.
                }
                catch {
                    my $msg = (ref $_) ? $_->text : $_;
                    $self->poperr($msg);
                    return;
                };
                if( ref $rv eq 'HASH' ) {
                    my $built = $rv->{'quantity'} // 0;
                    $total_built += $built;

                    if( $self->has_dialog_status ) {
                        try{ $self->dialog_status->say("Built $built.") };
                        try{ $self->dialog_status->say_recsep };
                    }
                    else {
                        last RECIPE;
                    }
                }
            }
        }
        my $plan_plural = ($total_built == 1) ? 'plan' : 'plans';
        if( $self->has_dialog_status ) {
            $self->dialog_status->hide;
            $self->dialog_status->erase;
        }
        $self->popmsg("Created $total_built Halls of Vrbansk $plan_plural.", 'Success!');
        return 1;
    }#}}}
    sub OnMouseEnterGlyphsList {#{{{
        my $self    = shift;
        my $parent  = shift;    # Wx::ScrolledWindow
        my $event   = shift;    # Wx::MouseEvent

        ### Setting focus on the glyph list on mouseover so scroll wheel events 
        ### activate the list, not the screen.
        $self->list_glyphs->SetFocus;
        $self->ancestor->has_focus(0);
        return 1;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;

