package Games::Lacuna::Webtools::Schema::Result::Enum_SpyTasks;
use 5.010;
use base 'DBIx::Class::Core';

__PACKAGE__->table('Enum_SpyTasks');
__PACKAGE__->add_columns( 
    id    => {data_type => 'integer', is_auto_increment => 1, is_nullable => 0, extra => {unsigned => 1} },
    name  => {data_type => 'varchar', size => 32, is_nullable => 0 },
);
__PACKAGE__->set_primary_key( 'id' ); 

1;
