package Games::Lacuna::Webtools::Schema::Result::SpyPrefs;
use 5.010;
use base 'DBIx::Class::Core';

__PACKAGE__->table('SpyPrefs');
__PACKAGE__->add_columns( 
    id        => {data_type => 'integer', is_auto_increment => 1, is_nullable => 0, extra => {unsigned => 1} },
    Logins_id => {data_type => 'integer', is_nullable => 0, extra => {unsigned => 1} },
    ### spy_id needs to be correct.  spy_name may not be; the user might 
    ### change the spy's name in-game after entering it in this table, in 
    ### which case the spy_name here will be incorrect.  But the spy_id won't 
    ### change.
    ### I'm pretty sure the spy_name column is going to go away altogether; it's 
    ### duplicated data.  It's just here to make it easier for me to eyeball 
    ### what's going on while I'm working.
    spy_id    => {data_type => 'integer', is_nullable => 0, extra => {unsigned => 1} },
    spy_name  => {data_type => 'varchar', size => 64, is_nullable => 1},
    task_id   => {data_type => 'integer', is_nullable => 0, default_value => 1, extra => {unsigned => 1} },
);
__PACKAGE__->set_primary_key( 'id' ); 
__PACKAGE__->belongs_to( 
    'login' => 
    'Games::Lacuna::Webtools::Schema::Result::Login',
    { 'foreign.id' => 'self.Logins_id'}
);  
__PACKAGE__->has_one(
    task => 'Games::Lacuna::Webtools::Schema::Result::Enum_SpyTasks', 
    { 'foreign.id' => 'self.task_id' }
);

sub all_tasks {#{{{
    my $self = shift;

=pod

Returns a recordset containing all possible spy tasks.  You could certainly 
just query the schema yourself, but trying to remember the correct spelling of 
"Enum_SpyTasks" is going to be a pain.  Getting a list of tasks from a SpyPrefs
record feels natural.

=cut

    my $schema   = $self->result_source->schema;
    my $tasks_rs = $schema->resultset('Enum_SpyTasks')->search();
    return $tasks_rs;
}#}}}

1;
