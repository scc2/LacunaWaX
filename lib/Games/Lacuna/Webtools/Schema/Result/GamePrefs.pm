package Games::Lacuna::Webtools::Schema::Result::GamePrefs;
use 5.010;
use base 'DBIx::Class::Core';

=pod

This manages prefs that have a one-to-one relationship between the empire and the 
game.

See PlanetPrefs for per-planet prefs.

=cut


### glyph_home, merc_base_id, and fetch_ship_pattern all commented out 
### 06/19/2012.  They've been removed from all code, but not yet from the 
### table.
###
### Give it a week or so and if everything is fine, delete the references in 
### here and drop the columns.
###
### When this happens, also remove the 'allow_fetch' task from EnumSpyTasks.  
### Check to see if anybody still has that task (6) assigned to any spies (I 
### think kiamo does) and let them know that it's now invalid.

__PACKAGE__->table('GamePrefs');
__PACKAGE__->add_columns( 
    id                      => {data_type => 'integer', is_auto_increment => 1, is_nullable => 0, extra => {unsigned => 1} },
    Logins_id               => {data_type => 'integer', is_nullable => 0, extra => {unsigned => 1} },
    empire_name             => {data_type => 'varchar', size => 64, is_nullable => 1},
    empire_password         => {data_type => 'varchar', size => 64, is_nullable => 1},
    sitter_password         => {data_type => 'varchar', size => 64, is_nullable => 1},
    server_uri              => {data_type => 'varchar', size => 256, is_nullable => 1},
    run_scheduler           => {data_type => 'tinyint', is_nullable => 0, default_value => 0, extra => {unsigned => 1}}, # meant to be a bool
    time_zone               => {data_type => 'varchar', size => 64, is_nullable => 1},
#    glyph_home              => {data_type => 'varchar', size => 64, is_nullable => 1},
    clear_pass_parl_mail    => {data_type => 'tinyint', is_nullable => 0, default_value => 0, extra => {unsigned => 1}}, # meant to be a bool
    clear_all_parl_mail     => {data_type => 'tinyint', is_nullable => 0, default_value => 0, extra => {unsigned => 1}}, # meant to be a bool
    permit_obs_scan         => {data_type => 'tinyint', is_nullable => 0, default_value => 0, extra => {unsigned => 1}}, # meant to be a bool
#    merc_base_id            => {data_type => 'integer', is_nullable => 1},
#    fetch_ship_pattern      => {data_type => 'varchar', size => 64, is_nullable => 1},
);
__PACKAGE__->set_primary_key( 'id' ); 
__PACKAGE__->add_unique_constraint( one_per_login => ['Logins_id'] ); # name not ID because of all
__PACKAGE__->belongs_to( 
    'login' => 
    'Games::Lacuna::Webtools::Schema::Result::Login',
    { 'foreign.id' => 'self.Logins_id'}
);  

1;

__END__

CREATE TABLE `gameprefs` (
	`id` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
	`Logins_id` INT(10) UNSIGNED NOT NULL,
	`empire_name` VARCHAR(64) NULL DEFAULT NULL,
	`empire_password` VARCHAR(64) NULL DEFAULT NULL,
	`sitter_password` VARCHAR(64) NULL DEFAULT NULL,
	`server_uri` VARCHAR(256) NULL DEFAULT NULL,
	`run_scheduler` TINYINT(1) UNSIGNED NOT NULL DEFAULT '0',
	`time_zone` VARCHAR(64) NULL DEFAULT NULL,
	`glyph_home` VARCHAR(64) NULL DEFAULT NULL,
	`clear_pass_parl_mail` TINYINT(1) UNSIGNED NOT NULL DEFAULT '0',
	`clear_all_parl_mail` TINYINT(1) UNSIGNED NOT NULL DEFAULT '0',
	`permit_obs_scan` TINYINT(1) UNSIGNED NOT NULL DEFAULT '0' COMMENT 'When true, user allows me to run observatory scanner by hand.',
	`merc_base_id` INT(10) NULL DEFAULT NULL,
	`fetch_ship_pattern` VARCHAR(64) NULL DEFAULT NULL,
	PRIMARY KEY (`id`),
	UNIQUE INDEX `one_per_login` (`Logins_id`),
	INDEX `GamePrefs_idx_Logins_id` (`Logins_id`),
	CONSTRAINT `GamePrefs_fk_Logins_id` FOREIGN KEY (`Logins_id`) REFERENCES `logins` (`id`) ON DELETE CASCADE
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB
ROW_FORMAT=DEFAULT
AUTO_INCREMENT=33


