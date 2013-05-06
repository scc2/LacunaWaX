package Games::Lacuna::Webtools::Schema::Result::Role;
use 5.010;
use base 'DBIx::Class::Core';

__PACKAGE__->table('Roles');
__PACKAGE__->add_columns( 
    id          => {data_type => 'integer', size => 32,  is_auto_increment => 1, is_nullable => 0, extra => {unsigned => 1} },
    name        => {data_type => 'varchar', size => 64,  is_nullable => 0},
    description => {data_type => 'varchar', size => 255, is_nullable => 1},
);
__PACKAGE__->set_primary_key( 'id' ); 
__PACKAGE__->add_unique_constraint( name => ['name'] ); 
__PACKAGE__->has_many( 
    login_roles => 'Games::Lacuna::Webtools::Schema::Result::Login_Role', 
    { 'foreign.Roles_id' => 'self.id' }
);
__PACKAGE__->many_to_many( logins => 'login_roles', 'login' );

1;
