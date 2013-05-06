package Games::Lacuna::Schema::Result::Empire;
use 5.010;
use Modern::Perl;
use Data::Dumper;
use base 'DBIx::Class::Core';

__PACKAGE__->table('Empires');
__PACKAGE__->add_columns( 
    id              => {data_type => 'integer',  is_auto_increment => 1, is_nullable => 0},     # NOT unsigned!
    alliance_id     => {data_type => 'integer',  is_nullable => 1},                             # NOT unsigned!
    name            => {data_type => 'varchar',  size => 64, is_nullable => 1},
    status_message  => {data_type => 'text',  is_nullable => 1},
    species         => {data_type => 'varchar',  size => 64, is_nullable => 1},
    description     => {data_type => 'text',  is_nullable => 1},
    player_name     => {data_type => 'varchar',  size => 64, is_nullable => 1},
    city            => {data_type => 'varchar',  size => 64, is_nullable => 1},
    country         => {data_type => 'varchar',  size => 64, is_nullable => 1},
    skype           => {data_type => 'varchar',  size => 64, is_nullable => 1},
    last_login      => {data_type => 'datetime', is_nullable => 1},
    date_founded    => {data_type => 'datetime', is_nullable => 1}

);
__PACKAGE__->set_primary_key( 'id' ); 
__PACKAGE__->add_unique_constraint( name => ['name'] ); 
__PACKAGE__->belongs_to( alliance => 'Games::Lacuna::Schema::Result::Alliance', 'alliance_id' );  
__PACKAGE__->has_many( planets => 'Games::Lacuna::Schema::Result::Planet', 'empire_id' ); 
__PACKAGE__->has_many( excavators_sent => 'Games::Lacuna::Schema::Result::ExcavatorLog', 'empire_id' ); 
__PACKAGE__->has_many( alliance => 'Games::Lacuna::Schema::Result::Alliance', {'foreign.id' => 'self.alliance_id'} ); 

1;
