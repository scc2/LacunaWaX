


###
### ImageDisplay.pm
###
### Demonstrates several different methods for creating and displaying images.
###
### The _build_bmp_* methods in here are arranged in the order in which they 
### should be read.
###


package LacunaWaX::Dialog::Test {
    use v5.14;
    use Archive::Zip;
    use Archive::Zip::MemberRead;
    use Data::Dumper;
    use File::Slurp;
    use Moose;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_BUTTON EVT_CLOSE EVT_SIZE);
    with 'LacunaWaX::Roles::GuiElement';

    use MooseX::NonMoose::InsideOut;
    extends 'Wx::Dialog';

    has 'sizer_debug' => (is => 'rw', isa => 'Int',  lazy => 1, default => 1);

    has 'title' => (is => 'rw', isa => 'Str', lazy => 1, default => 'Image From String');

    has 'bmp_file'          => (is => 'rw', isa => 'Wx::StaticBitmap',  lazy_build => 1);
    has 'bmp_stream'        => (is => 'rw', isa => 'Wx::StaticBitmap',  lazy_build => 1);
    has 'bmp_stream_zip'    => (is => 'rw', isa => 'Wx::StaticBitmap',  lazy_build => 1);
    has 'bmp_assets_zip'    => (is => 'rw', isa => 'Wx::StaticBitmap',  lazy_build => 1);
    has 'lbl_instructions'  => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'szr_main'          => (is => 'rw', isa => 'Wx::Sizer', lazy_build => 1, documentation => q{vertical});
    has 'szr_images'        => (is => 'rw', isa => 'Wx::Sizer', lazy_build => 1, documentation => q{vertical});
    has 'szr_instructions'  => (is => 'rw', isa => 'Wx::Sizer', lazy_build => 1, documentation => q{vertical});

    sub FOREIGNBUILDARGS {#{{{
        my $self = shift;
        my %args = @_;

        ### Although this block correctly spits the title attribute's value to 
        ### STDOUT...
            #my $title = $self->title;
            #say "--$title--";
            #return;
        ###
        ### $self is really not available yet when FOREIGNBUILDARGS gets called.  
        ### Attempting to use that $title value in the array we're returning 
        ### results in a screen full of uninitialized warnings.
        ###
        ### So just use an empty string for the title argument below, and then 
        ### remember to call SetTitle in BUILD, which happens /after/ the object 
        ### has actually been created.

        return (
            undef, -1, 
            q{},        # the title
            wxDefaultPosition,
            wxDefaultSize,
            wxRESIZE_BORDER|wxDEFAULT_DIALOG_STYLE
        );
    }#}}}
    sub BUILD {
        my($self, @params) = @_;

        $self->SetTitle( $self->title );

        $self->szr_instructions->Add($self->lbl_instructions, 0, 0, 0);

        $self->szr_images->Add($self->bmp_file);
        $self->szr_images->AddSpacer(5);
        $self->szr_images->Add($self->bmp_stream);
        $self->szr_images->AddSpacer(5);
        $self->szr_images->Add($self->bmp_stream_zip);
        $self->szr_images->AddSpacer(5);
        $self->szr_images->Add($self->bmp_assets_zip);

        $self->szr_main->Add($self->szr_instructions, 0, 0, 0);
        $self->szr_main->Add($self->szr_images, 0, 0, 0);

        $self->SetSizer($self->szr_main);

        return $self;
    };
    sub _build_bmp_file {#{{{
        my $self = shift;

=pod

Creates a StaticBitmap given a file.

Easy, but requires a filename of an existing image file.

=cut

        my $image_file = join '/', $self->app->bb->resolve(service => '/Directory/assets'), 'glyphs', 'anthracite_39x50.png';

        ### Create bitmap from filename
        my $bmp = Wx::Bitmap->new(
            $image_file,
            wxBITMAP_TYPE_PNG,
        );

        ### Create StaticBitmap (which we can put on the screen) from bitmap
        my $v = Wx::StaticBitmap->new(
            $self, -1, 
            $bmp,
            wxDefaultPosition,
            Wx::Size->new(39, 50),
            wxFULL_REPAINT_ON_RESIZE
        );

        return $v;
    }#}}}
    sub _build_bmp_stream {#{{{
        my $self = shift;

=pod

Creates an image from an open filehandle, rather from a filename.

Just using a 'regular' filehandle (created by opening a file) is fairly 
pointless - if we've got an existing file, we'd use _build_bmp_file() above 
and just hand it that filename.

However, we can also treat a scalar containing image data as a filehandle.  In 
this example, we've created that scalar by reading data out of a file, but 
that's just for convenience here.  The data in the scalar could come from 
anywhere (a database, a .zip file, whatever).

=cut

        my $img_file = join '/', $self->app->bb->resolve(service => '/Directory/assets'), 'glyphs', 'bauxite_39x50.png';

        ### Get a filehandle from the file...
        open my $reg_fh, '<:raw', $img_file;

        ### ...OR read the file data into a scalar and treat that as a 
        ### filehandle...
        my $img_data = read_file($img_file, { binmode => ':raw'} );
        open my $scalar_fh, '<', \$img_data;        # Scalar as filehandle

        ### ...Either way, we create a Wx::Image from a filehandle.
        #my $img = Wx::Image->new($reg_fh, wxBITMAP_TYPE_PNG );
        my $img = Wx::Image->new($scalar_fh, wxBITMAP_TYPE_PNG );

        ### Create the bitmap from our Image
        my $bmp = Wx::Bitmap->new($img);

        ### And here's our StaticBitmap
        my $v = Wx::StaticBitmap->new(
            $self, -1, 
            $bmp,
            wxDefaultPosition,
            Wx::Size->new(39, 50),
            wxFULL_REPAINT_ON_RESIZE
        );
        return $v;
    }#}}}
    sub _build_bmp_stream_zip {#{{{
        my $self = shift;

=pod

Where _build_bmp_stream(), above, got its data by opening a regular file, this 
version gets its data by opening the assets.zip file and reading from it.

=cut

        my $zip_file = join '/', $self->app->bb->resolve(service => '/Directory/user'), 'assets.zip';
        my $zip = Archive::Zip->new($zip_file);
        my $zfh = Archive::Zip::MemberRead->new($zip, 'images/glyphs/beryl_39x50.png');

        my $binary;
        while( 1 ) {
            my $read = $zfh->read(my $buffer, 1024);
            $binary .= $buffer;
            last unless $read;
        }
        open my $sfh, '<', \$binary;

        my $img = Wx::Image->new($sfh, wxBITMAP_TYPE_PNG );
        my $bmp = Wx::Bitmap->new($img);

        my $v = Wx::StaticBitmap->new(
            $self, -1, 
            $bmp,
            wxDefaultPosition,
            Wx::Size->new(39, 50),
            wxFULL_REPAINT_ON_RESIZE
        );
        return $v;
    }#}}}
    sub _build_bmp_assets_zip {#{{{
        my $self = shift;

=pod

_build_bmp_stream_zip(), above, worked fine, but all that fooling around with 
Archive::Zip every time we want an image is icky.

Instead, this grabs the binary image data from our BreadBoard, which now knows 
how to pull the requested image data from our assets.zip file for us.

After getting that binary data, this is essentially identical to 
_build_bmp_stream_zip.

=cut

        my $img = $self->app->wxbb->resolve(service => '/Assets/images/glyphs/chalcopyrite.png');
        $img->Rescale(39, 50);
        my $bmp = Wx::Bitmap->new($img);

        my $v = Wx::StaticBitmap->new(
            $self, -1, 
            $bmp,
            wxDefaultPosition,
            Wx::Size->new(39, 50),
            wxFULL_REPAINT_ON_RESIZE
        );
        return $v;
    }#}}}
    sub _build_lbl_instructions {#{{{
        my $self = shift;
        my $v = Wx::StaticText->new(
            $self, -1, 
            "Each of the images below is being created using a different method.  See the code for details.",
            wxDefaultPosition, 
            Wx::Size->new(500, 25)
        );
        return $v;
    }#}}}
    sub _build_szr_main {#{{{
        my $self = shift;
        my $v = $self->build_sizer($self, wxVERTICAL, 'Main Sizer');
        return $v;
    }#}}}
    sub _build_szr_images {#{{{
        my $self = shift;
        my $v = $self->build_sizer($self, wxVERTICAL, 'Images');
        return $v;
    }#}}}
    sub _build_szr_instructions {#{{{
        my $self = shift;
        my $v = $self->build_sizer($self, wxVERTICAL, 'Instructions');
        return $v;
    }#}}}
    sub _set_events {#{{{
        my $self = shift;
        EVT_CLOSE(  $self,  sub{$self->OnClose(@_)}     );
    }#}}}

    sub OnClose {#{{{
        my $self    = shift;
        my $dialog  = shift;
        my $event   = shift;
        $self->Destroy;
        $event->Skip();
    }#}}}
    sub OnShowButton {#{{{
        my $self    = shift;
        my $dialog  = shift;
        my $event   = shift;
say "Show button";

    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;
