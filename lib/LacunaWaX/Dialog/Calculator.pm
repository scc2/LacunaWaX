
package LacunaWaX::Dialog::Calculator {
    use v5.14;
    use Data::Dumper; $Data::Dumper::Indent = 1;
    use Moose;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_BUTTON EVT_CHECKBOX EVT_CHOICE EVT_CLOSE EVT_SIZE);
    use LacunaWaX::Dialog::NonScrolled;
    extends 'LacunaWaX::Dialog::NonScrolled';

    has 'sizer_debug'   => (is => 'rw', isa => 'Int',   lazy => 1, default => 0     );
    has 'width'         => (is => 'rw', isa => 'Int',   lazy => 1, default => 460   );
    has 'height'        => (is => 'rw', isa => 'Int',   lazy => 1, default => 630   );
    has 'line_height'   => (is => 'rw', isa => 'Int',   lazy => 1, default => 25    );

    has 'lbl_header'        => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'lbl_instructions'  => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'szr_header'        => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => 'vertical'    );
    has 'szr_instructions'  => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1);

    ### Halls
    has 'szr_halls'             => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => 'horizontal'    );
    has 'lbl_halls_lvl_from'    => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'lbl_halls_lvl_to'      => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'txt_halls_lvl_from'    => (is => 'rw', isa => 'Wx::TextCtrl',      lazy_build => 1);
    has 'txt_halls_lvl_to'      => (is => 'rw', isa => 'Wx::TextCtrl',      lazy_build => 1);
    has 'btn_halls'             => (is => 'rw', isa => 'Wx::Button',        lazy_build => 1);

    ### Distance from coords
    has 'szr_distance'          => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => 'horizontal'    );
    has 'szr_coords'            => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => 'vertical'    );
    has 'szr_distance_from'     => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => 'horizontal'    );
    has 'szr_distance_to'       => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => 'horizontal'    );
    has 'szr_distance_btn'      => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => 'vertical'    );
    has 'lbl_blank'             => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'lbl_from_x'            => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'lbl_from_y'            => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'lbl_to_x'              => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'lbl_to_y'              => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'txt_from_x'            => (is => 'rw', isa => 'Wx::TextCtrl',      lazy_build => 1);
    has 'txt_from_y'            => (is => 'rw', isa => 'Wx::TextCtrl',      lazy_build => 1);
    has 'txt_to_x'              => (is => 'rw', isa => 'Wx::TextCtrl',      lazy_build => 1);
    has 'txt_to_y'              => (is => 'rw', isa => 'Wx::TextCtrl',      lazy_build => 1);
    has 'btn_distance'          => (is => 'rw', isa => 'Wx::Button',        lazy_build => 1);

    ### Time
    has 'szr_time'      => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => 'horizontal'    );
    has 'lbl_distance'  => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'txt_distance'  => (is => 'rw', isa => 'Wx::TextCtrl',      lazy_build => 1);
    has 'lbl_speed'     => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'txt_speed'     => (is => 'rw', isa => 'Wx::TextCtrl',      lazy_build => 1);
    has 'btn_time'      => (is => 'rw', isa => 'Wx::Button',        lazy_build => 1);

    ### Trilateration
    has 'szr_tri'           => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => 'vertical'    );
    has 'szr_tri_p1'        => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => 'horizontal'    );
    has 'szr_tri_p2'        => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => 'horizontal'    );
    has 'lbl_tri_inst'      => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'lbl_p1_x'          => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'txt_p1_x'          => (is => 'rw', isa => 'Wx::TextCtrl',      lazy_build => 1);
    has 'lbl_p1_y'          => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'txt_p1_y'          => (is => 'rw', isa => 'Wx::TextCtrl',      lazy_build => 1);
    has 'lbl_p1_rate'       => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'txt_p1_rate'       => (is => 'rw', isa => 'Wx::TextCtrl',      lazy_build => 1);
    has 'lbl_p1_time'       => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'txt_p1_time'       => (is => 'rw', isa => 'Wx::TextCtrl',      lazy_build => 1);
    has 'lbl_p2_x'          => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'txt_p2_x'          => (is => 'rw', isa => 'Wx::TextCtrl',      lazy_build => 1);
    has 'lbl_p2_y'          => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'txt_p2_y'          => (is => 'rw', isa => 'Wx::TextCtrl',      lazy_build => 1);
    has 'lbl_p2_rate'       => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'txt_p2_rate'       => (is => 'rw', isa => 'Wx::TextCtrl',      lazy_build => 1);
    has 'lbl_p2_time'       => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'txt_p2_time'       => (is => 'rw', isa => 'Wx::TextCtrl',      lazy_build => 1);
    has 'btn_tri'           => (is => 'rw', isa => 'Wx::Button',        lazy_build => 1);

    sub BUILD {#{{{
        my $self = shift;

        $self->SetTitle( $self->title );
        $self->SetSize( $self->size );

        ### header
        $self->szr_header->AddSpacer(5);
        $self->szr_header->Add($self->lbl_header, 0, 0, 0);
        $self->szr_header->AddSpacer(10);
        $self->szr_header->Add($self->lbl_instructions, 0, 0, 0);

        ### Halls to level
        $self->szr_halls->Add($self->lbl_halls_lvl_from, 0, 0, 0);
        $self->szr_halls->Add($self->txt_halls_lvl_from, 0, 0, 0);
        $self->szr_halls->AddSpacer(5);
        $self->szr_halls->Add($self->lbl_halls_lvl_to, 0, 0, 0);
        $self->szr_halls->Add($self->txt_halls_lvl_to, 0, 0, 0);
        $self->szr_halls->AddSpacer(5);
        $self->szr_halls->Add($self->btn_halls, 0, 0, 0);

        ### Distance, given coords
        $self->szr_distance_from->Add($self->lbl_from_x, 0, 0, 0);
        $self->szr_distance_from->Add($self->txt_from_x, 0, 0, 0);
        $self->szr_distance_from->AddSpacer(5);
        $self->szr_distance_from->Add($self->lbl_from_y, 0, 0, 0);
        $self->szr_distance_from->Add($self->txt_from_y, 0, 0, 0);
        $self->szr_distance_to->Add($self->lbl_to_x, 0, 0, 0);
        $self->szr_distance_to->Add($self->txt_to_x, 0, 0, 0);
        $self->szr_distance_to->AddSpacer(5);
        $self->szr_distance_to->Add($self->lbl_to_y, 0, 0, 0);
        $self->szr_distance_to->Add($self->txt_to_y, 0, 0, 0);
        $self->szr_coords->Add($self->szr_distance_from, 0, 0, 0);
        $self->szr_coords->AddSpacer(5);
        $self->szr_coords->Add($self->szr_distance_to, 0, 0, 0);
        $self->szr_distance_btn->Add($self->lbl_blank, 5, 0, 0);
        $self->szr_distance_btn->Add($self->btn_distance, 2, 0, 0);
        $self->szr_distance->Add($self->szr_coords, 0, 0, 0);
        $self->szr_distance->AddSpacer(5);
        $self->szr_distance->Add($self->szr_distance_btn, 0, 0, 0);

        ### Distance, given rate and time (need this)
        ### ...actually, I could add this, but it's likely not useful to 
        ### anybody.

        ### Time, given rate and distance
        $self->szr_time->Add($self->lbl_distance, 0, 0, 0);
        $self->szr_time->AddSpacer(5);
        $self->szr_time->Add($self->txt_distance, 0, 0, 0);
        $self->szr_time->AddSpacer(10);
        $self->szr_time->Add($self->lbl_speed, 0, 0, 0);
        $self->szr_time->AddSpacer(5);
        $self->szr_time->Add($self->txt_speed, 0, 0, 0);
        $self->szr_time->AddSpacer(10);
        $self->szr_time->Add($self->btn_time, 0, 0, 0);

        ### Trilateration
        $self->szr_tri_p1->Add($self->lbl_p1_x, 0, 0, 0);
        $self->szr_tri_p1->Add($self->txt_p1_x, 0, 0, 0);
        $self->szr_tri_p1->AddSpacer(5);
        $self->szr_tri_p1->Add($self->lbl_p1_y, 0, 0, 0);
        $self->szr_tri_p1->Add($self->txt_p1_y, 0, 0, 0);
        $self->szr_tri_p1->AddSpacer(5);
        $self->szr_tri_p1->Add($self->lbl_p1_rate, 0, 0, 0);
        $self->szr_tri_p1->Add($self->txt_p1_rate, 0, 0, 0);
        $self->szr_tri_p1->AddSpacer(5);
        $self->szr_tri_p1->Add($self->lbl_p1_time, 0, 0, 0);
        $self->szr_tri_p1->Add($self->txt_p1_time, 0, 0, 0);

        $self->szr_tri_p2->Add($self->lbl_p2_x, 0, 0, 0);
        $self->szr_tri_p2->Add($self->txt_p2_x, 0, 0, 0);
        $self->szr_tri_p2->AddSpacer(5);
        $self->szr_tri_p2->Add($self->lbl_p2_y, 0, 0, 0);
        $self->szr_tri_p2->Add($self->txt_p2_y, 0, 0, 0);
        $self->szr_tri_p2->AddSpacer(5);
        $self->szr_tri_p2->Add($self->lbl_p2_rate, 0, 0, 0);
        $self->szr_tri_p2->Add($self->txt_p2_rate, 0, 0, 0);
        $self->szr_tri_p2->AddSpacer(5);
        $self->szr_tri_p2->Add($self->lbl_p2_time, 0, 0, 0);
        $self->szr_tri_p2->Add($self->txt_p2_time, 0, 0, 0);

        $self->szr_tri->Add($self->lbl_tri_inst, 0, 0, 0);
        $self->szr_tri->AddSpacer(10);
        $self->szr_tri->Add($self->szr_tri_p1, 0, 0, 0);
        $self->szr_tri->AddSpacer(10);
        $self->szr_tri->Add($self->szr_tri_p2, 0, 0, 0);
        $self->szr_tri->AddSpacer(10);
        $self->szr_tri->Add($self->btn_tri, 0, 0, 0);


        ### Add all to screen
        $self->main_sizer->Add($self->szr_header, 0, 0, 0);
        $self->main_sizer->AddSpacer(20);
        $self->main_sizer->Add($self->szr_halls, 0, 0, 0);
        $self->main_sizer->AddSpacer(20);
        $self->main_sizer->Add($self->szr_distance, 0, 0, 0);
        $self->main_sizer->AddSpacer(20);
        $self->main_sizer->Add($self->szr_time, 0, 0, 0);
        $self->main_sizer->AddSpacer(20);
        $self->main_sizer->Add($self->szr_tri, 0, 0, 0);

        $self->init_screen();

        return $self;
    }#}}}

