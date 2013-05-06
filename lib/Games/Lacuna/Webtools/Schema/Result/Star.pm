package Games::Lacuna::Webtools::Schema::Result::Star;
use 5.010;
use Modern::Perl;
use Data::Dumper;
use base 'DBIx::Class::Core';

__PACKAGE__->table('Stars');
__PACKAGE__->add_columns( 
    id => {data_type => 'integer', size => 32, is_auto_increment => 1, is_nullable => 0, extra => {unsigned => 1} },

    name           => {data_type => 'varchar', size => 50, is_nullable => 1},
    x              => {data_type => 'integer', size => 50, is_nullable => 1},
    y              => {data_type => 'integer', size => 50, is_nullable => 1},
    zone           => {data_type => 'varchar', size => 50, is_nullable => 1},
    color          => {data_type => 'varchar', size => 50, is_nullable => 1},
);
__PACKAGE__->set_primary_key( 'id' ); 

__PACKAGE__->has_many( 'planets', 'Games::Lacuna::Webtools::Schema::Result::Planet', 'star_id' ); 

1;
