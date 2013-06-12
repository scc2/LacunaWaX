#!/usr/bin/perl

use v5.14;
use version;
use warnings;
use DateTime;
use English qw( -no_match_vars );
use File::Copy;
use File::Spec;
use FindBin;
use IO::Handle;
use Try::Tiny;
use Win32::TieRegistry;
use lib $FindBin::Bin . "/../lib";
use LacunaWaX;
use LacunaWaX::Model::DefaultData;
use LacunaWaX::Model::Directory;
use LacunaWaX::Model::LogsSchema;
use LacunaWaX::Model::Schema;

my $class_id = 'CFA9E4F9-9CB0-1020-AAC5-BF3F2B732F6F';

=pod


This script is run by the executable installer created by Cava Packager.  If 
you're running LacunaWaX from source, rather than from an executable (and if 
you're reading this, that's probably the case), then you have zero need to run 
this.



When this is run as part of the install process, these statements...
    - $schema->deploy_statements()
    - $schema->deploy()

...both cause the script to simply halt where either method is called.  But 
both methods work as expected from the CLI, so I do not know why they fail 
during installation.

However, creating a table using raw SQL works just fine from the install 
process.

So I'm abandoning deploy, for now at least, in favor of hard-coded SQL.  This 
works, but it means that any changes made to the schemas need to be reflected 
here.



This script's flow:
    - Set perms on install dir to world-everything-able
        - This could probably be reduced to install_dir/"user"/

    - Attempt to create all tables/indexes/constraints needed for the app
        - This is done in a try{} block, so attempts to create any tables that 
          already exist as the result of a previous install will throw 
          exceptions, which will be caught and ignored.
        - create_main_tables_and_indexes() is doing this creation.

    - Determine whether this install is an upgrade to a previous install
        - If it is an upgrade, and any of the previously-existing tables have 
          been changed in the current version of the app, alter those tables 
          as necessary.
        - Right now, fix_old_tables, which is what's meant to perform this 
          upgrade, is a noop, but it is being called.

    - Add default data to the fresh databases
        - This currently consists of the known game servers, and known SMA space 
          stations.
            - When LacunaWaX sees a body for the first time, it can't know if 
              that body is a SS or a Planet.  The first time the user clicks on 
              that body's name in the tree, LacunaWaX will figure out and 
              remember which type that body is.  But this requires that you 
              click on all of your SSs on the first LacunaWaX run, then shut 
              down and restart.
            - Maintaining a list of known SSs saves people who have never 
              installed LacunaWaX from doing all that clicking.
            - But only SMA stations are currently recorded, as that's all I have 
              convenient access to.  It's recommended that you add your 
              alliance's SS.



When setting up a new version that includes new tables/indexes/constraints:
    - Create a sub in here containing the new definitions
        - see tables_1point0() for example

    - Modify create_main_tables_and_indexes() so it calls your new sub.

    - If your new version alters a table that existed in a previous version, 
      you'll need to change fix_old_tables() as appropriate.


=cut


### Creates 'TestOne' and 'TestTwo' test tables if true.
my $create_test_tables = 0; 


$Registry->Delimiter('/');
my $base_key                = 'HKEY_LOCAL_MACHINE/Software/Microsoft/Windows/CurrentVersion/Uninstall/{' . $class_id . '}_is1';
my $install_dir_key         = join '/', ($base_key, 'InstallLocation');
my $install_version_key     = join '/', ($base_key, 'DisplayVersion');
my $display_name_key        = join '/', ($base_key, 'DisplayName');

my $install_dir                     = $Registry->{$install_dir_key};        # ends with a \
my $currently_installed_version     = $Registry->{$install_version_key};
my $this_version                    = $LacunaWaX::VERSION;
my $display_name                    = $Registry->{$display_name_key};       # 'LacunaWaX'


my $dt = DateTime->now();

open my $ilog, '>', $install_dir . 'install_log.txt';
#open my $ilog, '>', 'C:/Documents and Settings/Jon/Desktop/' . 'install_log.txt';
say $ilog "Install dir is '$install_dir'.";

$ilog->autoflush(1);
say $ilog "---------- " . $dt->ymd . ' ' . $dt->hms . " ----------";


