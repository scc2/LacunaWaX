package Games::Lacuna::Schema::Result::Alliance;
use 5.010;
use Modern::Perl;
use Data::Dumper;
use base 'DBIx::Class::Core';

__PACKAGE__->table('Alliances');
__PACKAGE__->add_columns( 
    id           => {data_type => 'integer',  is_auto_increment => 1, is_nullable => 0},    # NOT unsigned!
    leader_id    => {data_type => 'integer',  is_nullable => 1, extra => {unsigned => 1}},
    influence    => {data_type => 'integer',  is_nullable => 1},
    name         => {data_type => 'varchar',  size => 255, is_nullable => 1},
    description  => {data_type => 'text', is_nullable => 1},
    date_created => {data_type => 'datetime', is_nullable => 1},


);
__PACKAGE__->set_primary_key( 'id' ); 
__PACKAGE__->add_unique_constraint( name => ['name'] ); 
__PACKAGE__->has_many( empires => 'Games::Lacuna::Schema::Result::Empire', {'foreign.alliance_id' => 'self.id'} ); 

### leader_id is nullable because we don't always know the answer.  has_one 
### and might_have require not nullable fields, so we use has_many.  Just 
### remember that means this will return a resultset, not a record.
__PACKAGE__->has_many( leader => 'Games::Lacuna::Schema::Result::Empire', {'foreign.id' => 'self.leader_id'} ); 

1;
