package Games::Lacuna::Webtools::Schema::Result::Message;
use 5.010;
use base 'DBIx::Class::Core';

=pod

This manages prefs that have a one-to-one relationship between the empire and the 
game.

See PlanetPrefs for per-planet prefs.

=cut

__PACKAGE__->table('Messages');
__PACKAGE__->add_columns( 
    id          => {data_type => 'integer', is_auto_increment => 1, extra => {unsigned => 1} },
    from_id     => {data_type => 'integer', extra => {unsigned => 1} },
    to_id       => {data_type => 'integer', extra => {unsigned => 1} },
    perused     => {data_type => 'tinyint', is_nullable => 0, default_value => 0, extra => {unsigned => 1} },   # bool
    message     => {data_type => 'text' },
);

### 'perused' because 'read' is a MySQL reserved word.

__PACKAGE__->set_primary_key( 'id' ); 
__PACKAGE__->has_one(
    from => 'Games::Lacuna::Webtools::Schema::Result::Login', 
    { 'foreign.id' => 'self.from_id' }
);
__PACKAGE__->has_one(
    to => 'Games::Lacuna::Webtools::Schema::Result::Login', 
    { 'foreign.id' => 'self.to_id' }
);


1;

__END__

CREATE TABLE `messages` (
	`id` INT(10) UNSIGNED NOT NULL,
	`from_id` INT(10) UNSIGNED NOT NULL,
	`to_id` INT(10) UNSIGNED NOT NULL,
	`message` TEXT NOT NULL,
	PRIMARY KEY (`id`)
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB
ROW_FORMAT=DEFAULT


