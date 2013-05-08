
### TBD
### - Needs an OnResize event for both the nav bar and the html window
###
### - Needs a Home button
###     - currently there's no way to get out of a search that returned no 
###     results
###
### - Search works (search for 'gogopuffs'), but the hitlist page is ugly.
###
### - Index creation is strictly manual right now.  I'm thinking it should be 
### made part of post_build.pl, but the indexing script (build_index.pl, 
### sitting in the HTML help directory) should also remain in case a user 
### wants to add their own help docs.
###     - Possibly that build_index.pl should be created as an executable
###     - Certainly it should end up living somewhere other than where it is 
###     now.
###     - The buttons need to be disable-able
###         - Make grayed-out versions of the images
###         - BitmapButton has a SetBitmapDisabled() method I can use to set 
###         those grayed images.
###         - If I'm at the start of my history, back button should be 
###         disabled.  If I'm at the end, forward button should be disabled.  
###         And if the user hasn't entered a search term yet, the search 
###         button should be disabled.
###         - So all three buttons should begin life disabled.

package LacunaWaX::Dialog::Help {
    use v5.14;
    use Data::Dumper;
    use File::Slurp;
    use Moose;
    use Template;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_BUTTON EVT_CLOSE EVT_HTML_LINK_CLICKED EVT_SIZE);
    with 'LacunaWaX::Roles::GuiElement';

    use MooseX::NonMoose::InsideOut;
    extends 'Wx::Dialog', 'LacunaWaX::Dialog::NonScrolled';

    has 'sizer_debug' => (is => 'rw', isa => 'Int',  lazy => 1, default => 0,
        documentation => q{
            Turning this on adds extra space usage because of the boxes drawn 
            around the sizers.  This will mess up the sizing on the navbar.
            That's OK, just be aware of it and don't try to fix the navbar sizing 
            while this is on.
        }
    );

    has 'index'         => (is => 'rw', isa => 'Str',       lazy_build => 1);
    has 'history'       => (is => 'rw', isa => 'ArrayRef',  lazy_build => 1);
    has 'history_idx'   => (is => 'rw', isa => 'Int',       lazy_build => 1,
        documentation => q{
            The subscript of the history array containing our current location.
        }
    );
    has 'html_dir' => (is => 'rw', isa => 'Str', lazy_build => 1);
    has 'prev_click_href' => (is => 'rw', isa => 'Str', lazy => 1, default => q{},
        documentation => q{ See OnLinkClicked for details.  }
    );
    has 'tt' => (is => 'rw', isa => 'Template', lazy_build => 1);

    has 'title' => (is => 'rw', isa => 'Str',       lazy_build => 1);
    has 'size'  => (is => 'rw', isa => 'Wx::Szie',  lazy_build => 1);

    ### CHECK
    ### On ubuntu, the full bitmap is not displayed in the bitmapbutton - it's 
    ### got a bit of a border that obscures the image detail at the edges.
    ### All of the bitmapbutton styles are Win32 only.  It looks to me like 
    ### turning on wxBU_AUTODRAW will make the buttons on Windows look more 
    ### like the buttons on ubuntu.
    ###
    ### I think that should be done for consistency, but this will mean that 
    ### the images I'm using right now will probably not work because the 
    ### circle around the arrows goes to the edge of the image and therefore 
    ### gets cut off
    has 'nav_img_h'     => (is => 'rw', isa => 'Int',  lazy => 1, default => 32);
    has 'nav_img_w'     => (is => 'rw', isa => 'Int',  lazy => 1, default => 32);
    has 'search_box_h'  => (is => 'rw', isa => 'Int',  lazy => 1, default => 32);
    has 'search_box_w'  => (is => 'rw', isa => 'Int',  lazy => 1, default => 150);

    has 'bmp_left'          => (is => 'rw', isa => 'Wx::BitmapButton',  lazy_build => 1);
    has 'bmp_right'         => (is => 'rw', isa => 'Wx::BitmapButton',  lazy_build => 1);
    has 'bmp_search'        => (is => 'rw', isa => 'Wx::BitmapButton',  lazy_build => 1);
    has 'fs_html'           => (is => 'rw', isa => 'Wx::FileSystem',    lazy_build => 1);
    has 'htm_window'        => (is => 'rw', isa => 'Wx::HtmlWindow',    lazy_build => 1);
    has 'szr_html'          => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => q{vertical});
    has 'szr_navbar'        => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => q{horizontal});
    has 'txt_search'        => (is => 'rw', isa => 'Wx::TextCtrl',      lazy_build => 1, documentation => q{horizontal});

    ### Doesn't follow the Hungarian notation convention used for the other 
    ### WxWindows on purpose, to set it apart from the other controls.    
    ### main_sizer is required by our NonScrolled parent.
    has 'main_sizer' => (is => 'rw', isa => 'Wx::Sizer', lazy_build => 1, documentation => q{vertical});

    sub FOREIGNBUILDARGS {#{{{
        my $self = shift;
        my %args = @_;

        return (
            undef, -1, 
            q{},        # the title
            wxDefaultPosition,
            Wx::Size->new(600, 700),
            wxRESIZE_BORDER|wxDEFAULT_DIALOG_STYLE
        );
    }#}}}
    sub BUILD {
        my($self, @params) = @_;
        $self->Show(0);

        $self->SetTitle( $self->title );
        $self->make_navbar();

        $self->szr_html->Add($self->htm_window, 0, 0, 0);

        $self->main_sizer->Add($self->szr_navbar, 0, 0, 0);
        $self->main_sizer->Add($self->szr_html, 0, 0, 0);

        unless( $self->load_html_file($self->index) ) {
            ### Produces an ugly window flash, but since this is something that 
            ### really should never happen, I'm not too concerned about 
            ### momentary ugliness.
            $self->Destroy;
            return;
        }

        $self->init_screen();
        $self->Show(1);
        return $self;
    };

    sub _build_bmp_left {#{{{
        my $self = shift;
        my $img = $self->app->wxbb->resolve(service => '/Assets/images/app/arrow-left.png');
        $img->Rescale($self->nav_img_w, $self->nav_img_h);
        my $bmp = Wx::Bitmap->new($img);
        my $v = Wx::BitmapButton->new(
            $self, -1, 
            $bmp,
            wxDefaultPosition,
            Wx::Size->new($self->nav_img_w, $self->nav_img_h),
            wxFULL_REPAINT_ON_RESIZE
        );
        return $v;
    }#}}}
    sub _build_bmp_right {#{{{
        my $self = shift;
        my $img = $self->app->wxbb->resolve(service => '/Assets/images/app/arrow-right.png');
        $img->Rescale($self->nav_img_w, $self->nav_img_h);
        my $bmp = Wx::Bitmap->new($img);
        my $v = Wx::BitmapButton->new(
            $self, -1, 
            $bmp,
            wxDefaultPosition,
            Wx::Size->new($self->nav_img_w, $self->nav_img_h),
            wxFULL_REPAINT_ON_RESIZE
        );
    }#}}}
    sub _build_bmp_search {#{{{
        my $self = shift;
        my $img = $self->app->wxbb->resolve(service => '/Assets/images/app/search.png');
        $img->Rescale($self->nav_img_w, $self->nav_img_h);
        my $bmp = Wx::Bitmap->new($img);
        my $v = Wx::BitmapButton->new(
            $self, -1, 
            $bmp,
            wxDefaultPosition,
            Wx::Size->new($self->nav_img_w, $self->nav_img_h),
            wxFULL_REPAINT_ON_RESIZE
        );
        $v->SetToolTip("Search is currently non-functional.");
        return $v;
    }#}}}
    sub _build_fs_html {#{{{
        my $self = shift;
        my $v    = Wx::FileSystem->new();
        $v->ChangePathTo( $self->html_dir, 1 );
        return $v;
    }#}}}
    sub _build_history {#{{{
        my $self = shift;
        return [$self->index];
    }#}}}
    sub _build_history_idx {#{{{
        return 0;
    }#}}}
    sub _build_htm_window {#{{{
        my $self = shift;

        my $w = $self->GetClientSize->width - 10;
        my $h = $self->GetClientSize->height - 30;

        my $v = Wx::HtmlWindow->new(
            $self, -1, 
            wxDefaultPosition, 
            Wx::Size->new($w, $h),
            wxHW_SCROLLBAR_AUTO
        );
        return $v;
    }#}}}
    sub _build_html_dir {#{{{
        my $self = shift;
        return $self->app->bb->resolve(service => '/Directory/html');
    }#}}}
    sub _build_index {#{{{
        return 'index.html';
    }#}}}
    sub _build_size {#{{{
        my $self = shift;
        return Wx::Size->new( 500, 600 );
    }#}}}
    sub _build_szr_main {#{{{
        my $self = shift;
        my $v = $self->build_sizer($self, wxVERTICAL, 'Main Sizer');
        return $v;
    }#}}}
    sub _build_szr_html {#{{{
        my $self = shift;
        my $v = $self->build_sizer($self, wxVERTICAL, 'HTML Window');
        return $v;
    }#}}}
    sub _build_szr_navbar {#{{{
        my $self = shift;
        my $v = $self->build_sizer($self, wxHORIZONTAL, 'Nav bar');
        return $v;
    }#}}}
    sub _build_title {#{{{
        return 'HTML Window';
    }#}}}
    sub _build_tt {#{{{
        my $self = shift;
        my $tt = Template->new(
            INCLUDE_PATH => $self->html_dir,
            OUTPUT_PATH => $self->html_dir,
            INTERPOLATE => 1,
        );
        return $tt;
    }#}}}
    sub _build_txt_search {#{{{
        my $self = shift;
        my $v = Wx::TextCtrl->new(
            $self, -1, 
            q{},
            wxDefaultPosition, 
            Wx::Size->new($self->search_box_w, $self->search_box_h)
        );
        $v->SetToolTip("Search is currently non-functional.");
        return $v;
    }#}}}
    sub _set_events {#{{{
        my $self = shift;
        EVT_CLOSE(              $self,                              sub{$self->OnClose(@_)}         );
        EVT_BUTTON(             $self,  $self->bmp_left->GetId,     sub{$self->OnLeftNav(@_)}       );
        EVT_BUTTON(             $self,  $self->bmp_right->GetId,    sub{$self->OnRightNav(@_)}      );
        EVT_BUTTON(             $self,  $self->bmp_search->GetId,   sub{$self->OnSearchNav(@_)}     );
        EVT_HTML_LINK_CLICKED(  $self,  $self->htm_window->GetId,   sub{$self->OnLinkClicked(@_)}   );
    }#}}}

    sub make_navbar {#{{{
        my $self = shift;

        my $spacer_width = $self->GetClientSize->width;
        $spacer_width -= $self->nav_img_w * 3;  # left & right buttons
        $spacer_width -= $self->search_box_w;
        $spacer_width -= 10;                    # right margin

        $self->szr_navbar->Add($self->bmp_left, 0, 0, 0);
        $self->szr_navbar->Add($self->bmp_right, 0, 0, 0);
        ### AddSpacer is adding unwanted vertical space when it adds the 
        ### wanted horizontal space.  Calling just Add instead fixes that.
        $self->szr_navbar->Add($spacer_width, 0, 0);
        $self->szr_navbar->Add($self->txt_search, 0, 0, 0);
        $self->szr_navbar->Add($self->bmp_search, 0, 0, 0);
    }#}}}
    sub load_html_file {#{{{
        my $self = shift;
        my $file = shift || return;

        ### GetPath does end with a /
        my $fqfn = $self->fs_html->GetPath() . $file;
        unless(-e $fqfn) {
            $self->app->poperr("$fqfn: No such file or directory");
            return;
        }

        $self->htm_window->LoadFile( $self->fs_html->GetPath() . $file );
    }#}}}

    sub OnClose {#{{{
        my $self    = shift;
        my $dialog  = shift;
        my $event   = shift;
        $self->Destroy;
        $event->Skip();
    }#}}}
    sub OnLeftNav {#{{{
        my $self    = shift;    # LacunaWaX::Dialog::Help
        my $dialog  = shift;    # LacunaWaX::Dialog::Help
        my $event   = shift;    # Wx::CommandEvent

        return if $self->history_idx == 0;

        $self->history_idx( $self->history_idx - 1 );
        $self->load_html_file( $self->history->[ $self->history_idx ] );
    }#}}}
    sub OnLinkClicked {#{{{
        my $self    = shift;    # LacunaWaX::Dialog::Help
        my $dialog  = shift;    # LacunaWaX::Dialog::Help
        my $event   = shift;    # Wx::HtmlLinkEvent

        my $info = $event->GetLinkInfo;

        ### Each link click is triggering this event twice.  This keeps the 
        ### same document from being pushed into our history twice.
        if( $self->prev_click_href eq $info->GetHref ) {
            $event->Skip;
            return;
        }
        $self->prev_click_href( $info->GetHref );

        push @{$self->history}, $info->GetHref;
        $self->history_idx( $self->history_idx + 1 );
        $event->Skip;
    }#}}}
    sub OnRightNav {#{{{
        my $self    = shift;    # LacunaWaX::Dialog::Help
        my $dialog  = shift;    # LacunaWaX::Dialog::Help
        my $event   = shift;    # Wx::CommandEvent

        return if $self->history_idx == $#{$self->history};

        $self->history_idx( $self->history_idx + 1 );
        $self->load_html_file( $self->history->[ $self->history_idx ] );
    }#}}}
    sub OnSearchNav {#{{{
        my $self    = shift;    # LacunaWaX::Dialog::Help
        my $dialog  = shift;    # LacunaWaX::Dialog::Help
        my $event   = shift;    # Wx::CommandEvent

        my $term = $self->txt_search->GetValue;
        unless($term) {
            $self->app->popmsg("Searching for nothing isn't going to return many results.");
            return;
        }

        my $searcher = $self->app->bb->resolve(service => '/Lucy/searcher');
        my $hits = $searcher->hits( query => $term );
        my $vars = {};
        while ( my $hit = $hits->next ) {
            push @{$vars->{'hits'}}, $hit->{'title'};
        }

        my $tmpl_file = 'hitlist.tmpl';
        my $html_file = 'hitlist.html';

        $self->tt->process($tmpl_file, $vars, $html_file);
        $self->load_html_file($html_file);
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;
