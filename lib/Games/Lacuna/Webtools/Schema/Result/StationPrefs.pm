package Games::Lacuna::Webtools::Schema::Result::StationPrefs;
use 5.010;
use base 'DBIx::Class::Core';

__PACKAGE__->table('StationPrefs');
__PACKAGE__->add_columns( 
    id                => {data_type => 'integer', is_auto_increment => 1, is_nullable => 0, extra => {unsigned => 1} },
    Logins_id         => {data_type => 'integer', is_nullable => 0, extra => {unsigned => 1} },
    station_id        => {data_type => 'integer', is_nullable => 0},
    agree_owner_vote  => {data_type => 'bool',    is_nullable => 1},
    agree_leader_vote => {data_type => 'bool',    is_nullable => 1},
    agree_all_vote    => {data_type => 'bool',    is_nullable => 1},
);
__PACKAGE__->set_primary_key( 'id' ); 
__PACKAGE__->add_unique_constraint( login_station => ['Logins_id', 'station_id'] );
__PACKAGE__->belongs_to( 
    'login' => 
    'Games::Lacuna::Webtools::Schema::Result::Login',
    { 'foreign.id' => 'self.Logins_id'}
);  

1;