### Halls
    sub _build_btn_halls {#{{{
        my $self = shift;
        my $v = Wx::Button->new(
            $self, -1, 
            "Calculate Halls",
            wxDefaultPosition, 
            Wx::Size->new(120, $self->line_height)
        );
        return $v;
    }#}}}
    sub _build_lbl_halls_lvl_from {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self, -1, 
            "Current Level:",
            wxDefaultPosition, 
            Wx::Size->new(100, $self->line_height)
        );
        $y->SetFont( $self->get_font('/bold_para_text_1') );
        return $y;
    }#}}}
    sub _build_lbl_halls_lvl_to {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self, -1, 
            "Destination Level:",
            wxDefaultPosition, 
            Wx::Size->new(120, $self->line_height)
        );
        $y->SetFont( $self->get_font('/bold_para_text_1') );
        return $y;
    }#}}}
    sub _build_szr_halls {#{{{
        my $self = shift;
        return $self->build_sizer($self, wxHORIZONTAL, 'Halls', 1);
    }#}}}
    sub _build_txt_halls_lvl_from {#{{{
        my $self = shift;
        return Wx::TextCtrl->new(
            $self, -1, 
            q{},
            wxDefaultPosition, Wx::Size->new(40,$self->line_height),
        );
    }#}}}
    sub _build_txt_halls_lvl_to {#{{{
        my $self = shift;
        return Wx::TextCtrl->new(
            $self, -1, 
            q{},
            wxDefaultPosition, Wx::Size->new(40,$self->line_height),
        );
    }#}}}

