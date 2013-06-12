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

As part of Cava's build process, it copies everything in ROOT/user to 
ROOT/Cava/release/LacunaWaX/user/.  This includes the live databases you're 
using if you're running the program from source, and these databases include 
your login credentials and logs as well as all of your preferences.

We don't want to install our personal databases into a new install, so this 
deletes those from the release directory.

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

