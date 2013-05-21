
package LacunaWaX::MainSplitterWindow::RightPane::LotteryPane {
    use v5.14;
    use utf8;
    use open qw(:std :utf8);
    use Moose;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_BUTTON EVT_ENTER_WINDOW EVT_LEAVE_WINDOW);
    with 'LacunaWaX::Roles::MainSplitterWindow::RightPane';

    use LacunaWaX::Model::Lottery::Links;

    has 'sizer_debug' => (is => 'rw', isa => 'Int', lazy => 1, default => 0);

    has 'planet_name'   => (is => 'rw', isa => 'Str',       required => 1     );
    has 'planet_id'     => (is => 'rw', isa => 'Str',       lazy_build => 1   );
    has 'status'        => (is => 'rw', isa => 'HashRef',   lazy_build => 1   );
    has 'type'          => (is => 'rw', isa => 'Str',       lazy_build => 1   );

    has 'links' => (
        is  => 'rw', 
        isa => 'Maybe[LacunaWaX::Model::Lottery::Links]',
    );
    has 'hard_links' => (
        is          => 'rw',
        isa         => 'ArrayRef',
        lazy_build  => 1,
        documentation => q{
            A hardcoded list of links.  This is meant to be the same URLs that 
            show up in 'links', but those are only available until the lottery 
            is played, then they become unavailable for 24 hours.
            This list will always be available, because it's hardcoded.  But if 
            the game adds/removes a link, this list will obviously not change 
            automatically.
            The contained HRs in this list are meant to resemble a 
            LacunaWaX::Model::Lottery::Link
            AoH:
            { name => 'name of site', url => 'url of site' }
        }
    );
    has 'save_caption' => (
        is          => 'rw', 
        isa         => 'Str',
        documentation => q{
            Mousing over the hyperlinks will change the main_frame caption to the URL 
            to which the link is pointing.
            Mousing out again should restore the caption to its previous state; this 
            attribute is where that previous state is stored.
        }
    );
    has 'assigned_other' => (
        is          => 'rw', 
        isa         => 'Int',
        lazy_build  => 1,
        documentation => q{
            Integer number of links that have been assigned to be played at another 
            colony's Entertainment District.
        }
    );
    has 'unassigned' => (
        is          => 'rw', 
        isa         => 'Int',
        lazy_build  => 1,
        documentation => q{
            Integer number of links that have not been assigned to be played at
            any Entertainment District anywhere.
        }
    );
    
    has 'szr_header'        => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1   );
    has 'lbl_header'        => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1   );
    has 'lbl_links_hdr'     => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1   );
    has 'lbl_links_inst'    => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1   );
    has 'lbl_total'         => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1   );
    has 'lbl_other'         => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1   );
    
    has 'szr_header'        => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1   );
    has 'lbl_header'        => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1   );
    has 'lbl_total'         => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1   );
    has 'lbl_other'         => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1   );

    has 'szr_mine'          => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1   );
    has 'lbl_mine_before'   => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1   );
    has 'txt_mine'          => (is => 'rw', isa => 'Wx::TextCtrl',      lazy_build => 1   );
    has 'lbl_mine_after'    => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1   );
    has 'btn_assign'        => (is => 'rw', isa => 'Wx::Button',        lazy_build => 1   );
    has 'btn_clear'         => (is => 'rw', isa => 'Wx::Button',        lazy_build => 1   );

    sub BUILD {
        my $self = shift;

        my $sp = $self->app->main_frame->splitter;

        my $l = try {
            $self->_make_links
        }
        catch {
            my $msg = (ref $_) ? $_->text : $_;
            $self->app->poperr("I was unable to access the lottery links: $msg");
            $sp->right_pane->clear_pane;
            $sp->right_pane->show_right_pane(
                'LacunaWaX::MainSplitterWindow::RightPane::DefaultPane'
            );
            return;
        } or return;
        $self->links($l);

        $self->szr_header->Add($self->lbl_header, 0, 0, 0);

        ### Third ("at this planet") line
        $self->szr_mine->Add($self->lbl_mine_before, 0, 0, 0);
        $self->szr_mine->AddSpacer(2);
        $self->szr_mine->Add($self->txt_mine, 0, 0, 0);
        $self->szr_mine->AddSpacer(5);
        $self->szr_mine->Add($self->lbl_mine_after, 0, 0, 0);
        $self->szr_mine->AddSpacer(5);
        $self->szr_mine->Add($self->btn_assign, 0, 0, 0);

        ### Header and first three lines, including "at this planet" line
        $self->content_sizer->Add($self->szr_header, 0, 0, 0);
        $self->content_sizer->AddSpacer(20);
        $self->content_sizer->Add($self->lbl_total, 0, 0, 0);
        $self->content_sizer->AddSpacer(2);
        $self->content_sizer->Add($self->lbl_other, 0, 0, 0);
        $self->content_sizer->AddSpacer(2);
        $self->content_sizer->Add($self->szr_mine, 0, 0, 0);
        $self->content_sizer->AddSpacer(20);
        $self->content_sizer->Add($self->btn_clear, 0, 0, 0);

        ### Hyperlinks
        $self->content_sizer->AddSpacer(20);
        $self->content_sizer->Add($self->lbl_links_hdr, 0, 0, 0);
        $self->content_sizer->AddSpacer(5);
        $self->content_sizer->Add($self->lbl_links_inst, 0, 0, 0);
        $self->content_sizer->AddSpacer(10);
        $self->content_sizer->Add( $self->_make_hard_link_szr, 0, 0, 0 );

        return $self;
    }

    sub _build_btn_assign {#{{{
        my $self = shift;
        return Wx::Button->new($self->parent, -1, "Assign");
    }#}}}
    sub _build_btn_clear {#{{{
        my $self = shift;
        my $v = Wx::Button->new($self->parent, -1, "Clear all assignments");
        $v->SetToolTip( "Clear all lottery assignments on all of my planets" );
        return $v;
    }#}}}
    sub _build_hard_links {#{{{
        my $self = shift;
        return [
            { name => "A Free Gaming",                  url => "http://www.afreegaming.com/vote/the-lacuna-expanse/" },
            { name => "Browser Based Games",            url => "HTTP://gamelist.bbgsite.com/goto/the_32_lacuna_32_expanse.shtml" },
            { name => "Browser MMORPG",                 url => "http://browsermmorpg.com/vote.php?id=648" },
            { name => "Extreme Top 100",                url => "http://www.xtremetop100.com/in.php?site=1132328899" },
            { name => "GameSites200",                   url => "http://www.gamesites200.com/mpog/in.php?id=5048" },
            { name => "JAG Top List",                   url => "http://www.jagtoplist.com/in.php?site=17337" },
            { name => "OMG Spider",                     url => "http://www.omgspider.com/in.php?game_id=2315" },
            { name => "MMORPG100",                      url => "http://www.mmorpg100.com/in.php?id=6844" },
            { name => "MPOG TOP",                       url => "http://mpogtop.com/in/1292516553" },
            { name => "MGPoll",                         url => "http://mgpoll.com/vote/80" },
            { name => "Persistent Browser Based Games", url => "http://pbbgames.com/site/vote/id/224" },
            { name => "Top 100 MMORPG",                 url => "http://www.top100mmorpgsites.com/in.php?siteid=1000001567" },
            { name => "Top Web Games",                  url => "http://www.topwebgames.com/in.asp?id=7441" },
            { name => "TopBBGS",                        url => "http://www.topbbgs.com/index.php?view=vote&id=273" },
            { name => "World Online Games",             url => "http://worldonlinegames.com/game/strategy/1565/the-lacuna-expanse.aspx" },
        ];
    }#}}}
    sub _build_lbl_header {#{{{
        my $self = shift;
        my $v = Wx::StaticText->new(
            $self->parent, -1, 
            "Play the lottery on " . $self->planet_name,
            wxDefaultPosition, 
            Wx::Size->new(-1, 35)
        );
        $v->SetFont( $self->app->wxbb->resolve(service => '/Fonts/header_1') );
        return $v;
    }#}}}
    sub _build_lbl_links_hdr {#{{{
        my $self = shift;
        my $v = Wx::StaticText->new(
            $self->parent, -1, 
            "Links to voting sites",
            wxDefaultPosition, 
            Wx::Size->new(-1, 35)
        );
        $v->SetFont( $self->app->wxbb->resolve(service => '/Fonts/header_2') );
        return $v;
    }#}}}
    sub _build_lbl_links_inst {#{{{
        my $self = shift;
        my $text = 
"    Clicking the links below will not play the lottery for you; they simply
take you to the same voting sites that the lottery links would have taken you
to.
    Since scheduling the lottery means you're not actually visiting these sites
and voting for TLE, please click the links below periodically and actually 
vote!
    If links are added to or removed from the game, those changes will not 
show up in this list until a new version of LacunaWaX is released.";

        my $v = Wx::StaticText->new(
            $self->parent, -1, 
            $text,
            wxDefaultPosition, 
            Wx::Size->new(-1, 140)
        );
        $v->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_2') );
        return $v;
    }#}}}
    sub _build_lbl_total {#{{{
        my $self = shift;

        my $th = 25;
        my $text = "There are " . $self->links->count . " total lottery links to be played.";
        unless( $self->links->count ) {
            $text .= "  You have already played the lottery today, so no links are available to be assigned.";
            $th = 45;
        }
        my $v = Wx::StaticText->new(
            $self->parent, -1, 
            $text,
            wxDefaultPosition, 
            Wx::Size->new(500,$th)
        );
        $v->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_2') );
        return $v;
    }#}}}
    sub _build_lbl_other {#{{{
        my $self  = shift;
        
        my $pl = ($self->assigned_other == 1) 
            ? "is 1 lottery link"
            : "are " . $self->assigned_other . " lottery links";
        my $text = "There $pl assigned to be played at other colonies.";
        my $v = Wx::StaticText->new(
            $self->parent, -1, 
            #$text,
            q{},
            wxDefaultPosition, 
            Wx::Size->new(500,25)
        );
        $v->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_2') );
        $v->SetLabel( $self->update_lbl_other_assignments );
        return $v;
    }#}}}
    sub _build_lbl_mine_before {#{{{
        my $self  = shift;

        my $text = "Click on";
        my $v = Wx::StaticText->new(
            $self->parent, -1, 
            $text,
            wxDefaultPosition, 
            Wx::Size->new(55,25)
        );
        $v->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_2') );
        
        return $v;
    }#}}}
    sub _build_txt_mine {#{{{
        my $self  = shift;
        
        my $schema = $self->app->bb->resolve( service => '/Database/schema' );
        my $my_cnt = $schema->resultset('LotteryPrefs')->search({
            server_id   => $self->app->server->id,
            body_id     => $self->planet_id,
        })->single;

        my $mine = ($my_cnt and $my_cnt->can('count')) ? $my_cnt->count : 0;

        my $v = Wx::TextCtrl->new(
            $self->parent, -1, 
            $mine,
            wxDefaultPosition, 
            Wx::Size->new(30,25)
        );
        $v->SetToolTip( $self->update_txt_mine_tooltip );

        return $v;
    }#}}}
    sub _build_lbl_mine_after {#{{{
        my $self  = shift;

        my $text = "lottery links at this planet.";
        my $v = Wx::StaticText->new(
            $self->parent, -1, 
            $text,
            wxDefaultPosition, 
            Wx::Size->new(180,25)
        );
        $v->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_2') );
        
        return $v;
    }#}}}
    sub _build_szr_mine {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxHORIZONTAL, 'My Assignments');
    }#}}}
    sub _build_szr_header {#{{{
        my $self = shift;
        return $self->build_sizer($self->parent, wxVERTICAL, 'Header');
    }#}}}
    sub _build_assigned_other {#{{{
        my $self  = shift;
        
        my $schema = $self->app->bb->resolve( service => '/Database/schema' );
        my $other_rs = $schema->resultset('LotteryPrefs')->search({
            server_id   => $self->app->server->id,
            body_id     => { q{!=} => $self->planet_id },
        });

        my $other_cnt = 0;
        while( my $rec = $other_rs->next ) {
            $other_cnt += $rec->count;
        }
        return $other_cnt;
    }#}}}
    sub _build_planet_id {#{{{
        my $self = shift;
        return $self->app->game_client->planet_id( $self->planet_name );
    }#}}}
    sub _build_unassigned {#{{{
        my $self  = shift;
        my $remaining = $self->links->count - $self->assigned_other;

        ### If they lottery's already been played there will be zero links 
        ### available, but there will likely be a bunch of links assigned to be 
        ### played, in which case $remaining will be negative.
        $remaining < 0 and $remaining = 0;

        return $remaining;
    }#}}}
    sub _set_events {#{{{
        my $self = shift;
        ### If we failed to construct $self->links, which is possible, we're 
        ### going to bail and display the default pane.
        ### But this method will still be called, and will lazily build the 
        ### controls below.  The conditionals stop that from happening.
        EVT_BUTTON( $self->parent, $self->btn_assign->GetId,    sub{$self->OnAssignButton(@_)}   ) if $self->has_btn_assign;
        EVT_BUTTON( $self->parent, $self->btn_clear->GetId,     sub{$self->OnClearButton(@_)}   )  if $self->has_btn_clear;
        return 1;

        ### The hyperlink mouseover and mouseout events are set in 
        ### _make_hard_link_szr().
    }#}}}

    sub _make_links {#{{{
        my $self = shift;
        ### Not called lazily, so _make instead of _build just to avoid 
        ### confusion.
        ### This is because this constructor could fail, so I'm wrapping the 
        ### call in try/catch (in BUILD).
        return LacunaWaX::Model::Lottery::Links->new(
            client      => $self->app->game_client,
            planet_id   => $self->planet_id,
        );
    }#}}}
    sub _make_hard_link_szr {#{{{
        my $self = shift;

=pod

Returns a single vertical sizer containing one HyperlinkCtrl per element in 
$self->hard_links

When moving the mouse horizontally from one link to another, the 
mouseover/mouseout events can be delivered in this order:

    - MouseOver link 1
    - MouseOver link 2
    - MouseOut link 1

...instead of what you'd expect:

    - MouseOver link 1
    - MouseOut link 1
    - MouseOver link 2

The two MouseOver events being delivered consecutively results in the wrong 
caption being displayed.  A forum posting indicates this will not be a problem 
under Linux, only Windows.

The 5 pixel spacer after each link exists to encourage the mouseout event to 
happen at the right time.  It's probably not bulletproof, but it's working so 
far in tests, and a bullet getting through this is not fatal.

=cut

        my $szr = $self->build_sizer($self->parent, wxVERTICAL, 'External Links');
        foreach my $hr( @{ $self->hard_links} ) {
            next unless $hr->{'name'} and $hr->{'url'};
            my $v = Wx::HyperlinkCtrl->new(
                $self->parent, -1, 
                $hr->{'name'},
                $hr->{'url'},
                wxDefaultPosition, 
                Wx::Size->new(-1, 20),
                wxHL_DEFAULT_STYLE
            );
            $v->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_3') );

            ### Windows, at least:
            ### Mousing over a link should display its hover color (default 
            ### red), and mousing out again should display its normal color 
            ### (default blue).
            ### This works if you move the mouse slowly and horizontally.
            ### But if the mouse is too quick, or it leaves to the right of the 
            ### link rather than above or below it, the hover color never 
            ### switches back to the normal color.
            ### This is ugly and distracting.  The simplest fix is to just use 
            ### the same color for hover and normal.  This way, when the color 
            ### changes incorrectly, it changes to the same color it already 
            ### was.
            $v->SetHoverColour ( Wx::Colour->new(0,0,255) );
            $v->SetNormalColour( Wx::Colour->new(0,0,255) );

            $szr->Add($v, 0, 0, 0);
            $szr->AddSpacer(5);         # see POD above for explanation

            $v->Connect(
                $v->GetId, wxID_ANY, wxEVT_LEAVE_WINDOW,
                sub{$self->OnMouseOutLink(@_)},
            );
            $v->Connect(
                $v->GetId, wxID_ANY, wxEVT_ENTER_WINDOW,
                sub{$self->OnMouseOverLink(@_)},
            );
        }

        return $szr;
    }#}}}

    sub update_txt_mine_tooltip {#{{{
        my $self = shift;
        ### Just return the text, don't try to set the tooltip itself; that'll 
        ### result in deep recursion.
        return "Up to " . $self->unassigned;
    }#}}}
    sub update_lbl_other_assignments {#{{{
        my $self = shift;
        my $pl = ($self->assigned_other == 1) 
            ? "is 1 lottery link"
            : "are " . $self->assigned_other . " lottery links";
        my $text = "There $pl assigned to be played at other colonies.";
        return $text;
    }#}}}

    sub OnAssignButton {#{{{
        my $self    = shift;
        my $panel   = shift;    # Wx::ScrolledWindow
        my $event   = shift;    # Wx::CommandEvent

        my $to_be_assigned = $self->txt_mine->GetLineText(0);

        if( $to_be_assigned > $self->unassigned ) {
            $self->app->poperr("Attempt to assign more links than are available failed.");
            return;
        }

        my $schema = $self->app->bb->resolve( service => '/Database/schema' );
        my $rec = $schema->resultset('LotteryPrefs')->find_or_create(
            {
                server_id => $self->app->server->id,
                body_id   => $self->planet_id,
            },
            { key => 'LotteryPrefs_body' }
        );
        $rec->count($to_be_assigned);
        $rec->update;

        $self->app->popmsg(
  "$to_be_assigned lottery links will be clicked from this planet.\n"
. "Don't forget to set up Schedule_lottery.exe to run twice per day!"
        );
        return 1;
    }#}}}
    sub OnClearButton {#{{{
        my $self    = shift;
        my $panel   = shift;    # Wx::ScrolledWindow
        my $event   = shift;    # Wx::CommandEvent

        my $schema = $self->app->bb->resolve( service => '/Database/schema' );
        my $rv = $schema->resultset('LotteryPrefs')->search({
            server_id => $self->app->server->id,
        })->delete;

        $self->clear_assigned_other;
        $self->clear_unassigned;

        $self->txt_mine->SetValue( q{} );
        $self->txt_mine->SetToolTip( $self->update_txt_mine_tooltip );
        $self->lbl_other->SetLabel( $self->update_lbl_other_assignments );

        $self->app->popmsg("All lottery assignments have been cleared.  Don't forget to reset them.");
        return 1;
    }#}}}
    sub OnMouseOverLink {#{{{
        my $self    = shift;
        my $ctrl    = shift;    # Wx::HyperlinkCtrl
        my $event   = shift;    # Wx::MouseEvent

        my $url = $ctrl->GetURL;
        my $old_caption = $self->app->caption($url);
        $self->save_caption( $old_caption ) unless $self->save_caption;
        return 1;
    }#}}}
    sub OnMouseOutLink {#{{{
        my $self    = shift;
        my $ctrl    = shift;    # Wx::HyperlinkCtrl
        my $event   = shift;    # Wx::MouseEvent

        $self->app->caption($self->save_caption);
        return 1;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

1;

