package Games::Lacuna::Webtools::Schema::Result::ResPushes;
use 5.010;
use base 'DBIx::Class::Core';
use Games::Lacuna::Schema::Result::Planet;

__PACKAGE__->table('Res_Pushes');
__PACKAGE__->add_columns( 
    id        => {data_type => 'integer', is_auto_increment => 1, is_nullable => 0, extra => {unsigned => 1} },
    Logins_id => {data_type => 'integer', is_nullable => 0, extra => {unsigned => 1}, is_foreign_key => 1 },
    from      => {data_type => 'integer', is_nullable => 0, is_foreign_key => 1},
    to        => {data_type => 'integer', is_nullable => 0, is_foreign_key => 1},
    hour      => {data_type => 'integer', is_nullable => 1},
    ship      => {data_type => 'varchar', size => 64, is_nullable => 1},
    res       => {data_type => 'varchar', size => 64, is_nullable => 1},
);
__PACKAGE__->set_primary_key( 'id' ); 
__PACKAGE__->belongs_to( 
    'login' => 
    'Games::Lacuna::Webtools::Schema::Result::Login',
    { 'foreign.id' => 'self.Logins_id'}
);  
__PACKAGE__->has_one(
    from_planet => 'Games::Lacuna::Webtools::Schema::Result::Planet', 
    { 'foreign.game_id' => 'self.from' }
);
__PACKAGE__->has_one(
    to_planet => 'Games::Lacuna::Webtools::Schema::Result::Planet', 
    { 'foreign.game_id' => 'self.to' }
);

1;