### Distance from coords
    sub _build_btn_distance {#{{{
        my $self = shift;
        my $v = Wx::Button->new(
            $self, -1, 
            "Calculate Distance",
            wxDefaultPosition, 
            Wx::Size->new(140, $self->line_height)
        );
        return $v;
    }#}}}
    sub _build_lbl_blank {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self, -1, 
            q{},
            wxDefaultPosition, 
            Wx::Size->new(-1, -1)
        );
        return $y;
    }#}}}
    sub _build_lbl_from_x {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self, -1, 
            "X:",
            wxDefaultPosition, 
            Wx::Size->new(13, $self->line_height)
        );
        $y->SetFont( $self->get_font('/bold_para_text_1') );
        return $y;
    }#}}}
    sub _build_lbl_from_y {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self, -1, 
            "Y:",
            wxDefaultPosition, 
            Wx::Size->new(13, $self->line_height)
        );
        $y->SetFont( $self->get_font('/bold_para_text_1') );
        return $y;
    }#}}}
    sub _build_lbl_to_x {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self, -1, 
            "X:",
            wxDefaultPosition, 
            Wx::Size->new(13, $self->line_height)
        );
        $y->SetFont( $self->get_font('/bold_para_text_1') );
        return $y;
    }#}}}
    sub _build_lbl_to_y {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self, -1, 
            "Y:",
            wxDefaultPosition, 
            Wx::Size->new(13, $self->line_height)
        );
        $y->SetFont( $self->get_font('/bold_para_text_1') );
        return $y;
    }#}}}
    sub _build_szr_distance {#{{{
        my $self = shift;
        return $self->build_sizer($self, wxHORIZONTAL, 'Distance from coords', 1);
    }#}}}
    sub _build_szr_coords {#{{{
        my $self = shift;
        return $self->build_sizer($self, wxVERTICAL, 'Coords');
    }#}}}
    sub _build_szr_distance_from {#{{{
        my $self = shift;
        return $self->build_sizer($self, wxHORIZONTAL, 'From', 1);
    }#}}}
    sub _build_szr_distance_to {#{{{
        my $self = shift;
        return $self->build_sizer($self, wxHORIZONTAL, 'To', 1);
    }#}}}
    sub _build_szr_distance_btn {#{{{
        my $self = shift;
        return $self->build_sizer($self, wxVERTICAL, 'Button');
    }#}}}
    sub _build_txt_from_x {#{{{
        my $self = shift;
        return Wx::TextCtrl->new(
            $self, -1, 
            q{},
            wxDefaultPosition, Wx::Size->new(40,$self->line_height),
        );
    }#}}}
    sub _build_txt_from_y {#{{{
        my $self = shift;
        return Wx::TextCtrl->new(
            $self, -1, 
            q{},
            wxDefaultPosition, Wx::Size->new(40,$self->line_height),
        );
    }#}}}
    sub _build_txt_to_x {#{{{
        my $self = shift;
        return Wx::TextCtrl->new(
            $self, -1, 
            q{},
            wxDefaultPosition, Wx::Size->new(40,$self->line_height),
        );
    }#}}}
    sub _build_txt_to_y {#{{{
        my $self = shift;
        return Wx::TextCtrl->new(
            $self, -1, 
            q{},
            wxDefaultPosition, Wx::Size->new(40,$self->line_height),
        );
    }#}}}