my $main_path   = $install_dir . 'user/lacuna_app.sqlite';
my $logs_path   = $install_dir . 'user/lacuna_log.sqlite';
$main_path =~ s{\\}{/}g;
$logs_path =~ s{\\}{/}g;
say $ilog "Deploying main database to $main_path, logs database to $logs_path.";
my $main_dsn    = "DBI:SQLite:dbname=$main_path";
my $logs_dsn    = "DBI:SQLite:dbname=$logs_path";
my $sql_options = {sqlite_unicode => 1, quote_names => 1};
my $main_schema = LacunaWaX::Model::Schema->connect($main_dsn, $sql_options)     or die "no main schema: $!";
my $logs_schema = LacunaWaX::Model::LogsSchema->connect($logs_dsn, $sql_options) or die "no logs schema: $!";


say $ilog "Setting perms";
set_installdir_permissions($install_dir);
say $ilog '';

say $ilog "Creating logs schema elements";
create_logs_tables_and_indexes($logs_schema);
say $ilog '';

say $ilog "Creating main schema elements";
create_main_tables_and_indexes($main_schema);
if( is_upgrade($this_version, $currently_installed_version) ) {
    say $ilog "Upgrade, so fixing old tables";
    fix_old_tables($main_schema, $this_version, $currently_installed_version);
}
say $ilog '';

my $d = LacunaWaX::Model::DefaultData->new();

say $ilog "Adding known servers";
$d->add_servers($main_schema);
say $ilog '';

### This may go away.
say $ilog "Adding known stations";
$d->add_stations($main_schema);


### Set the DisplayVersion registry key to be equal to $LacunaWaX::VERSION so 
### on the next upgrade this script will know what had previously been 
### installed.
$Registry->{$install_version_key} = $this_version;

say $ilog "---------- COMPLETE ----------";
close $ilog;


