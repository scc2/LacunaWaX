package Games::Lacuna::Webtools::Schema::Result::PlanetPrefs;
use 5.010;
use base 'DBIx::Class::Core';


### build_spies commented out 06/19/2012, all references in code removed.
###
### If everything's good after a week, remove the comment here and drop the 
### column.


__PACKAGE__->table('PlanetPrefs');
__PACKAGE__->add_columns( 
    id              => {data_type => 'integer', is_auto_increment => 1, is_nullable => 0, extra => {unsigned => 1} },
    Logins_id       => {data_type => 'integer', is_nullable => 0, extra => {unsigned => 1} },
    planet_name     => {data_type => 'varchar', size => 64, is_nullable => 0},
    trash_run_at    => {data_type => 'integer', is_nullable => 1},
    trash_run_to    => {data_type => 'integer', is_nullable => 1},
    search_archmin  => {data_type => 'varchar', size => 32, is_nullable => 1},
    shipyard        => {data_type => 'varchar', size => 64, is_nullable => 0, default_value => q{}},
    glyph_home      => {data_type => 'varchar', size => 64, is_nullable => 1},
    glyph_transport => {data_type => 'varchar', size => 64, is_nullable => 0, default_value => q{}},
#    build_spies     => {data_type => 'tinyint', is_nullable => 0, default_value => q{0}},
    train_spies     => {data_type => 'tinyint', is_nullable => 0, default_value => q{1}},
);
__PACKAGE__->set_primary_key( 'id' ); 
__PACKAGE__->add_unique_constraint( login_planet => ['Logins_id', 'planet_name'] ); # name not ID because of all
__PACKAGE__->belongs_to( 
    'login' => 
    'Games::Lacuna::Webtools::Schema::Result::Login',
    { 'foreign.id' => 'self.Logins_id'}
);  

1;