### Time
    sub _build_btn_time {#{{{
        my $self = shift;
        my $v = Wx::Button->new(
            $self, -1, 
            "Calculate Time",
            wxDefaultPosition, 
            Wx::Size->new(110, $self->line_height)
        );
        return $v;
    }#}}}
    sub _build_szr_time {#{{{
        my $self = shift;
        return $self->build_sizer($self, wxHORIZONTAL, 'Time', 1);
    }#}}}
    sub _build_lbl_distance {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self, -1, 
            q{Distance:},
            wxDefaultPosition, 
            Wx::Size->new(55, $self->line_height)
        );
        $y->SetFont( $self->get_font('/bold_para_text_1') );
        return $y;
    }#}}}
    sub _build_txt_distance {#{{{
        my $self = shift;
        return Wx::TextCtrl->new(
            $self, -1, 
            q{},
            wxDefaultPosition, Wx::Size->new(80,$self->line_height),
        );
    }#}}}
    sub _build_lbl_speed {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self, -1, 
            q{Speed:},
            wxDefaultPosition, 
            Wx::Size->new(40, $self->line_height)
        );
        $y->SetFont( $self->get_font('/bold_para_text_1') );
        return $y;
    }#}}}
    sub _build_txt_speed {#{{{
        my $self = shift;
        return Wx::TextCtrl->new(
            $self, -1, 
            q{},
            wxDefaultPosition, Wx::Size->new(80,$self->line_height),
        );
    }#}}}

