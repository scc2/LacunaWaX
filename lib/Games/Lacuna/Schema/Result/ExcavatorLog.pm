package Games::Lacuna::Schema::Result::ExcavatorLog;
use 5.010;
use Modern::Perl;
use Data::Dumper;
use base 'DBIx::Class::Core';

### The table this is using exists and makes sense, but is not currently being 
### used.

__PACKAGE__->table('ExcavatorLog');
__PACKAGE__->add_columns( 
    id        => {data_type => 'integer', is_nullable => 0, is_auto_increment => 1, extra => {unsigned => 1} },
    empire_id => {data_type => 'integer', is_nullable => 1},       # NOT unsigned!
    to_x      => {data_type => 'integer', is_nullable => 0},
    to_y      => {data_type => 'integer', is_nullable => 0},
    date      => {data_type => 'datetime', is_nullable => 1},
);
__PACKAGE__->set_primary_key( 'id' ); 
__PACKAGE__->add_unique_constraint( coords => [qw(to_x to_y)] ); 
__PACKAGE__->belongs_to( 
    'empire', 
    'Games::Lacuna::Schema::Result::Empire', 
    {'foreign.id' => 'self.empire_id'}
);  


1;
