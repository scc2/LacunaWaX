use Modern::Perl;
use Data::Dumper; $Data::Dumper::Indent = 1;
use FindBin;

use lib $FindBin::Bin . "/../lib";
use LacunaWaX::Container;
use LacunaWaX::Schema;
use LacunaWaX::LogsSchema;


my $c = LacunaWaX::Container->new(
    name        => 'my container',
    db_file     => 'C:/Program Files/TMT Tools/LacunaWaX/user/lacuna_app.sqlite',
    db_log_file => 'C:/Program Files/TMT Tools/LacunaWaX/user/lacuna_log.sqlite',
    root_dir    => 'C:/Program Files/TMT Tools/LacunaWaX'
);

my $schema = $c->resolve( service => '/Database/schema' );

#my $sql_options = {sqlite_unicode => 1, quote_names => 1};
#my $dsn    = 'DBI:SQLite:dbname=C:\Program Files\TMT Tools\LacunaWaX\user\lacuna_log.sqlite';
#my $schema = LacunaWaX::LogsSchema->connect($dsn, $sql_options);



#if( my @rs = $schema->resultset('BodyTypes')->search({ body_id => 473071, server_id => 1, type_general => 'space station'}) ) {
if( my $r = $schema->resultset('BodyTypes')->search({ body_id => 473071, server_id => 1})->single ) {
    say $r->body_id . " is of type " . $r->type_general;
    say '---';
}


sub seconds_till {#{{{
    my $self        = shift;
    my $target_time = shift;
    my $origin_time = shift || DateTime->now(time_zone => $target_time->time_zone);

=head2 seconds_till

Returns the seconds difference between two times.  If no second (origin) time 
is given, now() is assumed.

say $client->seconds_till( $plan_rec->datetime ) . " seconds between now and the planned arrival time.";
say $client->seconds_till( $target_dt, $origin_dt ) . " seconds from the origin till the target.";

If you pass the second (origin) argument, it must be in the same timezone as 
the first.

=cut
    ref $target_time eq 'DateTime' or die "target_time arg must be a DateTime object.";
    ref $origin_time eq 'DateTime' or die "optional origin_time arg must be undef or a DateTime object.";

    my $ct = $target_time->clone->set_time_zone('floating');
    my $co = $origin_time->clone->set_time_zone('floating');

    #my $dur         = $target_time - $origin_time;
    my $dur         = $ct - $co;
    #my $later       = $origin_time->clone->add_duration($dur);
    my $later       = $co->clone->add_duration($dur);
    #my $seconds_dur = $later->subtract_datetime_absolute($origin_time);
    my $seconds_dur = $later->subtract_datetime_absolute($co);
    return $seconds_dur->seconds;
}#}}}
sub db_function {#{{{
    

    my $rec = $schema->resultset('AttackShips')->search(
        {
            body_id => 157231,
            attack_plan_id => 2,
        },
        {
            select  => [ { MIN => 'ship_speed'} ],
            as      => 'speed'
        }
    )->single;

    say $rec->get_column('speed');
}#}}}

