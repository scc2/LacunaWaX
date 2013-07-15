
package LacunaWaX::Generics::ResBar {
    use v5.14;
    use Data::Dumper;
    use Moose;
    use Number::Format;
    use Try::Tiny;
    use Wx qw(:everything);
    with 'LacunaWaX::Roles::GuiElement';

    has 'sizer_debug' => (
        is              => 'rw',
        isa             => 'Int',
        lazy            => 1,
        default         => 0,
        documentation   => q{
            When true, all sizers will be drawn with boxes for easy visibility.
            Note those boxes add width; do not attempt to fool with screen centering while 
            this is turned on!
        }
    );

    has 'res_test_mode' => (
        is              => 'rw',
        isa             => 'Int',
        lazy            => 1,
        default         => 0,
        documentation   => q{
            When true, the res amounts will simply be the current epoch time, so calls to 
            update_res will visibly update the labels.  When false, the actual res amounts 
            are displayed.
        }
    );

    has 'planet_name' => (
        is          => 'rw',
        isa         => 'Str',
        required    => 1,
    );

    has 'planet_id' => (
        is              => 'rw',
        isa             => 'Int',
        lazy_build      => 1,
        documentation   => q{
            Derived from the required planet_name, so this doesn't have to be passed in.
        }
    );

    has 'num_formatter' => (
        is      => 'rw',
        isa     => 'Number::Format',
        lazy    => 1,
        default => sub{ Number::Format->new },
        handles => {
            format_num => 'format_number',
        }
    );

    has 'res_w' => (is => 'rw', isa => 'Int', lazy => 1, default => 140 );  # sizer size, not image size
    has 'res_h' => (is => 'rw', isa => 'Int', lazy => 1, default =>  -1 );  # sizer size, not image size
    has 'lbl_w' => (is => 'rw', isa => 'Int', lazy => 1, default => 120 );
    has 'lbl_h' => (is => 'rw', isa => 'Int', lazy => 1, default =>  20 );

    has 'szr_main'      => (is => 'rw', isa => 'Wx::BoxSizer', lazy_build => 1, documentation => 'horizontal'   );
    has 'szr_res_in'    => (is => 'rw', isa => 'Wx::BoxSizer', lazy_build => 1, documentation => 'horizontal'   );

    ### These cannot be generically built by make_res_box.  Each of the images 
    ### has a slightly different width (grrr), and the labels need to be 
    ### attributes so they can be updated later.
    has 'img_food'      => (is => 'rw', isa => 'Wx::StaticBitmap',  lazy_build => 1     );
    has 'img_ore'       => (is => 'rw', isa => 'Wx::StaticBitmap',  lazy_build => 1     );
    has 'img_water'     => (is => 'rw', isa => 'Wx::StaticBitmap',  lazy_build => 1     );
    has 'img_energy'    => (is => 'rw', isa => 'Wx::StaticBitmap',  lazy_build => 1     );
    has 'lbl_food'      => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1     );
    has 'lbl_ore'       => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1     );
    has 'lbl_water'     => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1     );
    has 'lbl_energy'    => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1     );

    sub BUILD {
        my $self = shift;

        $self->update_res;

        my $szr_food    = $self->make_res_box('food');
        my $szr_ore     = $self->make_res_box('ore');
        my $szr_water   = $self->make_res_box('water');
        my $szr_energy  = $self->make_res_box('energy');

        $self->szr_res_in->AddStretchSpacer(1);
        $self->szr_res_in->Add($szr_food, 2, 0, 0);
        $self->szr_res_in->AddSpacer(5);
        $self->szr_res_in->Add($szr_ore, 2, 0, 0);
        $self->szr_res_in->AddSpacer(5);
        $self->szr_res_in->Add($szr_water, 2, 0, 0);
        $self->szr_res_in->AddSpacer(5);
        $self->szr_res_in->Add($szr_energy, 2, 0, 0);
        $self->szr_res_in->AddSpacer(5);
        $self->szr_res_in->AddStretchSpacer(1);

        $self->szr_main->AddStretchSpacer(1);
        $self->szr_main->Add($self->szr_res_in, 0, wxALIGN_CENTER, 0);
        $self->szr_main->AddStretchSpacer(1);

        return $self;
    }
    sub _build_img_food {#{{{
        my $self = shift;

        my $img  = $self->wxbb->resolve(service => '/Assets/images/res_l/food.png');
        $img->Rescale(45, 45);
        my $bmp  = Wx::Bitmap->new($img);
        return Wx::StaticBitmap->new(
            $self->parent, -1, 
            $bmp,
            wxDefaultPosition,
            Wx::Size->new($img->GetWidth, $img->GetHeight),
            wxFULL_REPAINT_ON_RESIZE
        );

    }#}}}
    sub _build_img_ore {#{{{
        my $self = shift;

        my $img  = $self->wxbb->resolve(service => '/Assets/images/res_l/ore.png');
        $img->Rescale(39, 45);
        my $bmp  = Wx::Bitmap->new($img);
        return Wx::StaticBitmap->new(
            $self->parent, -1, 
            $bmp,
            wxDefaultPosition,
            Wx::Size->new($img->GetWidth, $img->GetHeight),
            wxFULL_REPAINT_ON_RESIZE
        );
    }#}}}
    sub _build_img_water {#{{{
        my $self = shift;

        my $img  = $self->wxbb->resolve(service => '/Assets/images/res_l/water.png');
        $img->Rescale(36, 45);
        my $bmp  = Wx::Bitmap->new($img);
        return Wx::StaticBitmap->new(
            $self->parent, -1, 
            $bmp,
            wxDefaultPosition,
            Wx::Size->new($img->GetWidth, $img->GetHeight),
            wxFULL_REPAINT_ON_RESIZE
        );
    }#}}}
    sub _build_img_energy {#{{{
        my $self = shift;

        my $img  = $self->wxbb->resolve(service => '/Assets/images/res_l/energy.png');
        $img->Rescale(31, 45);
        my $bmp  = Wx::Bitmap->new($img);
        return Wx::StaticBitmap->new(
            $self->parent, -1, 
            $bmp,
            wxDefaultPosition,
            Wx::Size->new($img->GetWidth, $img->GetHeight),
            wxFULL_REPAINT_ON_RESIZE
        );
    }#}}}
    sub _build_lbl_food {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self->parent, -1, 
            q{},
            wxDefaultPosition, Wx::Size->new($self->lbl_w, $self->lbl_h)
        );
        $y->SetFont( $self->get_font('/bold_modern_text_2') );
        return $y;
    }#}}}
    sub _build_lbl_ore {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self->parent, -1, 
            q{},
            wxDefaultPosition, Wx::Size->new($self->lbl_w, $self->lbl_h)
        );
        $y->SetFont( $self->get_font('/bold_modern_text_2') );
        return $y;
    }#}}}
    sub _build_lbl_water {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self->parent, -1, 
            q{},
            wxDefaultPosition, Wx::Size->new($self->lbl_w, $self->lbl_h)
        );
        $y->SetFont( $self->get_font('/bold_modern_text_2') );
        return $y;
    }#}}}
    sub _build_lbl_energy {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self->parent, -1, 
            q{},
            wxDefaultPosition, Wx::Size->new($self->lbl_w, $self->lbl_h)
        );
        $y->SetFont( $self->get_font('/bold_modern_text_2') );
        return $y;
    }#}}}
    sub _build_planet_id {#{{{
        my $self = shift;
        return $self->game_client->planet_id( $self->planet_name );
    }#}}}
    sub _build_szr_main {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxHORIZONTAL, 'Res Outside');
    }#}}}
    sub _build_szr_res_in {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxHORIZONTAL, 'Res Inside');
    }#}}}
    sub _set_events {#{{{
        my $self = shift;
        return 1;
    }#}}}

    sub make_res_box {#{{{
        my $self = shift;
        my $type = shift;

        ### Each box is a vertical sizer containing two horizontal sizers with 
        ### the image and the amount (the label).  Both horizontal sizers need 
        ### stretch spacers on left and right to center the image and the 
        ### label.
        ###
        ### Call this by passing in the res type: 'food', 'ore', 'water' or 
        ### 'energy'.  Passing in anything else will explode.

        my $szr_main = $self->build_sizer($self->parent, wxVERTICAL, $type);
        my $szr_img  = $self->build_sizer($self->parent, wxHORIZONTAL, "$type img");
        my $szr_lbl  = $self->build_sizer($self->parent, wxHORIZONTAL, "$type lbl");

        $szr_main->SetMinSize( Wx::Size->new($self->res_w, $self->res_h) );
        $szr_img->SetMinSize( Wx::Size->new($self->res_w, $self->res_h) );
        $szr_lbl->SetMinSize( Wx::Size->new($self->res_w, $self->res_h) );

        my $img_name = "img_$type";
        my $lbl_name = "lbl_$type";

        $szr_img->AddStretchSpacer(1);
        $szr_img->Add($self->$img_name, 0, 0, 0);
        $szr_img->AddStretchSpacer(1);

        $szr_lbl->AddStretchSpacer(1);
        $szr_lbl->Add($self->$lbl_name, 0, 0, 0);
        $szr_lbl->AddStretchSpacer(1);

        $szr_main->Add($szr_img, 0, 0, 0);
        $szr_main->AddSpacer(5);
        $szr_main->Add($szr_lbl, 0, 0, 0);
        return $szr_main;
    }#}}}
    sub update_res {#{{{
        my $self = shift;

        my $status = $self->game_client->get_body_status($self->planet_id, 1);  # force

        my $food    = $self->format_num($status->{'food_stored'});
        my $ore     = $self->format_num($status->{'ore_stored'});
        my $water   = $self->format_num($status->{'water_stored'});
        my $energy  = $self->format_num($status->{'energy_stored'});

        if( $self->res_test_mode ) {
            ($food, $ore, $water, $energy) = (time, time, time, time);
        }

        $self->lbl_food->SetLabel(   $food   );
        $self->lbl_ore->SetLabel(    $ore    );
        $self->lbl_water->SetLabel(  $water  );
        $self->lbl_energy->SetLabel( $energy );
        
        return 1;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;

__END__


=head1 NAME LacunaWaX::Generics::ResBar

Produces a sizer containing images for the four res types, and reports the 
number of each res currently onsite.

=head1 SYNOPSIS

 my $res = LacunaWaX::Generics::ResBar->new(
  app         => $self->app,
  ancestor    => $self->ancestor,
  parent      => $self->parent,
  planet_name => $self->planet_name,
 );

 $self->content_sizer->Add($res->szr_main, 0, 0, 0);

 ...do something that changes the amount of res stored (eg repair a bunch of buildings)...

 $res->update_res();    # The numeric labels update

=cut

