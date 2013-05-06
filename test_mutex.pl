use v5.14;
use utf8;      # so literals and identifiers can be in UTF-8
use warnings  qw(FATAL utf8);    # fatalize encoding glitches
use open      qw(:std :utf8);    # undeclared streams in UTF-8
use Data::Dumper;

use lib 'lib';
use LacunaWaX::Model::Mutex;

my $bb = LacunaWaX::Model::Container->new(
    name        => 'my container',
    root_dir    => 'C:\Documents and Settings\Jon\My Documents\work\LacunaWaX',
    db_file     => 'C:\Documents and Settings\Jon\My Documents\work\LacunaWaX\user\lacuna_app.sqlite', 
    db_log_file => 'C:\Documents and Settings\Jon\My Documents\work\LacunaWaX\user\lacuna_log.sqlite',
);

my $m = LacunaWaX::Model::Mutex->new( bb => $bb, name => 'jontest' );

say "attempting to obtain exclusive lock.";
if( $m->lock_exnb ) {
}
else {
    say "found existing scheduler lock; this run will pause until the lock releases.";
    $m->lock_ex;
}
say " succesfully obtained exclusive lock.";

sleep 10;

