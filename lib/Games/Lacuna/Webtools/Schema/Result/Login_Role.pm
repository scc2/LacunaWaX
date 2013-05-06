package Games::Lacuna::Webtools::Schema::Result::Login_Role;
use 5.010;
use base 'DBIx::Class::Core';

__PACKAGE__->table('Logins_Roles');
__PACKAGE__->add_columns( 
    id          => {data_type => 'integer', size => 32, is_auto_increment => 1, is_nullable => 0, extra => {unsigned => 1} },
    Logins_id   => {data_type => 'integer', size => 32, is_nullable => 0, extra => {unsigned => 1} },
    Roles_id    => {data_type => 'integer', size => 32, is_nullable => 0, extra => {unsigned => 1} },
);
__PACKAGE__->set_primary_key( 'id' ); 
__PACKAGE__->add_unique_constraint( loginrole => ['Logins_id', 'Roles_id'] ); 
__PACKAGE__->belongs_to( login => 'Games::Lacuna::Webtools::Schema::Result::Login',
    {'foreign.id' => 'self.Logins_id'}
);
__PACKAGE__->belongs_to( role  => 'Games::Lacuna::Webtools::Schema::Result::Role',
    {'foreign.id' => 'self.Roles_id'}
);

1;
