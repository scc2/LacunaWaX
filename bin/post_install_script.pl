#!/usr/bin/perl


### If upgrading the MAJOR version number from 1 to 2 (or to anything but 
### '1'), be sure to see fix_tables().


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


### Creates 'TestOne' and 'TestTwo' test tables if true.  For debugging only; 
### should usually be false.
my $create_test_tables = 0; 

### NOTES {#{{{
=pod

=head1 ABOUT

This script is run by the executable installer created by Cava Packager.  If 
you're running LacunaWaX from source, rather than from an executable (and if 
you're reading this, that's probably the case), then you have zero need to run 
this.

=head1 REGISTRY

The Cava installer adds some uninstall-related data into the registry.  But 
when it does this, it appears to be totally overwriting its own subtree.  So 
if you attempt to add extra data to that subtree, it will disappear the next 
time the installer gets run.

So leave Cava's subtree alone - dig data out of it as needed, but don't try to 
write anything there.  Instead, I'm using the subtree

 HKEY_LOCAL_MACHINE/Software/TMT Tools/LacunaWaX/

=head2 UNINSTALLING

Running the uninstaller will remove the Cava-generated registry keys, but not 
the TMT Tools/ subtree, as Cava's installer knows nothing about that stuff.

So if the user installs the program, then completely uninstalls it, then 
attempts to re-install it at a later date, the TMT Tools/ subtree will still 
exist.

But since this script runs POST INSTALL (derp), the Cava-generated subtree 
will also always exist.  By the time we get here, even on a brand-new, fresh 
install, this runs after the installer has already created that Cava subtree 
in the registry.

This all still works out OK.


Scenario 1 - Actual fresh install
    - Cava version exists in the registry, LacunaWaX version does not.  
      Databases get created, nothing is an upgrade.

Scenario 2 - Regular upgrade from previous version
    - Cava and LacunaWaX versions both exist in the registry.
    - Database files already exist.
    - ALL table creation subs get run; attempts to create any tables that 
      already exist fail silently as intended.
    - Already-existing tables that need to be altered get altered by 
      fix_old_tables() which compares the current $LacunaWaX::VERSION to the 
      LacunaWaX version in the registry.

Scenario 3 - User had a previous install, which they removed with the 
uninstaller.  They're now attempting to run a new version of the installer.  
The user thinks this is a fresh install.
    - Cava and LacunaWaX versions both exist in the registry.
    - The main and logs databases both still exist.  Since they get modified 
      during normal program runs, the uninstaller does not remove them.
    
    - As with Scenario 2:
        - ALL table creation subs get run; attempts to create any tables that 
          already exist fail silently as intended.
        - Already-existing tables that need to be altered get altered by 
          fix_old_tables() which compares the current $LacunaWaX::VERSION to 
          the LacunaWaX version in the registry.

    - So the user might think this is a "fresh" install, since they'd 
      previously run the uninstaller.  However, this is still an upgrade as 
      far as the databases are concerned.

Scenario 4 - User had a previous install, which they removed with the 
uninstaller.  The user ALSO went into their Program Files/TMT 
Tools/LacunaWaX/user/ directory and manually deleted their databases (or 
possibly they deleted the entire Program Files/TMT Tools/ directory).  They're 
now attempting to run a new version of the installer.  The user is sure this 
is a fresh install because of their manual deletions.
    - Cava and LacunaWaX versions both exist in the registry.
    - The main and logs databases do not exist since the user biffed them 
      manually.

    - ALL table creation subs get run, creating all tables in their most 
      current, updated form.

    - fix_old_tables() WILL be called if the old LacunaWaX version number in 
      the registry indicates that the old version is one that requires an 
      ALTER TABLE.
        - However, since the table creation subs themselves contain the tables 
          in their current, updated form, those tables actually do NOT need to 
          be altered.
        
    - This is still OK - the alter table statement is in a try/catch block, so 
      the attempt to alter the table into its already-existing form should end 
      up not causing any trouble.
        - This tested out fine.

=head1 VERSION NUMBERS

Cava's "DisplayVersion" in the registry is being set to Cava's internal 
version number, which I'm not using.

