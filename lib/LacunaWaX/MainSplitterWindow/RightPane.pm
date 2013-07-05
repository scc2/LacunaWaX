

package LacunaWaX::MainSplitterWindow::RightPane {
    use v5.14;
    use Moose;
    use English qw( -no_match_vars );
    use Time::HiRes qw(usleep);
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_BUTTON EVT_SPINCTRL EVT_CLOSE);
    with 'LacunaWaX::Roles::GuiElement';

    use LacunaWaX::MainSplitterWindow::RightPane::DefaultPane;
    use LacunaWaX::MainSplitterWindow::RightPane::SummaryPane;
    use LacunaWaX::MainSplitterWindow::RightPane::BFGPane;
    use LacunaWaX::MainSplitterWindow::RightPane::GlyphsPane;
    use LacunaWaX::MainSplitterWindow::RightPane::SSIncoming;
    use LacunaWaX::MainSplitterWindow::RightPane::LotteryPane;
    use LacunaWaX::MainSplitterWindow::RightPane::RearrangerPane;
    use LacunaWaX::MainSplitterWindow::RightPane::RepairPane;
    use LacunaWaX::MainSplitterWindow::RightPane::SpiesPane;
    use LacunaWaX::MainSplitterWindow::RightPane::PropositionsPane;

    has 'has_focus'     => (is => 'rw', isa => 'Int', lazy => 1, default => 0);
    has 'main_panel'    => (is => 'rw', isa => 'Wx::ScrolledWindow', predicate => 'has_main_panel');

    has 'panel_obj' => (is => 'rw', isa => 'Object', predicate => 'has_panel_obj',
        documentation => q{
            Whichever of the LacunaWaX::MainSplitterWindow::RightPane::WHATEVER.pm objects is currently on display.
        }
    );

    has 'prev_panel' => (is => 'rw', isa => 'Object', predicate => 'has_prev_panel');

    sub BUILD {
        my $self = shift;
        $self->show_right_pane( 'LacunaWaX::MainSplitterWindow::RightPane::DefaultPane' );
        return $self;
    }
    sub _set_events {#{{{
        my $self = shift;
        EVT_CLOSE( $self->main_panel,  sub{$self->OnClose(@_)}             );
        return 1;
    }#}}}

    sub OnClose {#{{{
        my $self    = shift;

        if( $self->has_panel_obj ) {
            $self->panel_obj->OnClose if $self->panel_obj->can('OnClose');
        }
        return 1;
    }#}}}

    sub clear_pane {#{{{
        my $self  = shift;

=head2 clear_pane

Resets the right pane back to 

    main_panel

With no children.

=cut

        if( $self->main_panel ) {
            $self->main_panel->DestroyChildren;
        }
        else {
            $self->main_panel(
                Wx::ScrolledWindow->new(
                    $self->parent, -1, 
                    wxDefaultPosition, wxDefaultSize, wxTAB_TRAVERSAL
                )
            );
            ### I'm unclear whether the arguments are doing anything at all.  
            ### Scrolling looks the same with the rate set at 10 as it does at 
            ### 1000.
            ### The method does definitely need to be called to create the 
            ### scrollbars though.
            $self->main_panel->SetScrollRate(10,10);
        }

        return 1;
    }#}}}
    sub finish_pane {#{{{
        my $self  = shift;

=head2 finish_pane

Should be called after modifying anything in the right pane.

=cut

        $self->main_panel->FitInside(); # Force the scrollbars to reset
        return 1;
    }#}}}

    sub show_right_pane {#{{{
        my $self  = shift;
        my $class = shift;
        my $pname = shift || q{};
        my $args  = shift || {};

=pod

Displays one of the RightPane/*.pm panels in the splitter window's right pane.

- $class - fully-qualified name of class to display

- $pname - name of the planet for which we're displaying the pane.
           Optional, provided the pane in question doesn't actually describe a 
           planet (eg DefaultPane.pm)

- $args  - hashref of additional arguments.
            - 'required_buildings'
                Hashref.  Names of buildings that must exist on this body to be 
                able to display the panel (eg 'Archaeology Ministry' to display 
                glyphs, etc.).  The values will be the minimum level required of 
                the building, undef if no minimum level (eg 'Parliament' => 25 
                for BFG)
            - 'nothrob'
                Flag.  If true, the throbber is not turned on.

=cut

        unless(defined $args->{'nothrob'} and $args->{'nothrob'}) {
            $self->throb;
            $self->yield;
        }
        $self->clear_pane;
        $self->main_panel->Show(0);
        $self->yield;

        if( defined $args->{'required_buildings'} ) {
            foreach my $bldg_name( keys %{$args->{'required_buildings'}} ) {
                $self->_validate_required_building(
                    $pname, 
                    $bldg_name, 
                    $args->{'required_buildings'}{$bldg_name}   # the required bldg lvl
                ) or return;
            }
        }

        my $panel = $class->new(
            app         => $self->app,
            parent      => $self->main_panel,
            ancestor    => $self,
            planet_name => $pname,
        );
        if( $panel ) {
            if( $self->has_prev_panel and $self->prev_panel->can('OnSwitch') ) {
                $self->prev_panel->OnSwitch;
            }
            $self->prev_panel($panel);
        }
        else {
            $self->_show_default_panel($pname, $class);
            return;
        }

        $self->panel_obj($panel);
        $self->main_panel->SetSizer($self->panel_obj->main_sizer);

        unless(defined $args->{'nothrob'} and $args->{'nothrob'}) {
            $self->endthrob;
            $self->yield;
        }
        $self->yield;

        $self->main_panel->Show(1);
        $self->finish_pane();
        return 1;
    }#}}}
    sub _planet_has_building {#{{{
        my $self        = shift;
        my $pid         = shift;
        my $bldg_name   = shift;

        my $bldg = try {
            $self->game_client->get_building($pid, $bldg_name);
        };
        $self->yield;
        return $bldg || undef;
    }#}}}
    sub _show_default_panel {#{{{
        my $self = shift;
        my $pname = shift || q{};
        my $class = shift || q{};

        if( $pname and $class ne 'LacunaWaX::MainSplitterWindow::RightPane::SummaryPane' ) {
            $self->get_right_pane->show_right_pane(
                'LacunaWaX::MainSplitterWindow::RightPane::SummaryPane',
                $pname
            );
        }
        elsif( $class ne 'LacunaWaX::MainSplitterWindow::RightPane::DefaultPane' ) {
            $self->get_right_pane->show_right_pane(
                'LacunaWaX::MainSplitterWindow::RightPane::DefaultPane'
            );
        }
        else {
            ### wtf?
            $self->poperr("Something has gone horribly wrong.");
            return;
        }

        return 1;
    }#}}}
    sub _validate_required_building {#{{{
        my $self        = shift;
        my $pname       = shift;
        my $bldg_name   = shift;
        my $bldg_lvl    = shift || 0;

        my $error = q{};
        my $pid   = $self->game_client->planet_id($pname) if $pname;

        my $bldg = $self->_planet_has_building($pid, $bldg_name);
        unless($bldg) {
            $error = "This pane requires that a $bldg_name exist on this body, and there isn't one."; 
        }

        if( $bldg and $bldg_lvl ) {
            my $b_view = try {
                $self->game_client->get_building_view($pid, $bldg);
            }
            catch {
                my $msg = (ref $_) ? $_->text : $_;
                $self->poperr($msg);
                return;
            };
            $b_view or return;
            if( $b_view->{'building'}{'level'} < $bldg_lvl ) {
                $error = "This pane requires that a $bldg_name exist at level $bldg_lvl or above.";
            }
        }

        if( $error ) {
            $self->popmsg( $error, "Missing building requirements" );
            $self->_show_default_panel($pname);
            return;
        }

        return $bldg;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;

__END__

# POD {#{{{

=head2 Adding a new right panel

=head3 Create your new panel module under RightPane/

For the most part, just follow the existing examples.  But there are some 
pseudo-events to be aware of.

=over 4

=item * OnClose

Optional.  If it exists, RightPane.pm will call your new panel's OnClose 
method when the RightPane is itself closed (during RightPane's own OnClose 
method, which is a true, not a pseudo, event.)

This RightPane OnClose event is triggered when the entire right panel is 
closed.  This basically means "when the program is closed".

=item * OnSwitch

Optional.  If it exists, RightPane.pm will call your new panel's OnSwitch 
method when the user attempts to open a different right panel:

 - User opens the Glyphs panel by clicking the appropriate leaf in the left 
   tree
 - User then opens the Rearrange panel by clicking its leaf.

Upon clicking the Rearrange panel, the user is "switching" from the Glyphs 
panel to the Rearrange panel, and the Glyphs panel's OnSwitch will therefore 
be called.

This is a good place to clean up any Status windows your panel may have 
created.

=item * OnDialogStatusClose

Optional.  If your panel needs to open a Dialog::Status window at some point, 
that status dialog will call your panel's OnDialogStatusClose method when (if) 
that status dialog gets closed. 

=back

=head3 Update the tree in the left pane

To update the TreeCtrl to include a pointer to your new pane (that the user 
can click on), first add the leaf itself (in fill_tree; follow existing 
examples).  Next, add a handler for when that leaf is clicked (in OnTreeClick; 
again, follow existing examples).

=cut

# }#}}}

