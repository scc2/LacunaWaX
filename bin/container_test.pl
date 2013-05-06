use v5.14;
use utf8;       # so literals and identifiers can be in UTF-8
use strict;     # quote strings, declare variables
use warnings;   # on by default
use warnings    qw(FATAL utf8);    # fatalize encoding glitches
use open        qw(:std :utf8);    # undeclared streams in UTF-8 - does not get along with use autodie.
use charnames   qw(:full :short);  # unneeded in v5.16
use Data::Dumper;

use FindBin;
use lib $FindBin::Bin . '/../lib';

use LacunaWaX::Container;
use LacunaWaX::WxContainer;

my $root_dir    = "$FindBin::Bin/..";
my $db_file     = join '/', ($root_dir, 'user', 'lacuna_app.sqlite');
my $db_log_file = join '/', ($root_dir, 'user', 'lacuna_log.sqlite');

my $bb = LacunaWaX::Container->new(
    name        => 'ScheduleContainer',
    db_file     => $db_file,
    db_log_file => $db_log_file,
);

my $wxbb = LacunaWaX::WxContainer->new(
    name => 'WxContainer',
);

my $chi  = $wxbb->resolve( service => '/Cache/raw_memory' );

my $broke = try {
    $wxbb->resolve( service => '/Cache/flurble' );
};


say 'foo';
