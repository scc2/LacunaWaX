use v5.14;
use FindBin;
use Getopt::Long;

use lib $FindBin::Bin . '/../lib';

use LacunaWaX::Container;
use LacunaWaX::Schedule;


my $schedule = q{};
GetOptions(
    'schedule=s' => \$schedule,
);

my $root_dir    = "$FindBin::Bin/..";
my $db_file     = join '/', ($root_dir, 'user', 'lacuna_app.sqlite');
my $db_log_file = join '/', ($root_dir, 'user', 'lacuna_log.sqlite');

my $bb = LacunaWaX::Container->new(
    name        => 'ScheduleContainer',
    root_dir    => $root_dir,
    db_file     => $db_file,
    db_log_file => $db_log_file,
);

### For now, just instantiating this runs the scheduler.  This may change.
my $scheduler = LacunaWaX::Schedule->new( 
    bb       => $bb,
    schedule => $schedule,
);

exit 0;

