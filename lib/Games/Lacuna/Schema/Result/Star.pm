package Games::Lacuna::Schema::Result::Star;
use 5.010;
use Modern::Perl;
use Data::Dumper;
use base 'DBIx::Class::Core';

__PACKAGE__->table('Stars');
__PACKAGE__->add_columns( 
    id => {data_type => 'integer', size => 32, is_auto_increment => 1, is_nullable => 0, extra => {unsigned => 1} },

    ### All the columns in quotes need to go away; they're left over from my 
    ### Excel sheet.  Same with 'Notes'.

    name           => {data_type => 'varchar', size => 50, is_nullable => 1},
    x              => {data_type => 'integer', size => 50, is_nullable => 1},
    y              => {data_type => 'integer', size => 50, is_nullable => 1},
    zone           => {data_type => 'varchar', size => 50, is_nullable => 1},
    color          => {data_type => 'varchar', size => 50, is_nullable => 1},
);
__PACKAGE__->set_primary_key( 'id' ); 

__PACKAGE__->has_many( 'planets', 'Games::Lacuna::Schema::Result::Planet', 'star_id' ); 

1;
