package Games::Lacuna::Webtools::Schema::Result::Planet;
use 5.010;
use Modern::Perl;
use Data::Dumper;
use DateTime;
use DateTime::Duration;
use base 'DBIx::Class::Core';

__PACKAGE__->table('Planets');
__PACKAGE__->add_columns( 
    id        => {data_type => 'integer', is_auto_increment => 1, is_nullable => 0, extra => {unsigned => 1} },
    game_id   => {data_type => 'integer', is_nullable => 1, extra => {unsigned => 1} },
    star_id   => {data_type => 'integer', is_nullable => 0, extra => {unsigned => 1}, is_foreign_key => 1 },

    name           => {data_type => 'varchar',  size => 64, is_nullable => 0},
    recorded       => {data_type => 'datetime', is_nullable => 1},
    zone           => {data_type => 'varchar',  size => 16, is_nullable => 1},
    x              => {data_type => 'integer',  is_nullable => 0},
    y              => {data_type => 'integer',  is_nullable => 0},
    image          => {data_type => 'varchar',  size => 64, is_nullable => 1},
    orbit          => {data_type => 'integer',  is_nullable => 1},
    size           => {data_type => 'integer',  is_nullable => 1},
    type           => {data_type => 'varchar',  size => 64, is_nullable => 1},
    excavator_sent => {data_type => 'datetime', size => 64, is_nullable => 1},
    inhabited_by   => {data_type => 'varchar',  size => 64, is_nullable => 1},
    current        => {data_type => 'integer',  size => 64, is_nullable => 1},

    anthracite   => {data_type => 'integer', is_nullable => 1},
    bauxite      => {data_type => 'integer', is_nullable => 1},
    beryl        => {data_type => 'integer', is_nullable => 1},
    chalcopyrite => {data_type => 'integer', is_nullable => 1},
    chromite     => {data_type => 'integer', is_nullable => 1},
    fluorite     => {data_type => 'integer', is_nullable => 1},
    galena       => {data_type => 'integer', is_nullable => 1},
    goethite     => {data_type => 'integer', is_nullable => 1},
    gold         => {data_type => 'integer', is_nullable => 1},
    gypsum       => {data_type => 'integer', is_nullable => 1},
    halite       => {data_type => 'integer', is_nullable => 1},
    kerogen      => {data_type => 'integer', is_nullable => 1},
    magnetite    => {data_type => 'integer', is_nullable => 1},
    methane      => {data_type => 'integer', is_nullable => 1},
    monazite     => {data_type => 'integer', is_nullable => 1},
    rutile       => {data_type => 'integer', is_nullable => 1},
    sulfur       => {data_type => 'integer', is_nullable => 1},
    trona        => {data_type => 'integer', is_nullable => 1},
    uraninite    => {data_type => 'integer', is_nullable => 1},
    zircon       => {data_type => 'integer', is_nullable => 1},
    water        => {data_type => 'integer', is_nullable => 1},
    empire_id    => {data_type => 'integer', is_nullable => 1},
);
__PACKAGE__->set_primary_key( 'id' ); 
__PACKAGE__->add_unique_constraints( 
    game_id => ['game_id'],
    coords  => [qw(x y)],
); 

__PACKAGE__->belongs_to( 
    'star' => 
    'Games::Lacuna::Webtools::Schema::Result::Star',
    { 'foreign.id' => 'self.star_id'}
);  

1;
