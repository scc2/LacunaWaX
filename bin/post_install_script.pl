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

=head1 REAON WE'RE NOT USING ->deploy

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

=head1 VERSION NUMBERS

"DisplayVersion" in the registry is being set by Cava, not by me, and it's 
being set to Cava's internal version number, which I'm not using.

Starting with v1.16, I began adding "LacunaWaXVersion" to the registry, set to 
the value of $LacunaWaX::VERSION.

So, in here, it's possible for $lw_version to be '0.0' but for $cava_version 
to be $SOMETHING.  This means that the user does have a previous version 
installed, and that version is < v1.16.  But past that, I can't tell which 
version they have.

=head1 UPDATING

When setting up a new version that includes new tables/indexes/constraints:
    - Create a sub in here containing the new definitions
        - see tables_1point0() for example

    - Modify create_main_tables_and_indexes() so it calls your new sub.

    - If your new version alters a table that existed in a previous version, 
      you'll need to change fix_old_tables() as appropriate.

=cut
### }#}}}

my $class_id = 'CFA9E4F9-9CB0-1020-AAC5-BF3F2B732F6F';

$Registry->Delimiter('/');
my $base_key            = 'HKEY_LOCAL_MACHINE/Software/Microsoft/Windows/CurrentVersion/Uninstall/{' . $class_id . '}_is1';
my $install_dir_key     = join '/', ($base_key, 'InstallLocation');
my $cava_version_key    = join '/', ($base_key, 'DisplayVersion');
my $lw_version_key      = join '/', ($base_key, 'LacunaWaXVersion');
my $display_name_key    = join '/', ($base_key, 'DisplayName');

my $install_dir     = $Registry->{$install_dir_key};        # ends with a \
my $this_version    = $LacunaWaX::VERSION;
my $cava_version    = $Registry->{$cava_version_key}    // q{0.0};
my $lw_version      = $Registry->{$lw_version_key}      // q{0.0};

open my $ilog, '>', $install_dir . 'install_log.txt';
my $dt = DateTime->now();
$ilog->autoflush(1);
say $ilog "---------- " . $dt->ymd . ' ' . $dt->hms . " ----------";
say $ilog "Install dir is '$install_dir'.";
say $ilog "this version: $this_version -- currently-installed version: $lw_version";

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

### This may go away.
say $ilog "Adding known stations";
$d->add_stations($main_schema);

### Set the DisplayVersion registry key to be equal to $LacunaWaX::VERSION so 
### on the next upgrade this script will know what had previously been 
### installed.
say $ilog "Setting registry version to '$this_version'";
$Registry->{$lw_version_key} = $this_version;

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

Returns true if the user has a previous version of LacunaWaX installed, else 
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
    my( $imajor, $iminor ) = split/\./, $lw_version;
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

    my @args = ();
    say $ilog "Altering the ArchMinPrefs table right now";
    $schema->storage->dbh_do(
        sub {
            my ($storage, $dbh, @args) = @_;
            $dbh->do('ALTER TABLE "main"."ArchMinPrefs" ADD COLUMN "reserve_glyphs" INTEGER NOT NULL DEFAULT 0')
        }, @args 
    );
    
}#}}}

