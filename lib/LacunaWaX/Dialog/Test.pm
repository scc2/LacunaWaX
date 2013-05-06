


###
### BackgroundDisplay.pm
### 
### Example of painting a background image on a panel.
###

=pod

http://wiki.wxwidgets.org/An_image_panel

According to the example, we should be able to use a PaintDC object to paint 
during an EVT_PAINT event, and a ClientDC object to paint outside of an event.

Painting to the panel inside the event using the PaintDC object is working as 
expected.

However, painting to the panel outside the event using the ClientDC object is 
doing nothing at all.

This isn't a huge problem, as the event can be triggered (per the URL above; 
untested here) by calling Refresh()/Update().


Even if painting outside the event worked, we'd still need the event anyway so 
the image would get repainted when the window regains focus or gets resized or 
whatever.

=cut


package LacunaWaX::Dialog::Test {
    use v5.14;
    use Data::Dumper;
    use File::Slurp;
    use Moose;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_CLOSE EVT_PAINT EVT_SIZE);
    with 'LacunaWaX::Roles::GuiElement';

    use MooseX::NonMoose::InsideOut;
    extends 'Wx::Dialog';

    has 'sizer_debug'   => (is => 'rw', isa => 'Int', lazy => 1, default => 1);
    has 'title'         => (is => 'rw', isa => 'Str', lazy => 1, default => 'Starfield Background');

    has 'pdc'               => (is => 'rw', isa => 'Wx::PaintDC',       lazy_build => 1);
    has 'img_background'    => (is => 'rw', isa => 'Wx::Image',         lazy_build => 1);
    has 'bmp_background'    => (is => 'rw', isa => 'Wx::Bitmap',        lazy_build => 1);
    has 'img_star'          => (is => 'rw', isa => 'Wx::Image',         lazy_build => 1);
    has 'bmp_star'          => (is => 'rw', isa => 'Wx::Bitmap',        lazy_build => 1);
    has 'sbmp_star'         => (is => 'rw', isa => 'Wx::StaticBitmap',  lazy_build => 1);

    has 'siz_inst'    => (is => 'rw', isa => 'Wx::Size',  lazy => 1, default => sub{ Wx::Size->new(500, 25) });
    has 'pos_inst'    => (is => 'rw', isa => 'Wx::Point', lazy => 1, default => sub{ Wx::Point->new(10, 10) });


    has 'lbl_instructions'  => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'szr_instructions'  => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => q{vertical});
    has 'szr_panel'         => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => q{vertical});
    has 'szr_main'          => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => q{vertical});

    sub FOREIGNBUILDARGS {#{{{
        my $self = shift;
        my %args = @_;

        return (
            undef, -1, 
            q{},        # the title
            wxDefaultPosition,
            Wx::Size->new(1000, 1000),
            wxRESIZE_BORDER|wxDEFAULT_DIALOG_STYLE
        );
    }#}}}
    sub BUILD {
        my($self, @params) = @_;
        $self->Show(0);


        ### Normally, sizers just get built with no size specifications.  
        ### Since they get added to the szr_main, everything ends up working 
        ### out.
        ###
        ### Here, we cannot have a szr_main (at least, we can't have one that 
        ### gets SetSizer()'d), so we have to specify the sizes of our sizers.  
        ### See the various _build_szr_* methods.


    ### Trying to draw controls on top of the background is not really working 
    ### so far.
    ###
    ### The closest I can get is:
    ###     - make sure our sizer_debug attribute is true
    ###         - Or a resize causes our starfield to go away totally.
    ###     - make sure the lbl and szr have the same pos and size
    ###         - Otherwise the lbl will not display inside the sizer
    ###     - add the lbl to the szr
    ###
    ### ...even then, losing focus causes the sizer's title and box to display 
    ### instead of the label.  Regaining focus does not fix that, but 
    ### regaining focus and resizing the window does fix it.
    ###
    ### Also, if we switch focus away from the window and leave focus off it 
    ### for a while (about a minute or so?), the starfield in the unfocused 
    ### window will eventually just disappear.  We must re-focus the window to 
    ### get the starfield back.
    ###
        #$self->SetTitle( $self->title );
        #$self->szr_instructions->Add($self->lbl_instructions, 0, 0, 0);


        $self->sbmp_star;


        ### Do not call SetSizer as you normally would.  That would cause 
        ### szr_main to occupy the entire Dialog, obscuring our pretty 
        ### background.
        #$self->SetSizer($self->szr_main);



    ### Calling $self->Refresh seems to be what's borking things up.  It works 
    ### fine here in the call below, but Resize events are calling it as well, 
    ### and I think that's what's causing our funk.
    ### Since a Refresh triggers an OnPaint event, I think my OnPaint method 
    ### is somehow broken.
        $self->Refresh();
        $self->Show(1);
        return $self;
    };

    sub _build_img_background {#{{{
        my $self = shift;
        my $size = shift || $self->GetSize;

        my $img = $self->app->wxbb->resolve(service => '/Assets/images/stars/field.png');
        my $w = $size->GetWidth;
        my $h = $size->GetHeight;
        $img->Rescale( $w, $h );
        return $img;
    }#}}}
    sub _build_bmp_background {#{{{
        my $self = shift;
        return Wx::Bitmap->new($self->img_background);
    }#}}}
    sub _build_img_star {#{{{
        my $self = shift;

        my $img = $self->app->wxbb->resolve(service => '/Assets/images/stars/blue.png');
        $img->Rescale( 300, 300 );
        return $img;
    }#}}}
    sub _build_bmp_star {#{{{
        my $self = shift;
        return Wx::Bitmap->new($self->img_star);
    }#}}}
    sub _build_sbmp_star {#{{{
        my $self = shift;
        my $v = Wx::StaticBitmap->new(
            $self, -1, 
            $self->bmp_star,
            #wxDefaultPosition,
            Wx::Point->new(100,100),
            Wx::Size->new(300, 300),
            wxFULL_REPAINT_ON_RESIZE
        );
    }#}}}
    sub _build_pdc {#{{{
        my $self = shift;
        ### use in OnPaint event
        return Wx::PaintDC->new($self);
    }#}}}

    sub _build_lbl_instructions {#{{{
        my $self = shift;
        my $text = 'Instructions go here';
        my $v = Wx::StaticText->new(
            $self, -1, 
            $text,
            #wxDefaultPosition,
            $self->pos_inst,
            $self->siz_inst,
        );
        return $v;
    }#}}}
    sub _build_szr_main {#{{{
        my $self = shift;
        my $v = $self->build_sizer($self, wxVERTICAL, 'Main Sizer', 0, wxDefaultPosition, Wx::Size->new(600,600));
        return $v;
    }#}}}
    sub _build_szr_instructions {#{{{
        my $self = shift;
        my $v = $self->build_sizer(
            $self, 
            wxVERTICAL, 
            'Instructions', 
            0,
            $self->pos_inst,
            $self->siz_inst,
            #Wx::Size->new(500,35)
        );
        return $v;
    }#}}}

    sub _set_events {#{{{
        my $self = shift;
        EVT_CLOSE(  $self,  sub{$self->OnClose(@_)}     );
        EVT_PAINT(  $self,  sub{$self->OnPaint(@_)}     );
        EVT_SIZE(   $self,  sub{$self->OnResize(@_)}     );
    }#}}}


    sub OnClose {#{{{
        my $self    = shift;
        my $dialog  = shift;
        my $event   = shift;
        $self->Destroy;
        $event->Skip();
    }#}}}
    sub OnPaint {#{{{
        my $self    = shift;
        my $dialog  = shift;
        my $event   = shift;

#say time() . "On paint";

        my $ww = $self->GetSize->GetWidth;
        my $wh = $self->GetSize->GetHeight;

        my $iw = $self->img_background->GetWidth;
        my $ih = $self->img_background->GetHeight;

#        if( $ww > $iw or $wh > $ih ) {
            ### The existing image can be safely scaled down.  But scaling it 
            ### up loses quality, so if the window size is increasing, clear 
            ### the current image so it can be created fresh.
            $self->clear_img_background;
#        }
        $self->img_background->Rescale( $ww, $wh );
        $self->clear_bmp_background;
$self->clear_sbmp_star;

$self->sbmp_star;
        $self->pdc->DrawBitmap( $self->bmp_background, 0, 0, 0 );
        
        $event->Skip;
    }#}}}
    sub OnResize {#{{{
        my $self    = shift;
        my $dialog  = shift;
        my $event   = shift;

#say time() . "On resize";
        $self->Refresh;
        $event->Skip;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;