sub set_installdir_permissions {#{{{
    my $dir = shift;
    my $d   = LacunaWaX::Model::Directory->new( path => $dir );
    my $rv  = $d->make_world_writable;
    say $ilog "RV on setting perms on installdir ($dir): '$rv'";
    return $rv;
}#}}}
sub create_logs_tables_and_indexes {#{{{
    my $schema  = shift;
    my $dbh     = $schema->storage->dbh;

    ### Must create all the tables before creating the indexes.

    say $ilog "-=-=-=-";
    say $ilog "Generating Logs Schema:";
    my( $tables, $indexes )  = tables_logs();
    foreach my $hr( $tables, $indexes ) {
        while( my($name,$stmt) = each %{$hr} ) {
            say $ilog "Attempting to create '$name':";
            try {
                $dbh->do($stmt);
            }
            catch {
                say $ilog "'$name' already exists; no need to re-create it. ($_)";
            };
        }
    }

    say $ilog "-=-=-=-";

}#}}}
sub create_main_tables_and_indexes {#{{{
    my $schema  = shift;
    my $dbh     = $schema->storage->dbh;

    ### Must create all the tables before creating the indexes.

    say $ilog "-=-=-=-";
    say $ilog "Generating 1.0 Schema:";
    my( $one_point_oh_tables, $one_point_oh_indexes) = tables_1point0();
    foreach my $hr( $one_point_oh_tables, $one_point_oh_indexes ) {
        while( my($name,$stmt) = each %{$hr} ) {
            say $ilog "Attempting to create '$name':";
            try {
                $dbh->do($stmt);
            }
            catch {
                say $ilog "'$name' already exists; no need to re-create it.";
            };
        }
    }
    say $ilog "-=-=-=-";

    say $ilog "-=-=-=-";
    say $ilog "Generating 1.1 Schema:";
    my( $one_point_one_tables, $one_point_one_indexes ) = tables_1point1();
    foreach my $hr( $one_point_one_tables, $one_point_one_indexes ) {
        while( my($name,$stmt) = each %{$hr} ) {
            say $ilog "Attempting to create '$name':";
            try {
                $dbh->do($stmt);
            }
            catch {
                say $ilog "'$name' already exists; no need to re-create it.";
            };
        }
    }
    say $ilog "-=-=-=-";

    say $ilog "-=-=-=-";
    say $ilog "Generating 1.10 Schema:";
    my( $one_point_ten_tables, $one_point_ten_indexes ) = tables_1point10();
    foreach my $hr( $one_point_ten_tables, $one_point_ten_indexes ) {
        while( my($name,$stmt) = each %{$hr} ) {
            say $ilog "Attempting to create '$name':";
            try {
                $dbh->do($stmt);
            }
            catch {
                say $ilog "'$name' already exists; no need to re-create it.";
            };
        }
    }
    say $ilog "-=-=-=-";

    if( $create_test_tables ) {
        say $ilog "-=-=-=-";
        say $ilog "Generating TEST Schema:";
        my( $test_tables, $test_indexes) = tables_testing();
        foreach my $hr( $test_tables, $test_indexes ) {
            while( my($name,$stmt) = each %{$hr} ) {
                try {
                    $dbh->do($stmt);
                }
                catch {
                    say $ilog "'$name' already exists; no need to re-create it.";
                };
            }
        }
        say $ilog "-=-=-=-";
    }

}#}}}
sub tables_logs {#{{{#{{{

    my $table_statements = {};
    my $index_statements = {};

    $table_statements->{'Logs'} = '
CREATE TABLE Logs (
  id INTEGER PRIMARY KEY NOT NULL,
  run integer NOT NULL,
  level varchar(16),
  component varchar(32),
  datetime datetime,
  message text
)';
    $index_statements->{'Logs_index_component'} = 'CREATE INDEX "Logs_component" ON "Logs" ("component" ASC)';
    $index_statements->{'Logs_index_datetime'}  = 'CREATE INDEX "Logs_datetime" ON "Logs" ("datetime" ASC)';
    $index_statements->{'Logs_index_run'}       = 'CREATE INDEX "Logs_run" ON "Logs" ("run" ASC)';

    return( $table_statements, $index_statements );
}#}}}#}}}
sub tables_1point0 {#{{{#{{{

    my $table_statements = {};
    my $index_statements = {};

    $table_statements->{'AppPrefsKeystore'} = '
CREATE TABLE AppPrefsKeystore (
  id INTEGER PRIMARY KEY NOT NULL,
  name varchar(64) NOT NULL,
  value varchar(64)
)';

    $table_statements->{'BodyTypes'} = '
CREATE TABLE BodyTypes (
  id INTEGER PRIMARY KEY NOT NULL,
  body_id integer NOT NULL,
  server_id integer,
  type_general varchar(16)
)';
    $index_statements->{'BodyTypes_index_body_id'} = 'CREATE INDEX BodyTypes_body_id ON BodyTypes (body_id)';
    $index_statements->{'BodyTypes_index_type_general'} = 'CREATE INDEX BodyTypes_type_general ON BodyTypes (type_general)';
    $index_statements->{'BodyTypes_constraint_one_per_server'} = 'CREATE UNIQUE INDEX one_per_server ON BodyTypes (body_id, server_id)';

    $table_statements->{'ServerAccounts'} = '
CREATE TABLE ServerAccounts (
  id INTEGER PRIMARY KEY NOT NULL,
  server_id integer NOT NULL,
  username varchar(64),
  password varchar(64),
  default_for_server integer,
  FOREIGN KEY(server_id) REFERENCES Servers(id)
)';
    $index_statements->{'ServerAccounts_index_server_id'} = 'CREATE INDEX ServerAccounts_idx_server_id ON ServerAccounts (server_id)';

    $table_statements->{'Servers'} = q{
CREATE TABLE Servers (
  id INTEGER PRIMARY KEY NOT NULL,
  name varchar(32) NOT NULL,
  url varchar(64) NOT NULL,
  protocol varchar(8) DEFAULT 'http'
)};
    $index_statements->{'Servers_constraint_unique_by_name'} = 'CREATE UNIQUE INDEX unique_by_name ON Servers (name)';

    $table_statements->{'SpyTrainPrefs'} = '
CREATE TABLE SpyTrainPrefs (
  id INTEGER PRIMARY KEY NOT NULL,
  server_id integer NOT NULL,
  spy_id integer NOT NULL,
  train varchar(32)
)';
    $index_statements->{'SpyTrainPrefs_index_spy_id'} = 'CREATE INDEX SpyTrainPrefs_spy_id ON SpyTrainPrefs (spy_id)';
    $index_statements->{'SpyTrainPrefs_index_train'} = 'CREATE INDEX SpyTrainPrefs_train ON SpyTrainPrefs (train)';

    return( $table_statements, $index_statements );
}#}}}#}}}
sub tables_1point1 {#{{{
    my $table_statements = {};
    my $index_statements = {};

    $table_statements->{'ArchMinPrefs'}  = '
CREATE TABLE ArchMinPrefs (
  id INTEGER PRIMARY KEY NOT NULL,
  server_id integer NOT NULL,
  body_id integer NOT NULL,
  glyph_home_id integer,
  pusher_ship_name varchar(32),
  auto_search_for varchar(32)
) ';
    $index_statements->{'ArchMinPrefs_index_body_id'} = 'CREATE INDEX ArchMinPrefs_body_id ON ArchMinPrefs (body_id)';
    $index_statements->{'ArchMinPrefs_index_server_id'} = 'CREATE INDEX ArchMinPrefs_server_id ON ArchMinPrefs (server_id)';
    $index_statements->{'ArchMinPrefs_constraint_one_per_body'} = 'CREATE UNIQUE INDEX one_per_body ON ArchMinPrefs (server_id, body_id)';

    $table_statements->{'ScheduleAutovote'}  = q{
CREATE TABLE ScheduleAutovote (
  id INTEGER PRIMARY KEY NOT NULL,
  server_id integer NOT NULL,
  proposed_by varchar(16) NOT NULL DEFAULT 'all'
)};

    $table_statements->{'SitterPasswords'}  = '
CREATE TABLE SitterPasswords (
  id INTEGER PRIMARY KEY NOT NULL,
  server_id integer,
  player_id integer,
  player_name varchar(64),
  sitter varchar(64)
)';
    $index_statements->{'SitterPasswords_constraint_one_player_per_server'} = 'CREATE UNIQUE INDEX one_player_per_server ON SitterPasswords (server_id, player_id)';
    
    return( $table_statements, $index_statements );
}#}}}
sub tables_1point10 {#{{{
    my $table_statements = {};
    my $index_statements = {};

    $table_statements->{'LotteryPrefs'}  = '
CREATE TABLE LotteryPrefs (
  id INTEGER PRIMARY KEY NOT NULL,
  server_id integer NOT NULL,
  body_id integer NOT NULL,
  count integer
)
';
    $index_statements->{'LotteryPrefs_body'} = 'CREATE UNIQUE INDEX LotteryPrefs_body ON LotteryPrefs (body_id, server_id)';
    
    return( $table_statements, $index_statements );
}#}}}
sub tables_testing {#{{{
    my $table_statements = {};

    $table_statements->{'TestOne'}  = '
CREATE TABLE TestOne (
  id INTEGER PRIMARY KEY NOT NULL,
  fname varchar(32),
  lname varchar(32)
) ';
    $table_statements->{'TestTwo'}  = '
CREATE TABLE TestTwo (
  id INTEGER PRIMARY KEY NOT NULL,
  fname varchar(32),
  lname varchar(32)
) ';

    return( $table_statements, {} );
}#}}}
sub is_upgrade {#{{{
    my $new_version     = shift;    # $LacunaWaX::VERSION
    my $inst_version    = shift;    # Whatever was in the registry as the previous version

    say $ilog "The version being installed right now is $new_version.";
    unless($inst_version) {
        say $ilog "No previous install version number was found.";
        $inst_version = 0;
    }
    say $ilog "The previously-installed version was $inst_version.";

    ### CHECK
    ### This is simplistic and naive and will probably need to be updated at 
    ### some point.
    my($text, $is_upgrade) = ( $inst_version eq $new_version )
        ? ('is not', 0) : ('is', 1);

    say $ilog "This install $text an upgrade to a previous install.";
    return $is_upgrade;
}#}}}
sub fix_old_tables {#{{{
    my $schema          = shift;
    my $new_version     = shift;
    my $inst_version    = shift;

    say $ilog "Upgrading tables from $inst_version to $new_version.";

    my $some_sort_of_table_altering_is_needed = 0;
    if( $some_sort_of_table_altering_is_needed ) {
        ### alter them as appropriate.
    }

    ### 1.0 Tables:
    ###     AppPrefsKeystore
    ###     BodyTypes
    ###     ServerAccounts
    ###     Servers
    ###     SpyTrainPrefs

    ### 1.1 (rel 1) Tables:
    ###     + ArchMinPrefs
    ###     + ScheduleAutovote

    ### 1.1 (rel 2) Tables:
    ###     + SitterPasswords
}#}}}

