package Games::Lacuna::Schema::Result::Planet;
use 5.010;
use Modern::Perl;
use Data::Dumper;
use DateTime;
use DateTime::Duration;
use base 'DBIx::Class::Core';

my $flurble;

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


=head1 Excavators

An empire can only send an excavator to any given planet once every 30 days.  
This section will help figure out if a given planet is a valid target for a new
excavator.

=head2 recent_excavator, recent_excavator_date

Mutually exclusive with old_excavator.

 if( $planet->recent_excavator ) {
  ### $planet is NOT a valid excavator target.
  say $planet->name . " was hit with an excavator on " . $planet->recent_excavator_date;
 }

=head2 old_excavator, old_excavator_date

Mutually exclusive with recent_excavator.  This exists just for curiosity; a 
planet that was hit with an excavator more than 30 days ago is, for all 
practical purposes, identical to one that was never hit with an excavator.

 if( $planet->old_excavator ) {
  ### $planet is a valid excavator target.
  say $planet->name . " was hit with an excavator on " . $planet->old_excavator_date;
 }

=head2 TBD

I still can't figure out how to use this relationship in a search.  I can do

 $rs = $schema->resultset('Planets')->search(...);
 PLANET: while( $rec = $rs->next ) {
  next PLANET if $rec->recent_excavator;
 }

...But I'd prefer not to select records with recent excavator activity in the 
first place.  I have tried

 $rs = $schema->resultset('Planet')->search({ recent_excavator => {'!=' => undef} });
 $rs = $schema->resultset('Planet')->search({ recent_excavator => {'!=' => ''} });
 $rs = $schema->resultset('Planet')->search({ recent_excavator => {'!=' => 'Games::Lacuna::Schema::Result::ExcavatorLog'} });

I also tried those using recent_excavator_date with the same results, which was 
that nothing was filtered; all records get returned regardless of 
recent_excavator values.

Conversely, these...

 $rs = $schema->resultset('Planet')->search({ recent_excavator => undef });
 $rs = $schema->resultset('Planet')->search({ recent_excavator => '' });
 $rs = $schema->resultset('Planet')->search({ recent_excavator => 'Games::Lacuna::Schema::Result::ExcavatorLog' });

...all filtered out all records - nothing matches any of them.


=cut

### Needed for SQLite
my $thirty_one_days = 60 * 60 * 24 * 31;

__PACKAGE__->has_one( 
    recent_excavator => 'Games::Lacuna::Schema::Result::ExcavatorLog', 
    { 'foreign.to_x' => 'self.x', 'foreign.to_y' => 'self.y', },
    {
        where => {
            ### The first works with SQLite.  The strftime nonsense is 
            ### necessary because SQLite doesn't actually have a datetime 
            ### type.  The second version works with MySQL.
            #-bool => \[ qq{strftime('%s',datetime('now')) - strftime('%s', date) < $thirty_one_days} ],
            -bool => \[ qq{( to_days(now()) -  to_days(date) ) <= 30 } ],
        },
        ### Allows you to do
        ###     $planet->recent_excavator_date
        ### To get ExcavatorLog.date
        proxy => {
            recent_excavator_date => 'date',
        },
    }
); 
__PACKAGE__->has_one(
    old_excavator => 'Games::Lacuna::Schema::Result::ExcavatorLog', 
    { 'foreign.to_x' => 'self.x', 'foreign.to_y' => 'self.y', },
    {
        where => {
            ### See comment above.
            #-bool => \[ qq{strftime('%s',datetime('now')) - strftime('%s', date) > $thirty_one_days} ],
            -bool => \[ qq{( to_days(now()) -  to_days(date) ) > 30 } ],
        },
        ### Allows you to do
        ###     $planet->old_excavator_date
        ### To get ExcavatorLog.date
        proxy => {
            old_excavator_date => 'date',
        },
    }
); 

__PACKAGE__->belongs_to( 
    'star' => 
    'Games::Lacuna::Schema::Result::Star',
    { 'foreign.id' => 'self.star_id'}
);  
### Including the following generates a FK relationship between Planet and 
### Empire when calling deploy().  In a perfect world we'd want that 
### relationship to exist, but since we're getting this data second-hand, and 
### since empires can disappear outside of our control, we do not want there 
### to exist a constraint between the two.
__PACKAGE__->belongs_to( 
    'empire', 
    'Games::Lacuna::Schema::Result::Empire', 
    { 'foreign.id' => 'self.empire_id'}
);  
#__PACKAGE__->has_one( 
#    'star' => 
#    'Games::Lacuna::Schema::Result::Star',
#    { 'foreign.id' => 'self.star_id'}
#);  


1;
