use v5.14;
use version;
use warnings;
use Cava::Packager;
use Cava::Packager::Release;
use File::Copy;
use FindBin;

use lib $FindBin::Bin . "/../lib";
use LacunaWaX;

=pod

Post build script, called by Cava packager on scan and build.

Cava Packager Utilities docs:
http://www.cavapackager.com/appdocs/utilities.htm

=cut

my $release      = Cava::Packager::Release->new();
my $rp           = $release->get_release_path;

Cava::Packager::SetInfoProductVersion( version->parse($LacunaWaX::VERSION )->normal );


### The database copies in ../user/ get copied into "cava release 
### directory"/user/* as part of Cava's build process - those contain any of my 
### data I've added from running the program from source.
###
### The install process re-creates those databases cleanly using deploy(), so I 
### don't need these copies hanging around; just remove them.
delete_old_databases($rp);

sub delete_old_databases {#{{{
    my $release_path = shift;

=pod

As part of Cava's build process, it copies everything currently in ROOT/user 
to ROOT/Cava/release/LacunaWaX/user/, and those files will be installed by the 
installer created by Cava.

So if you're working on LacunaWaX code and running the program from source, 
that's where the databases you're working on will be kept.  And they'll end up 
being installed by everyone who uses the installer you end up creating.

And those databases contain your own empire name, password, and any sitters 
you entered into the sitter manager, along with all of your other preferences.  
We don't want to publish that.

So this deletes those databases from the release directory.

=cut

    my $personal_main_db = $release_path . '/user/lacuna_app.sqlite';
    my $personal_logs_db = $release_path . '/user/lacuna_log.sqlite';
    if( -e $personal_main_db ) {
        unlink $personal_main_db;
    }
    if( -e $personal_logs_db ) {
        unlink $personal_logs_db;
    }
}#}}}

