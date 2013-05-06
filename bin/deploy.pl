#!/usr/bin/perl

use v5.14;
use FindBin;
use IO::Handle;
use lib $FindBin::Bin . "/../lib";
use LacunaWaX::Model::Container;
use LacunaWaX::Model::DefaultData;
use LacunaWaX::Model::LogsSchema;
use LacunaWaX::Model::Schema;
use version;

=pod

This exists to allow you to manually re-create LacunaWaX's databases.

However, if you're simply trying to get LacunaWaX running, you do not need to 
run this; it exists mainly as a convenience for anyone working on schema 
changes.

=cut


my $db_file     = $FindBin::Bin . '/../user/lacuna_app.sqlite';
my $db_log_file = $FindBin::Bin . '/../user/lacuna_log.sqlite';

if( -e $db_file or -e $db_log_file ) {
    say "
deploy.pl would clobber the currently-existing databases.  If you're sure you 
don't need them, please go delete them yourself and then run this again.
    ";
    exit;
}

autoflush STDOUT 1;
say "This takes a few seconds, please be patient...";

my $c = LacunaWaX::Model::Container->new(
    name        => 'my container',
    root_dir    => $FindBin::Bin . "/..",
    db_file     => $db_file,
    db_log_file => $db_log_file,
);
my $app_schema = $c->resolve( service => '/Database/schema' );
my $log_schema = $c->resolve( service => '/DatabaseLog/schema' );

$log_schema->deploy;
$app_schema->deploy;

my $d = LacunaWaX::Model::DefaultData->new();
$d->add_servers($app_schema);
$d->add_stations($app_schema);

say "Databases have been deployed.";


