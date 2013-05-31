
package LacunaWaX::MainSplitterWindow::RightPane::GlyphsPane::RecipeForm {
    use v5.14;
    use Moose;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_BUTTON EVT_SPINCTRL);
    with 'LacunaWaX::Roles::GuiElement';

    has 'height'                => (is => 'rw', isa => 'Int',       lazy => 1,      default => 20);
    has 'recipe_name'           => (is => 'rw', isa => 'Str',       required => 1);
    has 'recipe_ingredients'    => (is => 'rw', isa => 'ArrayRef',  required => 1);

    has 'dialog_status' => (
        is          => 'rw',
        isa         => 'LacunaWaX::Dialog::Status',
        predicate   => 'has_dialog_status',
        clearer     => 'clear_dialog_status',
        documentation => q{
            This attribute is a bit of an odd case, and cannot be lazy or have a 
            builder method defined.
            See the explanation in GlyphPane.pm's _make_dialog_status()
        }
    );

    has 'main_sizer'    => (is => 'rw', isa => 'Wx::BoxSizer',      lazy_build => 1, documentation => 'horizontal');
    has 'lbl_name'      => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'lbl_recipe'    => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'spin_quantity' => (is => 'rw', isa => 'Wx::SpinCtrl',      lazy_build => 1);
    has 'btn_assemble'  => (is => 'rw', isa => 'Wx::Button',        lazy_build => 1);

    sub BUILD {
        my $self = shift;
        
        ### In this case, existence of the dialog_status is very conditional 
        ### (only upon making the all halls recipe), and it requires a quantity 
        ### arg.  So don't try making it here.

        if( $self->recipe_name eq 'Halls of Vrbansk (all)' ) {
            my $various_tt_text = 
                "Remember that the number you choose here is the number per recipe\n"
                . "and that there are five 'various' recipes.\n"
                . "So if you choose '100', you'll actually end up with up to 500 halls.";
            $self->lbl_name->SetToolTip( $various_tt_text );
            $self->lbl_recipe->SetToolTip( $various_tt_text );
            $self->spin_quantity->SetToolTip( $various_tt_text );
            $self->btn_assemble->SetToolTip( $various_tt_text );
        }

        $self->main_sizer->Add($self->lbl_name,         0, 0, 0);
        $self->main_sizer->Add($self->lbl_recipe,       0, 0, 0);
        $self->main_sizer->Add($self->spin_quantity,    0, 0, 0);
        $self->main_sizer->Add($self->btn_assemble,     0, 0, 0);
        return $self;
    }
    sub _build_main_sizer {#{{{
        my $self = shift;
        return Wx::BoxSizer->new(wxHORIZONTAL);
    }#}}}
    sub _build_lbl_name {#{{{
        my $self = shift;
        my $v = Wx::StaticText->new(
            $self->parent, -1, 
            $self->recipe_name, 
            wxDefaultPosition, 
            Wx::Size->new(150, $self->height)
        );
        $v->SetFont( $self->get_font('/para_text_1') );
        return $v;
    }#}}}
    sub _build_lbl_recipe {#{{{
        my $self = shift;
        my $v = Wx::StaticText->new(
            $self->parent, -1, 
            ' (' . (join ', ', @{$self->recipe_ingredients}) .') ', 
            wxDefaultPosition, 
            Wx::Size->new(270, $self->height)
        );
        $v->SetFont( $self->get_font('/para_text_1') );
        return $v;
    }#}}}
    sub _build_spin_quantity {#{{{
        my $self = shift;
        my $v = Wx::SpinCtrl->new(
            $self->parent, -1, q{}, 
            wxDefaultPosition, 
            Wx::Size->new(65, $self->height), 
            wxSP_ARROW_KEYS, 
            0, 5000, 0
        );
        $v->SetFont( $self->get_font('/para_text_1') );
        return $v;
    }#}}}
    sub _build_btn_assemble {#{{{
        my $self = shift;
        my $v = Wx::Button->new(
            $self->parent, -1,
            "Assemble"
        );
        $v->SetFont( $self->get_font('/para_text_1') );
        return $v;
    }#}}}
    sub _build_list_glyphs {#{{{
        my $self = shift;
        $self->throb();
        $self->yield;

        my $sorted_glyphs = try {
            $self->game_client->get_glyphs($self->parent->planet_id);
        }
        catch {
            $self->has_arch_min(0);
            $self->poperr($_->text);
            return;
        };

        ### Create glyphs list ctrl
        my $list_ctrl = Wx::ListCtrl->new(
            $self->parent, -1, 
            wxDefaultPosition, 
            Wx::Size->new(300,400), 
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

        $self->endthrob();
        return $list_ctrl;
    }#}}}
    sub _make_dialog_status {#{{{
        my $self     = shift;
        my $quantity = shift;

=head2 _make_dialog_status

Long-ass explanation for this in GlyphsPane.pm (see the method of the same 
name.)

That explanation includes the fact that something mysterious was touching 
$self->dialog_status over in GlyphsPane.  I have not verified that that is 
happening here, so it's possible that a simple lazy_build would work fine in 
this case.  

But since this pseudo-lazy _make method also works fine, I'm going to stay with 
it for consistency with GlyphsPane.

The only additional explanation is that this version needs to accept a quantity, 
where the GlyphsPane version is always building all possible, so the quantity 
arg is not necessary there.

=cut

        return LacunaWaX::Dialog::Status->new( 
            app         => $self->app,
            ancestor    => $self,
            title       => "Building up to $quantity halls per recipe",
            recsep      => '-=-=-=-=-=-=-',
            size        => Wx::Size->new(500,300),
        );
    }#}}}
    sub _set_events {#{{{
        my $self = shift;
        my $btn_id  = $self->btn_assemble->GetId;
        EVT_BUTTON( $self->parent, $btn_id, sub{$self->OnAssembleButtonClick($btn_id, @_)} );
        return 1;
    }#}}}

    ### Pseudo events
    sub OnClose {#{{{
        my $self = shift;
        $self->dialog_status->close if $self->has_dialog_status;
        return 1;
    }#}}}
    sub OnDialogStatusClose {#{{{
        my $self = shift;
        if($self->has_dialog_status) {
            $self->clear_dialog_status;
        }
        return 1;
    }#}}}

    sub OnAssembleButtonClick {#{{{
        my $self    = shift;    # LacunaWaX::MainSplitterWindow::RightPane
        my $id      = shift;    # integer ID
        my $panel   = shift;    # Wx::Panel or Wx::ScrolledWindow
        my $event   = shift;    # Wx::CommandEvent

        my $logger = $self->get_logger;
        $self->throb();

        my $recipe_name     = $self->recipe_name;
        my $quantity        = $self->spin_quantity->GetValue // 0;
        unless( $quantity ) {
            $self->poperr('You must choose a quantity to assemble.', "Can't Make Zero!");
            $self->endthrob();
            return;
        }

        my $gc = $self->game_client;

        ### 'Halls of Vrbansk (all)' is not a recipe, it's an indication that 
        ### we're supposed to build each of the 5 halls recipes.
        my $response = q{};
        if( $recipe_name eq 'Halls of Vrbansk (all)' ) {#{{{
            $logger->debug("Attempting to make all halls");

            ### Building all halls requires five different 'build this' calls so 
            ### it takes longer, so show the status window.
            unless($self->has_dialog_status) {
                $self->dialog_status( $self->_make_dialog_status($quantity) );
            }
            $self->dialog_status->show;

            if( $self->has_dialog_status ) {
                try{ $self->dialog_status->say("You did see the new, shiny, convenient, Build as Many Halls as Possible button above, right?") };
                try{ $self->dialog_status->say_recsep };
            }
            else {
                return;
            }

            my @recipes_to_build = ();
            my $total_built = 0;
            RECIPE:
            foreach my $rname( sort keys %{$gc->glyph_recipes} ) {
                if( $rname =~ /Halls of Vrbansk \((\d)\)/ ) {

                    if( $self->has_dialog_status ) {
                        try{ $self->dialog_status->say("Attempting $rname") };
                    }
                    else {
                        last RECIPE;
                    }

                    my $ringredients = $gc->glyph_recipes->{$rname};
                    $self->yield;
                    my $rv = try {
                        $gc->cook_glyphs($self->ancestor->planet_id, $ringredients, $quantity);
                    }
                    catch {
                        $self->poperr($_->text);
                        return;
                    };
                    $self->yield;
                    if( ref $rv eq 'HASH' ) {
                        my $built = $rv->{'quantity'} // 0;
                        $total_built += $built;
                        if( $self->has_dialog_status ) {
                            try{ $self->dialog_status->say("Built $built.") };
                        }
                        else {
                            last RECIPE;
                        }
                        $logger->debug("All halls builder built $built of $rname");
                    }
                    $self->dialog_status->say_recsep;
                }
            }
            if( $self->has_dialog_status ) {
                ### Don't just erase it and hide it.  If it needs to be 
                ### recreated, it's going to need a different quantity so it'll 
                ### need to be a truly new dialog.
                try{ $self->dialog_status->close };
                try{ $self->clear_dialog_status };
            }
            my $plan_plural = ($total_built == 1) ? 'plan' : 'plans';
            $response = "Created $total_built Halls of Vrbansk $plan_plural.";
        }#}}}
        else {#{{{
            my $plan_plural = ($quantity == 1) ? 'plan' : 'plans';
            $self->yield;
            my $ringredients = $gc->glyph_recipes->{$recipe_name};
            my $built = try {
                $gc->cook_glyphs($self->ancestor->planet_id, $ringredients, $quantity);
            }
            catch {
                $self->poperr($_->text);
                return;
            };

            $self->yield;
            if( ref $built eq 'HASH' ) {
                if( $built->{'error'} ) {
                    $self->poperr($built->{'error'});
                    $self->endthrob();
                    return;
                }
                $response = "Created $built->{'quantity'} $plan_plural of $built->{'item_name'}.";
            }
            else {
                ### Shouldn't ever happen.
                $self->endthrob();
                $logger->error("Glyph assembler event got back non-hashref '-$built-' from cook_glyphs.");
                $self->poperr("Attempt to build glyphs produced an unexpected error.");
                $self->endthrob();
                return;
            }
        }#}}}

        $self->yield;   # allow throbber to update if it's on
        $self->endthrob();
        $self->popmsg($response, "Success!");
        return 1;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;