### Trilateration
    sub _build_btn_tri {#{{{
        my $self = shift;
        my $v = Wx::Button->new(
            $self, -1, 
            "Calculate Location",
            wxDefaultPosition, 
            Wx::Size->new(140, $self->line_height)
        );
        return $v;
    }#}}}
    sub _build_szr_tri {#{{{
        my $self = shift;
        return $self->build_sizer($self, wxVERTICAL, 'Trilaterate', 1);
    }#}}}
    sub _build_szr_tri_p1 {#{{{
        my $self = shift;
        return $self->build_sizer($self, wxHORIZONTAL, 'Planet 1', 1);
    }#}}}
    sub _build_szr_tri_p2 {#{{{
        my $self = shift;
        return $self->build_sizer($self, wxHORIZONTAL, 'Planet 2', 1);
    }#}}}
    sub _build_lbl_tri_inst {#{{{
        my $self = shift;
        my $text = "Find an unprobed planet given its known time of travel from two of your planets.";
        my $y = Wx::StaticText->new(
            $self, -1, 
            $text,
            wxDefaultPosition, 
            Wx::Size->new(350, 30)
        );
        $y->SetFont( $self->get_font('/para_text_1') );
        return $y;
    }#}}}
    sub _build_lbl_p1_x {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self, -1, 
            q{X:},
            wxDefaultPosition, 
            Wx::Size->new(13, $self->line_height)
        );
        $y->SetFont( $self->get_font('/bold_para_text_1') );
        return $y;
    }#}}}
    sub _build_lbl_p1_y {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self, -1, 
            q{Y:},
            wxDefaultPosition, 
            Wx::Size->new(13, $self->line_height)
        );
        $y->SetFont( $self->get_font('/bold_para_text_1') );
        return $y;
    }#}}}
    sub _build_lbl_p1_rate {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self, -1, 
            q{Speed:},
            wxDefaultPosition, 
            Wx::Size->new(45, $self->line_height)
        );
        $y->SetFont( $self->get_font('/bold_para_text_1') );
        $y->SetToolTip("Enter the speed as an integer, as it appears in-game.");
        return $y;
    }#}}}
    sub _build_lbl_p1_time {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self, -1, 
            q{Time:},
            wxDefaultPosition, 
            Wx::Size->new(40, $self->line_height)
        );
        $y->SetFont( $self->get_font('/bold_para_text_1') );
        $y->SetToolTip( "Enter the time as given in-game, eg hh:mm:ss" );
        return $y;
    }#}}}
    sub _build_txt_p1_x {#{{{
        my $self = shift;
        return Wx::TextCtrl->new(
            $self, -1, 
            q{},
            wxDefaultPosition, Wx::Size->new(40,$self->line_height),
        );
    }#}}}
    sub _build_txt_p1_y {#{{{
        my $self = shift;
        return Wx::TextCtrl->new(
            $self, -1, 
            q{},
            wxDefaultPosition, Wx::Size->new(40,$self->line_height),
        );
    }#}}}
    sub _build_txt_p1_rate {#{{{
        my $self = shift;
        my $y =  Wx::TextCtrl->new(
            $self, -1, 
            q{},
            wxDefaultPosition, Wx::Size->new(80,$self->line_height),
        );
        $y->SetToolTip("Enter the speed as an integer, as it appears in-game.");
        return $y;
    }#}}}
    sub _build_txt_p1_time {#{{{
        my $self = shift;
        my $y = Wx::TextCtrl->new(
            $self, -1, 
            q{},
            wxDefaultPosition, Wx::Size->new(80,$self->line_height),
        );
        $y->SetToolTip( "Enter the time as given in-game, eg hh:mm:ss" );
        return $y;
    }#}}}
    sub _build_lbl_p2_x {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self, -1, 
            q{X:},
            wxDefaultPosition, 
            Wx::Size->new(13, $self->line_height)
        );
        $y->SetFont( $self->get_font('/bold_para_text_1') );
        return $y;
    }#}}}
    sub _build_lbl_p2_y {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self, -1, 
            q{Y:},
            wxDefaultPosition, 
            Wx::Size->new(13, $self->line_height)
        );
        $y->SetFont( $self->get_font('/bold_para_text_1') );
        return $y;
    }#}}}
    sub _build_lbl_p2_rate {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self, -1, 
            q{Speed:},
            wxDefaultPosition, 
            Wx::Size->new(45, $self->line_height)
        );
        $y->SetFont( $self->get_font('/bold_para_text_1') );
        $y->SetToolTip("Enter the speed as an integer, as it appears in-game.");
        return $y;
    }#}}}
    sub _build_lbl_p2_time {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self, -1, 
            q{Time:},
            wxDefaultPosition, 
            Wx::Size->new(40, $self->line_height)
        );
        $y->SetFont( $self->get_font('/bold_para_text_1') );
        $y->SetToolTip( "Enter the time as given in-game, eg hh:mm:ss" );
        return $y;
    }#}}}
    sub _build_txt_p2_x {#{{{
        my $self = shift;
        return Wx::TextCtrl->new(
            $self, -1, 
            q{},
            wxDefaultPosition, Wx::Size->new(40,$self->line_height),
        );
    }#}}}
    sub _build_txt_p2_y {#{{{
        my $self = shift;
        return Wx::TextCtrl->new(
            $self, -1, 
            q{},
            wxDefaultPosition, Wx::Size->new(40,$self->line_height),
        );
    }#}}}
    sub _build_txt_p2_rate {#{{{
        my $self = shift;
        my $y = Wx::TextCtrl->new(
            $self, -1, 
            q{},
            wxDefaultPosition, Wx::Size->new(80,$self->line_height),
        );
        $y->SetToolTip("Enter the speed as an integer, as it appears in-game.");
        return $y;
    }#}}}
    sub _build_txt_p2_time {#{{{
        my $self = shift;
        my $y = Wx::TextCtrl->new(
            $self, -1, 
            q{},
            wxDefaultPosition, Wx::Size->new(80,$self->line_height),
        );
        $y->SetToolTip( "Enter the time as given in-game, eg hh:mm:ss" );
        return $y;
    }#}}}

