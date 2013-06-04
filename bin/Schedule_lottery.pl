use v5.14;
use DateTime::TimeZone;
use FindBin;
use Getopt::Long;

use lib $FindBin::Bin . '/../lib';

use LacunaWaX::Model::Container;
use LacunaWaX::Schedule;

my $root_dir    = "$FindBin::Bin/..";
my $db_file     = join '/', ($root_dir, 'user', 'lacuna_app.sqlite');
my $db_log_file = join '/', ($root_dir, 'user', 'lacuna_log.sqlite');

my $bb = LacunaWaX::Model::Container->new(
    name            => 'ScheduleContainer',
    root_dir        => $root_dir,
    db_file         => $db_file,
    db_log_file     => $db_log_file,
    log_time_zone   => DateTime::TimeZone->new( name => 'local' )->name() || 'UTC',
);

my $scheduler = LacunaWaX::Schedule->new( 
    bb       => $bb,
    schedule => 'lottery',
);

exit 0;