Starting with v1.16, I began adding my own subtree to the registry as noted 
above, setting the Version key to the value of $LacunaWaX::VERSION (that's 
what's being assigned to $lw_version).

Since that didn't start until v1.16, it's possible for $lw_version to be '0.0' 
but for $cava_version to be $SOMETHING.  This means that the user does have a 
previous version installed, and that version is < v1.16.  But past that, I 
can't tell which version they have.

=head1 DATABASE CHANGES WITH NEW VERSIONS

If your new version includes new tables:

    - Create a sub in here containing the new definitions; use your new 
      version number in the sub name:
        - see tables_1point0() for example

    - Modify create_main_tables_and_indexes() so it calls your new sub, 
      creating your new table.

If your new version alters an existing table:

    - Find the table's existing definition.  It will be in one of the 
      tables_VERSION() subs.  Update that definition to include your new 
      columns.  This will take care of any new installs.

    - See fix_old_tables().  This is what allows altering of older setups that 
      already have the table in question but which do not already have the 
      column in question.

=head2 REAON WE'RE NOT USING ->deploy

When this is run as part of the install process, these statements...
    - $schema->deploy_statements()
    - $schema->deploy()

...both cause the script to simply halt where either method is called.  Both 
methods work as expected from the CLI, so I do not know why they fail during 
installation.

However, creating a table using raw SQL works just fine from the install 
process.

=cut
### }#}}}


$Registry->Delimiter('/');
my $class_id            = 'CFA9E4F9-9CB0-1020-AAC5-BF3F2B732F6F';
my $cava_base_key       = 'HKEY_LOCAL_MACHINE/Software/Microsoft/Windows/CurrentVersion/Uninstall/{' . $class_id . '}_is1';
my $install_dir_key     = join '/', ($cava_base_key, 'InstallLocation');
my $cava_version_key    = join '/', ($cava_base_key, 'DisplayVersion');
my $display_name_key    = join '/', ($cava_base_key, 'DisplayName');
my $install_dir         = $Registry->{$install_dir_key};        # ends with a \
my $this_version        = $LacunaWaX::VERSION;
my $cava_version        = $Registry->{$cava_version_key}    // q{0.0};

my $tmt_key     = 'HKEY_LOCAL_MACHINE/Software/TMT Tools/';
my $lw_version  = $Registry->{ $tmt_key . "LacunaWaX/Version" } // '0.0';


open my $ilog, '>', $install_dir . 'install_log.txt';
my $dt = DateTime->now();
$ilog->autoflush(1);
say $ilog "---------- " . $dt->ymd . ' ' . $dt->hms . " ----------";
say $ilog "Install dir is '$install_dir'.";
say $ilog "this version: $this_version -- currently-installed version: $lw_version (Cava version: $cava_version)";

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


set_installdir_permissions($install_dir);
create_logs_tables_and_indexes($logs_schema);
create_main_tables_and_indexes($main_schema);

say $ilog q{};
my $upgrade_rv = is_upgrade($this_version, $lw_version, $cava_version);
if( $upgrade_rv ) {
    fix_old_tables($main_schema, $this_version, $lw_version);
}

my $d = LacunaWaX::Model::DefaultData->new();

say $ilog "Adding known servers";
$d->add_servers($main_schema);

say $ilog "Adding known stations";
$d->add_stations($main_schema);


### It looks wrong for "LacunaWaX/" to end with a delimiter and "/Version" to 
### also start with one.
### It is not wrong; this is how the module is documented, and it works.  
### Don't get clever.
say $ilog "Setting registry version to '$this_version'";
$Registry->{$tmt_key} = {
    "LacunaWaX/" => {
        "/Version" => $this_version
    }
};

say $ilog "---------- COMPLETE ----------";
close $ilog;


sub set_installdir_permissions {#{{{
    my $dir = shift;
    my $d   = LacunaWaX::Model::Directory->new( path => $dir );
    my $rv  = $d->make_world_writable;
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
                say $ilog "'$name' already exists; no need to re-create it.";
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
  reserve_glyphs integer not null default(0),
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
    my $inst_version    = shift;    # Whatever was in the registry as the previous version.  '0.0' if this is a brand new install.
    my $cava_version    = shift;    # Pre-1.16 there was no "inst_version".  In that case, if this is not '0.0', we're doing a pre-1.16 upgrade.

=pod

Returns true if the user has any previous version of LacunaWaX installed, else 
returns false.

=cut

    say $ilog "The version being installed right now is $new_version.";
    if( $cava_version eq '0.0' ) {
        say $ilog "No previous install version number was found.";
        return 0;
    }
    if( $inst_version eq '0.0' ) {
        say $ilog "Previous cava version exists, but no previous LacunaWaX version.  So we're upgrading from < 1.16.";
        return 1;
    }
    say $ilog "This is an upgrade.  The previously-installed version was $inst_version.";
    return 1;
}#}}}
sub fix_old_tables {#{{{
    my $schema          = shift;
    my $new_version     = shift;    # The version we're installing right now
    my $lw_version      = shift;    # The previously-installed lw version.  '0.0' means '< 1.16'

=pod

We should only get here if is_upgrade() returned true, so we already know that 
the current install is an upgrade.

However, since I didn't start setting LacunaWaXVersion in the registry until 
v1.16, it's completely possible for $lw_version to be '0.0' in here.

=cut


    if( $lw_version eq '0.0' ) {
        $lw_version = '1.0';
    }

    say $ilog "Upgrading tables from $lw_version to $new_version.";
    my( $imajor, $iminor, $bugfix_garbage ) = split/\./, $lw_version;
    unless( $imajor == 1 ) {
        say $ilog "GONNNNNNNNG!";
        say $ilog "The post install script is about to die because we're upgrading to an unexpected major version ($imajor).";
        say $ilog "That means that this install should be considered to have FAILED.";
        say $ilog "**********************";
        die "Installed major version number is unexpected; I don't know what to do with it.";
    }

    if( $iminor < 16 ) {
        say $ilog "Adding reserve_glyphs column to ArchMinPrefs table";
        add_reserve_glyphs_to_arch_min_prefs($schema);
    }

}#}}}
sub add_reserve_glyphs_to_arch_min_prefs {#{{{
    my $schema = shift;

    ### reserve_glyphs is new as of v1.16
    my $dbh = $schema->storage->dbh;
    my $tbl_exists_stmt = "SELECT reserve_glyphs FROM ArchMinPrefs where 1 = 1 LIMIT 1";
    my $test_sth = try {
        $dbh->prepare($tbl_exists_stmt);
    };
    ### If that worked, the reserve_glyphs table already exists so there's 
    ### nothing else for us to do.
    return if $test_sth;

    my @args = ();
    say $ilog "Altering the ArchMinPrefs table right now";
    my $alter_tbl_stmt = 'ALTER TABLE "main"."ArchMinPrefs" ADD COLUMN "reserve_glyphs" INTEGER NOT NULL DEFAULT 0';
    my $alter_tbl_sth = try {
        $dbh->prepare($alter_tbl_stmt);
    }
    catch {
        say $ilog "Attempt to alter ArchMinPrefs failed with $_";
    };
    if( $alter_tbl_sth ) {
        $alter_tbl_sth->execute;
    }
    else {
        say $ilog "try/catch passed but I still have no alter table statement.";
    }
}#}}}