### Screen
    sub _build_lbl_header {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self, -1, 
            "Calculator",
            wxDefaultPosition, 
            Wx::Size->new(400, 35)
        );
        $y->SetFont( $self->get_font('/header_1') );
        return $y;
    }#}}}
    sub _build_lbl_instructions {#{{{
        my $self = shift;
        my $text = q{What's happening here may be a bit confusing, especially the Trilateration section.  See the help documentation for complete information.};
        my $y = Wx::StaticText->new(
            $self, -1, 
            $text,
            wxDefaultPosition, 
            Wx::Size->new( $self->width - 20, 35 )
        );
        $y->SetFont( $self->get_font('/para_text_2') );
        return $y;
    }#}}}
    sub _build_szr_header {#{{{
        my $self = shift;
        return $self->build_sizer($self, wxVERTICAL, 'Header');
    }#}}}
    sub _build_size {#{{{
        my $self = shift;
        my $s = Wx::Size->new($self->width, $self->height);
        return $s;
    }#}}}
    sub _build_title {#{{{
        my $self = shift;
        return 'Calculator';
    }#}}}
    sub _set_events {#{{{
        my $self = shift;
        EVT_BUTTON(     $self, $self->btn_tri->GetId,           sub{$self->OnTrilaterate(@_)});
        EVT_BUTTON(     $self, $self->btn_halls->GetId,         sub{$self->OnHalls(@_)});
        EVT_BUTTON(     $self, $self->btn_distance->GetId,      sub{$self->OnDistance(@_)});
        EVT_BUTTON(     $self, $self->btn_time->GetId,          sub{$self->OnTime(@_)});
        EVT_CLOSE(      $self,                                  sub{$self->OnClose(@_)});
        return 1;
    }#}}}


sub trilaterate {#{{{
    my $self = shift;
    my $a_x = shift;
    my $a_y = shift;
    my $b_x = shift;
    my $b_y = shift;
    my $ab_length = shift;
    my $ac_length = shift;
    my $bc_length = shift;  

    if( $ab_length > ($ac_length + $bc_length) ) {
        die "Points do not intersect!";
    }
    if( $ab_length < abs($ac_length - $bc_length) ) {
        die "Points on circle do not intersect!";
    }

    my $ad_length = ($ab_length**2 + $ac_length**2 - $bc_length**2) / (2 * $ab_length);
    my $d_x = $a_x + $ad_length * ($b_x - $a_x) / $ab_length;
    my $d_y = $a_y + $ad_length * ($b_y - $a_y) / $ab_length;
    
    my $h = sqrt( abs($ac_length**2 - $ad_length**2) );

    my $c_x1 = $d_x + $h * ($b_y - $a_y) / $ab_length;
    my $c_y1 = $d_y - $h * ($b_x - $a_x) / $ab_length;

    my $c_x2 = $d_x - $h * ($b_y - $a_y) / $ab_length;
    my $c_y2 = $d_y + $h * ($b_x - $a_x) / $ab_length;

    $c_x1 = sprintf "%.0f", $c_x1;
    $c_y1 = sprintf "%.0f", $c_y1;
    $c_x2 = sprintf "%.0f", $c_x2;
    $c_y2 = sprintf "%.0f", $c_y2;

    return( 
        $c_x1, $c_y1,
        $c_x2, $c_y2
    );
    
}#}}}
sub secs_from_game_dur {#{{{
    my $self = shift;
    my $dur = shift;
    my @ar = split /:/, $dur;

    my($d,$h,$m,$s);

    if( @ar ) { $s = pop @ar; }
    if( @ar ) { $m = pop @ar; }
    if( @ar ) { $h = pop @ar; }
    if( @ar ) { $d = pop @ar; }

    $s += $m * 60 if $m;
    $s += $h * 3600 if $h;
    $s += $d * 86400 if $d;
    return $s;
}#}}}
sub distance_from_rt {#{{{
    my $self = shift;
    my $rate = shift;
    my $time = shift;   # seconds

    $time /= 360_000;
    my $dist = $rate * $time;
    return $dist;
}#}}}
sub distance_from_coords {#{{{
    my $self = shift;
    my $ox = shift;
    my $oy = shift;
    my $tx = shift;
    my $ty = shift;
    return sqrt( ($tx - $ox)**2 + ($ty - $oy)**2 );
}#}}}


    sub OnClose {#{{{
        my($self, $dialog, $event) = @_;
        $self->Destroy;
        $event->Skip();
        return 1;
    }#}}}
    sub OnDistance {#{{{
        my $self    = shift;    # self
        my $dialog  = shift;    # self
        my $event   = shift;    # CommandEvent

        my $fx = (int $self->txt_from_x->GetValue) || 0;
        my $fy = (int $self->txt_from_y->GetValue) || 0;
        my $tx = (int $self->txt_to_x->GetValue) || 0;
        my $ty = (int $self->txt_to_y->GetValue) || 0;

        my $dist = $self->cartesian_distance($fx, $fy, $tx, $ty);
        $self->txt_distance->SetValue($dist);
        $self->popmsg("The distance between those two points is $dist.");

        return 1;
    }#}}}
    sub OnHalls {#{{{
        my $self    = shift;    # self
        my $dialog  = shift;    # self
        my $event   = shift;    # CommandEvent

        my $from = (int $self->txt_halls_lvl_from->GetValue) || 0;
        my $to   = (int $self->txt_halls_lvl_to->GetValue) || 0;

        unless($to > $from) {
            $self->poperr("The level you're going to has to be higher than the level you're at now.");
            return;
        }

        my $needed = $self->halls_to_level($from, $to);
        $self->popmsg("You need $needed halls to go from level $from to level $to.");

        return 1;
    }#}}}
    sub OnTime {#{{{
        my $self    = shift;    # self
        my $dialog  = shift;    # self
        my $event   = shift;    # CommandEvent

        my $distance = $self->txt_distance->GetValue || 0;
        my $speed    = (int $self->txt_speed->GetValue) || 0;

        my $seconds = $self->travel_time($speed, $distance);
        my $time = $self->secs_to_human($seconds, 1);   # 1 == 'exact'
        $self->popmsg("Traveling $distance units at $speed speed will take $time ($seconds seconds).");

        return 1;
    }#}}}
    sub OnTrilaterate {#{{{
        my $self    = shift;    # self
        my $dialog  = shift;    # self
        my $event   = shift;    # CommandEvent

        my $ax = $self->txt_p1_x->GetValue;
        my $ay = $self->txt_p1_y->GetValue;
        my $bx = $self->txt_p2_x->GetValue;
        my $by = $self->txt_p2_y->GetValue;

        my $ac_rate = $self->txt_p1_rate->GetValue;
        my $bc_rate = $self->txt_p2_rate->GetValue;
        my $ac_time = $self->txt_p1_time->GetValue;
        my $bc_time = $self->txt_p2_time->GetValue;

        for($ax, $ay, $bx, $by, $ac_rate, $bc_rate, $ac_time, $bc_time) {
            unless( defined ) {
                $self->poperr("All of the inputs must be set.");
                return 0;
            }
        }

        $ac_time = $self->secs_from_game_dur($ac_time);
        $bc_time = $self->secs_from_game_dur($bc_time);

        my $ab_length = $self->distance_from_coords($ax, $ay, $bx, $by);
        my $ac_length = $self->distance_from_rt($ac_rate, $ac_time);
        my $bc_length = $self->distance_from_rt($bc_rate, $bc_time);

        my ($cx1, $cy1, $cx2, $cy2) = $self->trilaterate(
            $ax, $ay, $bx, $by,
            $ab_length, $ac_length, $bc_length
        );

        ### We can only be sure of the actual location of the target planet if 
        ### one of the given coordinates is outside the boundaries of the 
        ### game.
        if( abs $cx1 > 1500 or abs $cy1 > 1500 ) {
            $self->popmsg("Your target planet is at ($cx2, $cy2).");
            return 1;
        }
        elsif( abs $cx2 > 1500 or abs $cy2 > 1500 ) {
            $self->popmsg("Your target planet is at ($cx1, $cy1).");
            return 1;
        }

        $self->popmsg("Your target planet is either at ($cx1, $cy1) or ($cx2, $cy2).");
        return 1;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;
