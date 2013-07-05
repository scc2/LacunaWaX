
package LacunaWaX::MainSplitterWindow::LeftPane::BodiesTreeCtrl {
    use v5.14;
    use utf8;
    use open qw(:std :utf8);
    use Moose;
    use MIME::Base64;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_TREE_ITEM_ACTIVATED EVT_ENTER_WINDOW);
    with 'LacunaWaX::Roles::GuiElement';

    has 'treectrl' => (is => 'rw', isa => 'Wx::TreeCtrl',  lazy_build => 1);

    has 'root_item_id' => (is => 'rw', isa => 'Wx::TreeItemId',
        documentation => q{
            The true root item.  Not visisble because of the wxTR_HIDE_ROOT style.
        }
    );

    has 'bodies_id' => (is => 'rw', isa => 'Wx::TreeItemId',
        documentation => q{
            The 'Bodies' leaf, which looks like the root item, as it's the top level item visible.
        }
    );

    has 'expand_state' => (is => 'rw', isa => 'Str', lazy => 1, default => 'collapsed', 
        documentation => q{
            Starts out 'collapsed', the other option is 'expanded'.  Used to keep track of what we should
            do (expand or collapse) on a double-click on the visible root item.
        }
    );

    sub BUILD {
        my $self = shift;
        $self->fill_tree;
        return $self;
    };
    sub _build_treectrl {#{{{
        my $self = shift;
        my $v = Wx::TreeCtrl->new(
            $self->parent, -1, wxDefaultPosition, wxDefaultSize, 
            wxTR_DEFAULT_STYLE
            |wxTR_HAS_BUTTONS
            |wxTR_LINES_AT_ROOT
            |wxSUNKEN_BORDER
            |wxTR_HIDE_ROOT
        );
        $v->SetFont( $self->get_font('/para_text_1') );
        return $v;
    }#}}}
    sub _set_events {#{{{
        my $self = shift;
        EVT_TREE_ITEM_ACTIVATED($self->treectrl, $self->treectrl->GetId, sub{$self->OnTreeClick(@_)} );
        EVT_ENTER_WINDOW(   $self->treectrl,  sub{$self->OnMouseEnter(@_)}    );
        return 1;
    }#}}}

    sub fill_tree {#{{{
        my $self = shift;

        $self->root_item_id( 
            $self->treectrl->AddRoot( ('Root Item ' . time), -1, -1, Wx::TreeItemData->new('Hidden Root') )
        );
        if( $self->game_client and $self->game_client->ping ) {

            my $b64_bodies = encode_base64(join q{:}, ('bodies'));
            $self->bodies_id(
                $self->treectrl->AppendItem( 
                    $self->root_item_id, 'Bodies', -1, -1, Wx::TreeItemData->new($b64_bodies)
                )
            );
            my $schema = $self->get_main_schema;


            ### To add a leaf:
            ###     - Add a $b64_NAME variable below
            ###         - encode_base64 cannot handle wide characters, so we're 
            ###         using the $pid instead of the (possibly 
            ###         unicode-containing) planet names.
            ###     - Append an item to the appropriate part of the tree here, 
            ###     using your $b64_NAME variable
            ###     - Add a new action to the given/when in OnTreeClick

            foreach my $pname( sort{lc $a cmp lc $b} keys %{$self->game_client->planets} ) {#{{{
                my $pid = $self->game_client->planet_id($pname);

                ### Both Planet and Station
                my $b64_planet      = encode_base64(join q{:}, ('name', $pid));
                my $b64_rearrange   = encode_base64(join q{:}, ('rearrange', $pid));
                ### Planet
                my $b64_glyphs      = encode_base64(join q{:}, ('glyphs', $pid));
                my $b64_lottery     = encode_base64(join q{:}, ('lottery', $pid));
                my $b64_repair      = encode_base64(join q{:}, ('repair', $pid));
                my $b64_spies       = encode_base64(join q{:}, ('spies', $pid));
                ### Station
                my $b64_bfg         = encode_base64(join q{:}, ('bfg', $pid));
                my $b64_inc         = encode_base64(join q{:}, ('incoming', $pid));
                my $b64_props       = encode_base64(join q{:}, ('propositions', $pid));

                ### Planet name produces summary and should be bolded
                my $planet_name_id  = $self->treectrl->AppendItem(
                    $self->bodies_id, $pname, -1, -1, Wx::TreeItemData->new($b64_planet)
                );
                $self->treectrl->SetItemFont(
                    $planet_name_id, $self->get_font('/bold_para_text_1')
                );

                ### Both Planets and Space Stations get a Rearrange leaf, and 
                ### the code is identical.  Its creation is repeated below to 
                ### keep it in correct alpha order.
                if(
                    my $rec = $schema->resultset('BodyTypes')->search({
                        body_id         => $pid,
                        type_general    => 'space station',
                        server_id       => $self->get_connected_server->id,
                    })->next
                ) {
                    ### 
                    ### Space Station
                    ###
                    my $bfg_id = $self->treectrl->AppendItem( $planet_name_id, 
                        'Fire the BFG', -1, -1, Wx::TreeItemData->new($b64_bfg)
                    );
                    my $inc_id = $self->treectrl->AppendItem( 
                        $planet_name_id, 'Incoming', -1, -1, Wx::TreeItemData->new($b64_inc)
                    );
                    my $props_id = $self->treectrl->AppendItem( 
                        $planet_name_id, 'Propositions', -1, -1, Wx::TreeItemData->new($b64_props)
                    );
                    my $rearrange_id = $self->treectrl->AppendItem( 
                        $planet_name_id, 'Rearrange', -1, -1, Wx::TreeItemData->new($b64_rearrange)
                    );
                }
                else {
                    ### 
                    ### Planet
                    ###
                    my $glyphs_id = $self->treectrl->AppendItem( 
                        $planet_name_id, 'Glyphs', -1, -1, Wx::TreeItemData->new($b64_glyphs)
                    );
                    my $lottery_id = $self->treectrl->AppendItem( 
                        $planet_name_id, 'Lottery', -1, -1, Wx::TreeItemData->new($b64_lottery)
                    );
                    my $rearrange_id = $self->treectrl->AppendItem( 
                        $planet_name_id, 'Rearrange', -1, -1, Wx::TreeItemData->new($b64_rearrange)
                    );
                    my $repair_id = $self->treectrl->AppendItem( 
                        $planet_name_id, 'Repair', -1, -1, Wx::TreeItemData->new($b64_repair)
                    );
                    my $spies_id = $self->treectrl->AppendItem( 
                        $planet_name_id, 'Spies', -1, -1, Wx::TreeItemData->new($b64_spies)
                    );
                }
            }#}}}

            ### On Ubuntu, if the tree is taller than the height of the 
            ### window, the last item in the tree is partially obscured by 
            ### the status bar, even after scrolling all the way down.
            ### Appending an empty item at the very end fixes this.
            my $blank_id = $self->treectrl->AppendItem( $self->bodies_id, q{}, -1, -1 );

            $self->treectrl->Expand($self->bodies_id);
        }
        return 1;
    }#}}}
    sub toggle_expansion_state {#{{{
        my $self = shift;

        given( $self->expand_state ) {
            ### Collapsing and expanding provides a bit of animation; I haven't 
            ### decided whether I like that or not.
            ### Hiding the tree before doing anything, then showing it 
            ### afterwards, removes that animation and makes the state toggle 
            ### happen more quickly, but without the animation the effect is a 
            ### bit flat.
            ### Play with toggling the hidden/shown state (the two calls to 
            ### Show) to decide what you want.
            #$self->treectrl->Show(0);
            when('collapsed') {
                $self->treectrl->ExpandAllChildren( $self->bodies_id );
                ### Expanding everything auto-scrolls us to the bottom, and 
                ### nobody wants that.  Rescroll back up to the top.
                $self->treectrl->ScrollTo( $self->bodies_id );
                $self->expand_state('expanded');
            }
            when('expanded') {
                my($child, $cookie) = $self->treectrl->GetFirstChild($self->bodies_id);
                $self->treectrl->CollapseAllChildren( $child );

                COLLAPSE:
                while( 1 ) {
                    ($child, $cookie) = $self->treectrl->GetNextChild($self->bodies_id, $cookie); 
                    last COLLAPSE unless $child->IsOk;
                    $self->treectrl->CollapseAllChildren( $child );
                }
                $self->expand_state('collapsed');
            }
        }
        return 1;
    }#}}}

    sub OnTreeClick {#{{{
        my $self        = shift;
        my $tree_ctrl   = shift;
        my $tree_event  = shift;

        my $leaf = $tree_event->GetItem();
        my $root = $tree_ctrl->GetRootItem();

        if( $leaf == $tree_ctrl->GetRootItem ) {
            $self->poperr("Selected item is root item.");
            return;
        }

        my $text = $tree_ctrl->GetItemText($leaf);
        if( my $data = $tree_ctrl->GetItemData($leaf) ) {

            my ($action, $pid, @args)   = split /:/, decode_base64($data->GetData || q{});
            my $planet                  = $self->game_client->planet_name($pid);

            given( $action || q{} ) {
                when(/^bodies$/) {
                    $self->toggle_expansion_state();
                }

                ### All
                when(/^default$/) {
                    $self->get_right_pane->show_right_pane(
                        'LacunaWaX::MainSplitterWindow::RightPane::DefaultPane'
                    );
                }
                when(/^rearrange$/) {
                    $self->get_right_pane->show_right_pane(
                        'LacunaWaX::MainSplitterWindow::RightPane::RearrangerPane', $planet
                    );
                }
                when(/^name$/) {
                    $self->get_right_pane->show_right_pane(
                        'LacunaWaX::MainSplitterWindow::RightPane::SummaryPane', $planet
                    );
                }

                ### Planet only
                when(/^glyphs$/) {
                    $self->get_right_pane->show_right_pane(
                        'LacunaWaX::MainSplitterWindow::RightPane::GlyphsPane',
                        $planet,
                        { required_buildings  => {'Archaeology Ministry' => undef}, }
                    );
                }
                when(/^lottery$/) {
                    $self->get_right_pane->show_right_pane(
                        'LacunaWaX::MainSplitterWindow::RightPane::LotteryPane',
                        $planet,
                        { required_buildings  => {'Entertainment District' => undef}, }
                    );
                }
                when(/^repair$/) {
                    $self->get_right_pane->show_right_pane(
                        'LacunaWaX::MainSplitterWindow::RightPane::RepairPane',
                        $planet,
                    );
                }
                when(/^spies$/) {
                    $self->get_right_pane->show_right_pane(
                        'LacunaWaX::MainSplitterWindow::RightPane::SpiesPane',
                        $planet,
                        { required_buildings => {'Intelligence Ministry' => undef} } 
                    );
                }

                ### Space Station only
                when(/^bfg$/) {
                    $self->get_right_pane->show_right_pane(
                        'LacunaWaX::MainSplitterWindow::RightPane::BFGPane',
                        $planet,
                        { required_buildings => {'Parliament' => 25} } 
                    );
                }
                when(/^incoming$/) {
                    $self->get_right_pane->show_right_pane(
                        'LacunaWaX::MainSplitterWindow::RightPane::SSIncoming',
                        $planet,
                        { required_buildings => {'Police' => undef} } 
                    );
                }
                when(/^propositions$/) {
                    $self->get_right_pane->show_right_pane(
                        'LacunaWaX::MainSplitterWindow::RightPane::PropositionsPane',
                        $planet,
                        { 
                            required_buildings  => {'Parliament' => undef}, 
                            nothrob             => 1,
                        } 
                    );
                }

                default {
                    return;
                }
            }
        }

        return 1;
    }#}}}
    sub OnMouseEnter {#{{{
        my $self    = shift;
        my $control = shift;    # Wx::TreeCtrl
        my $event   = shift;    # Wx::MouseEvent

        ### Set focus on the treectrl when the mouse enters to allow 
        ### scrollwheel events to affect the tree rather than whatever they'd 
        ### been affecting previously.
        unless( $self->ancestor->has_focus ) {
            $control->SetFocus;
            $self->ancestor->ancestor->focus_left();
        }

        $event->Skip();
        return 1;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;
