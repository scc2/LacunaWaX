package Games::Lacuna::Client::Task;
use feature ':5.10';
use Moose::Role;

BEGIN {
    my $file_id  = '$Id: Task.pm 14 2012-12-10 23:19:27Z jon $';
    my $file_url = '$URL: https://tmtowtdi.gotdns.com:15000/svn/LacunaWaX/trunk/lib/Games/Lacuna/Client/Task.pm $';
    my $revision = '$Rev: 14 $';
    $Games::Lacuna::CLient::Task::VERSION = '0.1.' . join '', $revision =~ m/(\d+)/;
}

### Required args
has 'client' => ( isa => 'Games::Lacuna::Client::App', is => 'rw', required => 1 );

1;

