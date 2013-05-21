use v5.14;
use utf8;
use warnings;


=pod

Any resolvable Wx components should be in here, rather than Container.pm.

=cut

package LacunaWaX::Model::WxContainer {
    use Archive::Zip;
    use Archive::Zip::MemberRead;
    use Bread::Board;
    use Carp;
    use English qw( -no_match_vars );
    use Moose;
    use MooseX::NonMoose;
    use Try::Tiny;
    use Wx qw(:everything);

    extends 'Bread::Board::Container';

    ### Assets
    has 'root_dir' => ( is => 'rw', isa => 'Str', required => 1 );

    ### Cache
    has 'cache_global'              => ( is => 'rw', isa => 'Int', lazy => 1, default => 1 );
    has 'cache_expires_variance'    => ( is => 'rw', isa => 'Num', lazy => 1, default => 0.25 );
    has 'cache_max_items'           => ( is => 'rw', isa => 'Int', lazy => 1, default => 20 );

    sub BUILD {
        my $self = shift;

        container $self => as {
            container 'Assets' => as {#{{{
                my $zipfile         = join q{/}, $self->root_dir, 'user/assets.zip';
                my $zip             = Archive::Zip->new($zipfile);
                service 'zip'       => $zip;
                service 'zipfile'   => $zipfile;

=pod

Provides services for all media assets used by the app.  Right now, "all media 
assets" consist of many .png files and a single .ico file.  

The Assets container will hold sub-containers for each type of asset; images, 
sounds, etc.  All of these assets are stored in a zip file.

Keep in mind that, though zip/unzip programs tend to make it look like their 
members are stored in nested directories inside the zip file, those members 
don't actually behave like files and directories in your filesystem.

So the containers and services provided under this Assets container have to be set 
up carefully so they end up resembling the familiar path structure to the user.  
See the images subcontainer for examples.

=cut

                container 'images' => as {#{{{

=pod

Creates and returns a Wx::Image of the requested image, which you can then rescale 
if needed and convert to a bitmap for display:

 my $img = $self->app->bb->resolve(service => '/Assets/glyphs/chalcopyrite.png');
 $img->Rescale(39, 50);
 my $bmp = Wx::Bitmap->new($img);

 my $v = Wx::StaticBitmap->new(
  $self, -1,
  $bmp,
  wxDefaultPosition,
  Wx::Size->new($img->GetWidth, $img->GetHeight),
  wxFULL_REPAINT_ON_RESIZE
 );

Also provides a 'zipfile' service that reports on exactly which file is being 
read from:

 $file = self->app->bb->resolve(service => '/Assets/zipfile');
 say $file; # '/path/to/assets.zip'



You can freely add more subdirectories under images/ in the main assets.zip 
file, and sub-containers and services will be created for those new 
subdirectories automatically without any code changes.

HOWEVER, you may only add a single level of subdirectories under images:

 ### Fine.
 images/my_new_subdirectory/
 images/my_new_subdirectory/my_new_image_1.png
 images/my_new_subdirectory/my_new_image_2.png

 ...then, in calling code...

 my $bmp = $self->app->wxbb->resolve(service => '/Assets/images/my_new_subdirectory/my_new_image_1.png');


 ### NOT Fine - the 'futher_nested_subdirectory' will not work.  If you 
 ### absolutely must have this, you'll need to update the code under the images 
 ### container.
 images/my_new_subdirectory/further_nested_subdirectory/
 images/my_new_subdirectory/further_nested_subdirectory/my_new_image_1.png
 images/my_new_subdirectory/further_nested_subdirectory/my_new_image_2.png
 ...



The Assets zip file currently contains different members for the same image if 
that image has different sizes:

    images/glyphs/chalcopyrite.png
    images/glyphs/chalcopyrite_39x50.png
    images/glyphs/chalcopyrite_79x100.png

I now plan to keep just 'chalcopyrite.png' and rescale it as needed, so I'll 
ultimately be able to get rid of all of the resized images in the .zip file, 
which should save some space and time.

=cut

                    my %dirs = ();

                    foreach my $member( $zip->membersMatching("images/.*(png|ico)\$") ) {
                        $member->fileName =~ m{images/([^/]+)/};
                        my $dirname = $1;
                        push @{$dirs{$dirname}}, $member;
                    }

                    foreach my $dir( keys %dirs ) { # 'glyphs', 'planetside', etc
                        container "$dir" => as {
                            foreach my $image_member(@{ $dirs{$dir} }) {
                                $image_member->fileName =~ m{images/$dir/(.+)$};
                                my $image_filename = $1; # just the image name, eg 'beryl.png'

                                service "$image_filename" => (
                                    block => sub {
                                        my $s = shift;
                                        my $zfh = Archive::Zip::MemberRead->new(
                                            $zip,
                                            $image_member->fileName,
                                        );
                                        my $binary;
                                        while(1) {
                                            my $buffer = q{};
                                            my $read = $zfh->read($buffer, 1024);
                                            $binary .= $buffer;
                                            last unless $read;
                                        }
                                        open my $sfh, '<', \$binary or croak "Unable to open stream: $ERRNO";
                                        my $img = Wx::Image->new($sfh, wxBITMAP_TYPE_ANY);
                                        close $sfh or croak "Unable to close stream: $ERRNO";
                                        return(wantarray) ? ($img, $binary) : $img;
                                    }
                                );
                            }
                        }
                    }
                };# images }}}
            };# Assets }}}
            container 'Cache' => as {#{{{
                service 'expires_variance'  => $self->cache_expires_variance;
                service 'global'            => $self->cache_global;
                service 'max_items'         => $self->cache_max_items;

                service 'raw_memory' => (#{{{
                    dependencies => {
                        expires_variance    => depends_on('/Cache/expires_variance'),
                        global              => depends_on('/Cache/global'),
                        max_items           => depends_on('/Cache/max_items'),
                    },
                    block => sub {
                        use CHI;
                        my $s = shift;
                        my $chi = CHI->new(
                            driver              => 'RawMemory',
                            expires_variance    => $s->param('expires_variance'),
                            global              => $s->param('global'),
                            max_items           => $s->param('max_items'),
                        );
                        return $chi;
                    },
                );#}}}
            };#}}}
            container 'Fonts' => as {#{{{

                ### para_text fontsize increases as number increases.  Swiss is 
                ### variable-width sans-serif (arial).  I know serif is 
                ### supposedly easier to read, but the ROMAN (serif) font is 
                ### Times New Roman and is just ugly and hurts my eyes.
                service 'para_text_1'       => Wx::Font->new(8,  wxSWISS, wxNORMAL, wxNORMAL, 0);
                service 'para_text_2'       => Wx::Font->new(10, wxSWISS, wxNORMAL, wxNORMAL, 0);
                service 'para_text_3'       => Wx::Font->new(12, wxSWISS, wxNORMAL, wxNORMAL, 0);
                service 'bold_para_text_1'  => Wx::Font->new(8,  wxSWISS, wxNORMAL, wxBOLD, 0);
                service 'bold_para_text_2'  => Wx::Font->new(10, wxSWISS, wxNORMAL, wxBOLD, 0);
                service 'bold_para_text_3'  => Wx::Font->new(12, wxSWISS, wxNORMAL, wxBOLD, 0);

                ### modern_text fontsize increases as number increases, like 
                ### para_text.  Modern is fixed-width.
                service 'modern_text_1'       => Wx::Font->new(8,  wxMODERN, wxNORMAL, wxNORMAL, 0);
                service 'modern_text_2'       => Wx::Font->new(10, wxMODERN, wxNORMAL, wxNORMAL, 0);
                service 'modern_text_3'       => Wx::Font->new(12, wxMODERN, wxNORMAL, wxNORMAL, 0);
                service 'bold_modern_text_1'  => Wx::Font->new(8,  wxMODERN, wxNORMAL, wxBOLD, 0);
                service 'bold_modern_text_2'  => Wx::Font->new(10, wxMODERN, wxNORMAL, wxBOLD, 0);
                service 'bold_modern_text_3'  => Wx::Font->new(12, wxMODERN, wxNORMAL, wxBOLD, 0);

                ### header fontsize decreases as number increases
                service 'header_1'   => Wx::Font->new(22, wxSWISS, wxNORMAL, wxBOLD, 0);
                service 'header_2'   => Wx::Font->new(20, wxSWISS, wxNORMAL, wxBOLD, 0);
                service 'header_3'   => Wx::Font->new(18, wxSWISS, wxNORMAL, wxBOLD, 0);
                service 'header_4'   => Wx::Font->new(16, wxSWISS, wxNORMAL, wxBOLD, 0);
                service 'header_5'   => Wx::Font->new(14, wxSWISS, wxNORMAL, wxBOLD, 0);
                service 'header_6'   => Wx::Font->new(12, wxSWISS, wxNORMAL, wxBOLD, 0);
                service 'header_7'   => Wx::Font->new(10, wxSWISS, wxNORMAL, wxBOLD, 0);
            };#}}}
        };

        return $self;
    }

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;

