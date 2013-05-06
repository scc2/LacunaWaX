package Games::Lacuna::Webtools::Schema::Result::QueuedJob;
use v5.14;
use base 'DBIx::Class::Core';

__PACKAGE__->table('QueuedJobs');
__PACKAGE__->load_components(qw/FilterColumn/);
__PACKAGE__->add_columns( 
    id       => { data_type => 'integer', is_nullable => 0,             is_auto_increment => 1, extra => {unsigned => 1} },
    empire   => { data_type => 'varchar', is_nullable => 0, size => 64  },
    name     => { data_type => 'varchar', is_nullable => 0, size => 64  },
    args     => { data_type => 'blob',    is_nullable => 1 },
    complete => { data_type => 'tinyint', is_nullable => 0,             default => 0 },
);
__PACKAGE__->set_primary_key( 'id' ); 



=pod

empire
    Optional.
    Name of the empire this job is to run against.  

name
    Required.
    Name of the job itself, so whatever handlers are out there know which jobs 
    they should deal with.

args
    Optional.
    json-encoded ref of arbitrary arguments to be sent to the job.

complete
    Defaults to 0.  Handlers should look for jobs with 'complete' set to 0, and 
    then update to 1 once the job has been successfully handled.

=cut




1;
