package Games::Lacuna::Webtools::Schema::Result::ScheduleLog;
use 5.010;
use base 'DBIx::Class::Core';

__PACKAGE__->table('ScheduleLog');
__PACKAGE__->add_columns( 
    id          => {data_type => 'integer', size => 32, is_auto_increment => 1, is_nullable => 0, extra => {unsigned => 1} },
    empire_name => {data_type => 'varchar', size => 64, is_nullable => 0},
    level       => {data_type => 'varchar', size => 64, is_nullable => 0},
    timestamp   => {data_type => 'datetime', is_nullable => 1},
    message     => {data_type => 'text'},
);
__PACKAGE__->set_primary_key( 'id' ); 

1;
