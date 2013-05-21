
package LacunaWaX::MainSplitterWindow::RightPane::BFGPane {
    use v5.14;
    use LacunaWaX::Model::Client;
    use List::Util qw(first);
    use Moose;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_BUTTON);
    with 'LacunaWaX::Roles::MainSplitterWindow::RightPane';

    has 'sizer_debug'   => (is => 'rw', isa => 'Int', lazy => 1, default => 0);

    has 'planet_name'   => (is => 'rw', isa => 'Str', required => 1);
    has 'planet_id'     => (is => 'rw', isa => 'Int', lazy_build => 1);

    has 'parl' => (
        is          => 'rw',
        isa         => 'Maybe[Games::Lacuna::Client::Buildings::Parliament]',
        lazy_build  => 1,
        clearer     => 'clear_parl',
        predicate   => 'has_parl',
    );
    has 'parl_id'     => (is => 'rw', isa => 'Int');

    has 'szr_form'              => (is => 'rw', isa => 'Wx::BoxSizer', lazy_build => 1, documentation => 'vertical'     );
    has 'szr_header'            => (is => 'rw', isa => 'Wx::BoxSizer', lazy_build => 1, documentation => 'vertical'     );
    has 'szr_lbl_instructions'  => (is => 'rw', isa => 'Wx::BoxSizer', lazy_build => 1, documentation => 'horizontal'   );
    has 'szr_name_orbit'        => (is => 'rw', isa => 'Wx::BoxSizer', lazy_build => 1, documentation => 'horizontal'   );
    has 'szr_reason'            => (is => 'rw', isa => 'Wx::BoxSizer', lazy_build => 1, documentation => 'horizontal'   );
    has 'szr_target_id'         => (is => 'rw', isa => 'Wx::BoxSizer', lazy_build => 1, documentation => 'horizontal'   );

    has 'lbl_instructions'  => (is => 'rw', isa => 'Wx::StaticText', lazy_build => 1);
    has 'lbl_orbit'         => (is => 'rw', isa => 'Wx::StaticText', lazy_build => 1);
    has 'lbl_reason'        => (is => 'rw', isa => 'Wx::StaticText', lazy_build => 1);
    has 'lbl_planet_name'   => (is => 'rw', isa => 'Wx::StaticText', lazy_build => 1);
    has 'lbl_star_name'     => (is => 'rw', isa => 'Wx::StaticText', lazy_build => 1);
    has 'lbl_target_id'     => (is => 'rw', isa => 'Wx::StaticText', lazy_build => 1);

    has 'btn_fire'          => (is => 'rw', isa => 'Wx::Button',    lazy_build => 1                         );
    has 'chc_orbit'         => (is => 'rw', isa => 'Wx::Choice',    lazy_build => 1                         );
    has 'default_reason'    => (is => 'rw', isa => 'Str',           lazy => 1,      default => 'pew pew pew');
    has 'txt_reason'        => (is => 'rw', isa => 'Wx::TextCtrl',  lazy_build => 1                         );
    has 'txt_star_name'     => (is => 'rw', isa => 'Wx::TextCtrl',  lazy_build => 1                         );
    has 'txt_target_id'     => (is => 'rw', isa => 'Wx::TextCtrl',  lazy_build => 1                         );

    sub BUILD {
        my $self = shift;

        return unless $self->parl_exists_here;

        $self->szr_header->Add($self->lbl_planet_name, 0, 0, 0);
        $self->szr_header->AddSpacer(5);
        $self->szr_header->Add($self->szr_lbl_instructions, 0, 0, 0);

        $self->fill_szr_form();

        $self->content_sizer->Add($self->szr_header, 0, 0, 0);
        $self->content_sizer->AddSpacer(10);
        $self->content_sizer->Add($self->szr_form, 0, 0, 0);
        return $self;
    }
    sub _build_btn_fire {#{{{
        my $self = shift;
        ### There's no Wrap() for button labels.  I found a forum post saying 
        ### that there might be something like that in 2.9, but not yet.
        ### So the label layout has to be hardcoded.
        my $v = Wx::Button->new(
            $self->parent, -1, 
            "Open fire!  All weapons!",
            wxDefaultPosition,
            Wx::Size->new(400, 50),
        );
        $v->SetFont( $self->app->wxbb->resolve(service => '/Fonts/bold_para_text_3') );
        $v->SetBackgroundColour(Wx::Colour->new(200,0,0));      # Brits!
        $v->SetForegroundColour(Wx::Colour->new(255,255,255));  # Brits!
        my $tt = Wx::ToolTip->new("Dispatch war rocket Ajax to bring back his body!");
        $v->SetToolTip($tt);

        return $v;
    }#}}}
    sub _build_chc_orbit {#{{{
        my $self = shift;

        my $v = Wx::Choice->new(
            $self->parent, -1, 
            wxDefaultPosition, 
            Wx::Size->new(50, 25), 
            [1..8],
        );
        $v->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_1') );

        return $v;
    }#}}}
    sub _build_lbl_instructions {#{{{
        my $self = shift;

        my $indent = q{ }x4;
        my $text = "${indent}YOU MUST BE LOGGED IN USING YOUR FULL PASSWORD.  Sitter passwords are not permitted to create propositions.
${indent}If you're on your sitter right now, change to your full password in Edit... Preferences, then close and re-start LacunaWaX.  Simply re-connecting from the File menu after changing your credentials will not work; you must restart the program.
        
${indent}If you know the ID of your target planet, that's all you need.  And it's safer to use; if the target planet gets moved elsewhere by a BHG, using the ID will still hit it, whereas accidentally providing the wrong orbit will end up targeting the wrong body (this is known as A Bad Thing).
${indent}If you don't know the ID of your target, (carefully) provide its star's name and the target's orbit around that star.  You'll be provided the target ID so you can write it down somewhere for use next time.

${indent}Remember that this form only creates a proposition to fire the BFG, and, like any other SS proposition, it must be voted upon before it actually takes effect.";

        my $y = Wx::StaticText->new(
            $self->parent, -1,
            $text,
            wxDefaultPosition, 
            Wx::Size->new(-1, 270)
        );
        $y->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_2') );
        $y->Wrap(560);

        return $y;
    }#}}}
    sub _build_lbl_orbit {#{{{
        my $self = shift;

        my $text = "Orbit:";

        my $y = Wx::StaticText->new(
            $self->parent, -1, 
            $text,
            wxDefaultPosition, 
            Wx::Size->new(-1, 25)
        );
        $y->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_2') );

        return $y;
    }#}}}
    sub _build_lbl_reason {#{{{
        my $self = shift;

        my $text = "Reason:";

        my $y = Wx::StaticText->new(
            $self->parent, -1, 
            $text,
            wxDefaultPosition, 
            Wx::Size->new(-1, 25)
        );
        $y->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_2') );

        return $y;
    }#}}}
    sub _build_lbl_star_name {#{{{
        my $self = shift;

        my $text = "Star Name:";

        my $y = Wx::StaticText->new(
            $self->parent, -1, 
            $text,
            wxDefaultPosition, 
            Wx::Size->new(-1, 25)
        );
        $y->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_2') );

        return $y;
    }#}}}
    sub _build_lbl_target_id {#{{{
        my $self = shift;

        my $text = "Target Planet ID:";

        my $y = Wx::StaticText->new(
            $self->parent, -1, 
            $text,
            wxDefaultPosition, 
            Wx::Size->new(-1, 40)
        );
        $y->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_2') );

        return $y;
    }#}}}
    sub _build_lbl_planet_name {#{{{
        my $self = shift;
        my $y = Wx::StaticText->new(
            $self->parent, -1, 
            "Fire BFG on " . $self->planet_name, 
            wxDefaultPosition, Wx::Size->new(-1, 40)
        );
        $y->SetFont( $self->app->wxbb->resolve(service => '/Fonts/header_1') );
        return $y;
    }#}}}
    sub _build_parl {#{{{
        my $self = shift;

        my $parl = try {
            $self->app->game_client->get_building($self->planet_id, 'Parliament', 1);
        }
        catch {
            my $msg = (ref $_) ? $_->text : $_;
            $self->app->poperr($msg);
            return;
        };

        return( $parl and ref $parl eq 'Games::Lacuna::Client::Buildings::Parliament' ) ? $parl : undef;
    }#}}}
    sub _build_planet_id {#{{{
        my $self = shift;
        return $self->app->game_client->planet_id( $self->planet_name );
    }#}}}
    sub _build_szr_form {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxVERTICAL, 'Fire BFG Form');
    }#}}}
    sub _build_szr_header {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxVERTICAL, 'Header');
    }#}}}
    sub _build_szr_lbl_instructions {#{{{
        my $self = shift;
        my $sizer = $self->build_sizer($self->parent, wxHORIZONTAL, 'Instructions');
        $sizer->Add($self->lbl_instructions, 0, 0, 0);
        return $sizer;
    }#}}}
    sub _build_szr_name_orbit {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxHORIZONTAL, 'Star Name and Orbit', 1);
    }#}}}
    sub _build_szr_reason {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxHORIZONTAL, 'Reason');
    }#}}}
    sub _build_szr_target_id {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxHORIZONTAL, 'Target ID', 1);
    }#}}}
    sub _build_txt_reason {#{{{
        my $self = shift;
        my $v = Wx::TextCtrl->new(
            $self->parent, -1, 
            $self->default_reason,
            wxDefaultPosition, 
            Wx::Size->new(250,25)
        );
        $v->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_1') );
        my $tt = Wx::ToolTip->new("This can be anything - feel free to change the default.");
        $v->SetToolTip($tt);
        return $v;
    }#}}}
    sub _build_txt_star_name {#{{{
        my $self = shift;
        ### This would have been nice as a combo box, but since stars get 
        ### renamed faster than I can keep up with it, I can't keep an accurate 
        ### local database of stars, so just force the user to type or paste the 
        ### name.
        my $v = Wx::TextCtrl->new(
            $self->parent, -1, 
            q{},
            wxDefaultPosition, 
            Wx::Size->new(200,25)
        );
        $v->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_1') );
        my $tt = Wx::ToolTip->new("You or somebody in your alliances must have this star probed.");
        $v->SetToolTip($tt);
        return $v;
    }#}}}
    sub _build_txt_target_id {#{{{
        my $self = shift;
        my $v = Wx::TextCtrl->new(
            $self->parent, -1, 
            q{},
            wxDefaultPosition, 
            Wx::Size->new(70,25)
        );
        $v->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_1') );
        return $v;
    }#}}}
    sub _set_events {#{{{
        my $self = shift;
        EVT_BUTTON( $self->parent, $self->btn_fire->GetId, sub{$self->OnFire(@_)}  );
        return 1;
    }#}}}

    sub fill_szr_form {#{{{
        my $self = shift;

        $self->szr_target_id->Add($self->lbl_target_id, 0, 0, 0);
        $self->szr_target_id->AddSpacer(2);
        $self->szr_target_id->Add($self->txt_target_id, 0, 0, 0);

        $self->szr_name_orbit->Add($self->lbl_star_name, 0, 0, 0);
        $self->szr_name_orbit->AddSpacer(2);
        $self->szr_name_orbit->Add($self->txt_star_name, 0, 0, 0);
        $self->szr_name_orbit->AddSpacer(5);
        $self->szr_name_orbit->Add($self->lbl_orbit, 0, 0, 0);
        $self->szr_name_orbit->AddSpacer(2);
        $self->szr_name_orbit->Add($self->chc_orbit, 0, 0, 0);

        $self->szr_reason->Add($self->lbl_reason, 0, 0, 0);
        $self->szr_reason->AddSpacer(2);
        $self->szr_reason->Add($self->txt_reason, 0, 0, 0);

        $self->szr_form->Add($self->szr_target_id, 0, 0, 0);
        $self->szr_form->AddSpacer(10);
        $self->szr_form->Add($self->szr_name_orbit, 0, 0, 0);
        $self->szr_form->AddSpacer(10);
        $self->szr_form->Add($self->szr_reason, 0, 0, 0);
        $self->szr_form->AddSpacer(30);
        $self->szr_form->Add($self->btn_fire, 0, 0, 0);

        return $self->szr_form;
    }#}}}
    sub get_target {#{{{
        my $self = shift;

=pod

Returns a hashref containing, at least, the ID of the target, and possibly also 
its name:

 {
    id   => 123456,
    name => 'Some planet name',
 }

If the user supplied the target ID on the form, then /only/ the ID will be 
included in the returned hashref.

If the user supplied star name and orbit, the target name will be included as 
well.



Given the star name and orbit, I can get rudimentary info on the planet at that 
orbit.

But using planet (target) ID instead of star name and orbit, where possible, is 
preferred.  This is to keep users from being lazy and just repeatedly firing at 
the same star, same orbit, without checking - if the target gets moved by a BHG 
to another orbit, being lazy like that can result in accidentally firing at an 
alliance member.

However, given a body object created just by ID, as when given a target ID, I am 
unable to get any information at all on that body, unless it's a body I own - 
body->get_status returns "1002: That body does not exist" (or similar) for 
foreign bodies.  I can't even get the name of the orbited star given just the 
planet ID.  

So I'd really like it if this method could return the target planet name, but 
it's only able to do so if the user supplied the (less preferred) star name and 
orbit rather than the target body ID.

I guess I understand that; you could conceivably write a script that just 
iterates from 1 .. $big_integer to grab bodies and then derive info from that, 
without ever having to probe them.

=cut

        my $tid = $self->txt_target_id->GetLineText(0);
        return {'id' => $tid} if $tid and $tid =~ /^\d{1,}$/;

        ### No target ID provided by the user; derive it from starname and 
        ### orbit.

        my $star_name = $self->trim( $self->txt_star_name->GetLineText(0) ) or return;
        my $star = try {
            my $map = $self->app->game_client->map();
            my $star = $map->get_star_by_name($star_name);
            return $star;
        }
        catch {
            my $msg = (ref $_) ? $_->text : $_;
            $self->app->poperr("Attempt to find star named '$star_name' failed: $msg", "No such star"); 
            return;
        } or return;
        my $sid = $star->{'star'}{'id'};

        ### {star}{bodies} is an AoH.  It usually appears ordered by orbit, but 
        ### I think it's really ordered by planet ID.  So if things have been 
        ### moved around, the order will not match the orbits.
        my $orbit = $self->chc_orbit->GetSelection + 1;
        my $bodies = $star->{'star'}{'bodies'};
        my $target = first{ $_->{'orbit'} eq $orbit }@{$bodies};

        return $target;
    }#}}}
    sub parl_exists_here {#{{{
        my $self = shift;

        ### $self->has_parl would just tell us if this object has a parliament 
        ### attribute.  Don't care - what we want to know is whether a 
        ### Parliament building exists on the SS or not.
        ###
        ### So start by just referring to $self->parl, which will call the lazy 
        ### builder if needed, which returns undef if no parl
        $self->parl;

        ### Now we know that parl's builder has run.  If there's still no parl 
        ### object in $self, it's because there's no Parliament building on the 
        ### surface.
        return unless $self->has_parl;

        return 1;
    };#}}}
    sub trim {#{{{
        my $self = shift;
        my $str  = shift;
        $str =~ s/^\s+//;
        $str =~ s/\s+$//;
        return $str;
    }#}}}

    sub OnFire {    ### AAAAAAHHHHHHHHHHHHH!!!!!!!!!! #{{{
        my $self    = shift;
        my $parent  = shift;    # Wx::ScrolledWindow
        my $event   = shift;    # Wx::CommandEvent

        my $target = $self->get_target or do {
            $self->app->poperr("I was unable to determine the target - something's funky.", "Like George Clinton");
            return;
        };
        my $target_id   = $target->{'id'};
        my $target_name = $target->{'name'} // "Body ID $target_id";
        my $reason      = $self->txt_reason->GetLineText(0) || $self->default_reason;

        ### Set target_id value on form in case the user sent star name and 
        ### orbit
        $self->txt_target_id->SetValue($target_id);

        unless( wxYES == $self->app->popconf("Fire the BFG at $target_name - are you sure?", "Really really?") ) {
            $self->app->popmsg("You seem to have had a change of heart.", "No pew pew"); 
            return;
        }

        my $rv = try {
            $self->parl->propose_fire_bfg($target_id, $reason);
        }
        catch {
            my $msg = (ref $_) ? $_->text : $_;
            $self->app->poperr("Attempt to fire the BFG failed: $msg", "No pew pew"); 
            return;
        } or return;

        $self->app->popmsg("Proposal to fire the BFG at $target_name has been submitted; don't forget to vote.", "Success!"); 
        return 1;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;
