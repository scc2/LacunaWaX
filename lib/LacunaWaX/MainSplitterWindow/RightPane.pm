

package LacunaWaX::MainSplitterWindow::RightPane {
    use v5.14;
    use Moose;
    use English qw( -no_match_vars );
    use Time::HiRes qw(usleep);
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_BUTTON EVT_SPINCTRL EVT_CLOSE);
    with 'LacunaWaX::Roles::GuiElement';

    has 'has_focus'     => (is => 'rw', isa => 'Int', lazy => 1, default => 0);
    has 'main_panel'    => (is => 'rw', isa => 'Wx::ScrolledWindow', predicate => 'has_main_panel');

    has 'panel_obj' => (is => 'rw', isa => 'Object', predicate => 'has_panel_obj',
        documentation => q{
            Whichever of the LacunaWaX::MainSplitterWindow::RightPane::WHATEVER.pm objects is currently on display.
        }
    );

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
            $self->app->throb;
            $self->app->Yield;
        }
        $self->clear_pane;
        $self->main_panel->Show(0);
        $self->app->Yield;

        my $mf = $self->app->main_frame;

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
        unless( $panel ) {
            $self->_show_default_panel($pname, $class);
            return;
        }

        $self->panel_obj($panel);
        $self->main_panel->SetSizer($self->panel_obj->main_sizer);

        unless(defined $args->{'nothrob'} and $args->{'nothrob'}) {
            $self->app->endthrob;
            $self->app->Yield;
        }
        $self->app->Yield;

        $self->main_panel->Show(1);
        $self->finish_pane();
        return 1;
    }#}}}
    sub _planet_has_building {#{{{
        my $self        = shift;
        my $pid         = shift;
        my $bldg_name   = shift;

        my $bldg = try {
            $self->app->game_client->get_building($pid, $bldg_name);
        };
        $self->app->Yield;
        return $bldg || undef;
    }#}}}
    sub _show_default_panel {#{{{
        my $self = shift;
        my $pname = shift || q{};
        my $class = shift || q{};

        my $mf = $self->app->main_frame;
        if( $pname and $class ne 'LacunaWaX::MainSplitterWindow::RightPane::SummaryPane' ) {
            $mf->splitter->right_pane->show_right_pane(
                'LacunaWaX::MainSplitterWindow::RightPane::SummaryPane',
                $pname
            );
        }
        elsif( $class ne 'LacunaWaX::MainSplitterWindow::RightPane::DefaultPane' ) {
            $mf->splitter->right_pane->show_right_pane(
                'LacunaWaX::MainSplitterWindow::RightPane::DefaultPane'
            );
        }
        else {
            ### wtf?
            $self->app->poperr("Something has gone horribly wrong.");
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
        my $mf    = $self->app->main_frame;
        my $pid   = $self->app->game_client->planet_id($pname) if $pname;

        my $bldg = $self->_planet_has_building($pid, $bldg_name);
        unless($bldg) {
            $error = "This pane requires that a $bldg_name exist on this body, and there isn't one."; 
        }

        if( $bldg and $bldg_lvl ) {
            my $b_view = try {
                $self->app->game_client->get_building_view($pid, $bldg);
            }
            catch {
                my $msg = (ref $_) ? $_->text : $_;
                $self->app->poperr($msg);
                return;
            };
            $b_view or return;
            if( $b_view->{'building'}{'level'} < $bldg_lvl ) {
                $error = "This pane requires that a $bldg_name exist at level $bldg_lvl or above.";
            }
        }

        if( $error ) {
            $self->app->popmsg( $error, "Missing building requirements" );
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

=head2 Adding new Right Panel

First you'll need to update the TreeCtrl in the left panel to add your new 
leaf and a new action handler (follow the existing examples).

The new action handler will call a method of this class, by convention named 
"show_NAME_OF_YOUR_NEW_PANE_CONTENTS()".  

Your new method should always start with:

 sub show_NAME_OF_YOUR_NEW_PANE_CONTENTS {
  my $self = shift;
  $self->clear_pane();
  $self->app->throb();      # Include if creating your new pane will take more than 1 second

  ...

  $self->app->endthrob();   # Include if you called throb() above.
  $self->finish_pane();
 }

Your new pane should create a sizer containing a Panel or whatever you need.  
Set your sizer as $self->main_panel->SetSizer($sizer).

=cut

# }#}}}

