
=pod

Do not use this for Wx components, such as fonts.  

This container is used by scheduled processes, and using Wx in those causes 
explosions.

This container has no caching at all.

=cut

package LacunaWaX::Model::Container {
    use v5.14;
    use Bread::Board;
    use Carp;
    use Moose;
    use MooseX::NonMoose;

    ### This exists, commented, as a reminder not to get clever and add it.  
    ### It doesn't play well with Bread::Board.
    #use Moose::Util::TypeConstraints;

    extends 'Bread::Board::Container';

    ### Pseudo-globals
    has 'api_key' => ( is => 'rw', isa => 'Str', default => '02484d96-804d-43e9-a6c4-e8e80f239573' );

    ### Database
    has 'db_file'     => ( is => 'rw', isa => 'Str', required => 1);
    has 'db_log_file' => ( is => 'rw', isa => 'Str', required => 1);
    has 'sql_options' => (
        is      => 'rw',
        isa     => "HashRef[Any]",
        lazy    => 1,
        default => sub{ {sqlite_unicode => 1, quote_names => 1} },
    );

    ### Directories
    has 'root_dir' => ( is => 'rw', isa => 'Str', required => 1 );

    ### Logging
    has 'log_time_zone' => ( is => 'rw', isa => 'Str', lazy => 1, default => 'UTC' );
    has 'log_component' => ( is => 'rw', isa => 'Str', lazy => 1, default => 'main' );
    has 'run'           => ( is => 'rw', isa => 'Int' );

    ### Lucy
    has 'help_index' => ( is => 'rw', isa => 'Str', lazy_build => 1 );

    sub _build_help_index {#{{{
        my $self = shift;
        return join q{/}, ($self->root_dir, 'user', 'doc', 'html', 'html.idx');
    }#}}}
    sub _check_caller_type {#{{{
        ### This trigger is emulating an enum, which we could get out of 
        ### Moose::Util::TypeConstraints.  However, we cannot use that, as it 
        ### contains a prototype that disagrees with Bread::Board, hence this 
        ### trigger.
        my $self     = shift;
        my $new_type = shift;
        my $old_type = shift;
        unless( $new_type ~~ [qw(web local)] ) {
            croak "Invalid caller_type '$new_type'; must be 'web' or 'local'."
        }
        return 1;
    }#}}}
    sub _check_log_file_min_level {#{{{
        ### This trigger is emulating an enum, which we could get out of 
        ### Moose::Util::TypeConstraints.  However, we cannot use that, as it 
        ### contains a prototype that disagrees with Bread::Board, hence this 
        ### trigger.
        my $self     = shift;
        my $new_type = shift;
        my $old_type = shift;
        unless( $new_type ~~ [ $self->valid_log_levels ] ) {
            croak "Invalid log_file_min_level '$new_type'; see valid_log_levels() for valid options.";
        }
        return 1;
    }#}}}
    sub valid_log_levels {#{{{
        return qw(debug info notice warning error critical alert emergency);
    }#}}}

    sub BUILD {
        my $self = shift;

        container $self => as {
            container 'Database' => as {#{{{
                service 'db_file'       => $self->db_file;
                service 'sql_options'   => $self->sql_options;
                service 'dsn' => (#{{{
                    dependencies => {
                        db_file => depends_on('Database/db_file'),
                    },
                    block => sub {
                        my $s = shift;
                        my $dsn = 'DBI:SQLite:dbname=' . $s->param('db_file');
                        return $dsn;
                    },
                );#}}}
                service 'connection' => (#{{{
                    class        => 'DBI',
                    dependencies => {
                        dsn         => (depends_on('Database/dsn')),
                        sql_options => (depends_on('Database/sql_options')),
                    },
                    block => sub {
                        my $s = shift;
                        return DBI->connect(
                            $s->param('dsn'),
                            q{},
                            q{},
                            $s->param('sql_options'),
                        );
                    },
                );#}}}
                service 'schema' => (#{{{
                    lifecycle => 'Singleton',
                    dependencies => [
                        depends_on('Database/dsn'),
                        depends_on('Database/sql_options'),
                    ],
                    class => 'LacunaWaX::Model::Schema',
                    block => sub {
                        my $s = shift;
                        my $conn = LacunaWaX::Model::Schema->connect(
                            $s->param('dsn'),
                            $s->param('sql_options'),
                        );
                        return $conn;
                    }
                );#}}}
            };#}}}
            container 'DatabaseLog' => as {#{{{
                ### Uses a separate db file for logging.
                service 'db_file'       => $self->db_log_file;
                service 'sql_options'   => $self->sql_options;
                service 'dsn' => (#{{{
                    dependencies => {
                        db_file => depends_on('DatabaseLog/db_file'),
                    },
                    block => sub {
                        my $s = shift;
                        my $dsn = 'DBI:SQLite:dbname=' . $s->param('db_file');
                        return $dsn;
                    },
                );#}}}
                service 'connection' => (#{{{
                    class        => 'DBI',
                    dependencies => {
                        dsn         => (depends_on('DatabaseLog/dsn')),
                        sql_options => (depends_on('DatabaseLog/sql_options')),
                    },
                    block => sub {
                        my $s = shift;
                        return DBI->connect(
                            $s->param('dsn'),
                            q{},
                            q{},
                            $s->param('sql_options'),
                        );
                    },
                );#}}}
                service 'schema' => (#{{{
                    ### Non-singleton.  This way, the log viewer can follow 
                    ### along with a currently-running scheduled task.
#                    lifecycle => 'Singleton',
                    dependencies => [
                        depends_on('DatabaseLog/dsn'),
                        depends_on('DatabaseLog/sql_options'),
                    ],
                    class => 'LacunaWaX::Model::LogsSchema',
                    block => sub {
                        my $s = shift;
                        my $conn = LacunaWaX::Model::LogsSchema->connect(
                            $s->param('dsn'),
                            $s->param('sql_options'),
                        );
                        return $conn;
                    }
                );#}}}
            };#}}}
            container 'Directory' => as {#{{{
                service 'assets'    => join q{/}, $self->root_dir, 'user', 'assets';
                service 'bin'       => join q{/}, $self->root_dir, 'bin';
                service 'html'      => join q{/}, $self->root_dir, 'user', 'doc', 'html';
                service 'ico'       => join q{/}, $self->root_dir, 'user', 'ico';
                service 'root'      => $self->root_dir;
                service 'user'      => join q{/}, $self->root_dir, 'user';
            };#}}}
            container 'Globals' => as {#{{{
                service 'api_key' => $self->api_key;
            };#}}}
            container 'Log' => as {#{{{
                service 'log_time_zone' => $self->log_time_zone;
                service 'log_component' => $self->log_component;
                container 'Outputs' => as {#{{{
                    service 'dbi' => (#{{{
                        class => 'LacunaWaX::Model::DBILogger',
                        dependencies => {
                            log_component   => depends_on('/Log/log_component'),
                            log_time_zone   => depends_on('/Log/log_time_zone'),
                            db_connection   => depends_on('/DatabaseLog/connection'),
                        },
                        block => sub {
                            my $s = shift;

                            my %args = (
                                name        => 'dbi',
                                min_level   => 'debug',
                                component   => $s->param('log_component'),
                                time_zone   => $s->param('log_time_zone'),
                                dbh         => $s->param('db_connection'),
                                table       => 'Logs',
                                callbacks   => sub{ my %h = @_; return sprintf "%s", $h{'message'}; }
                            );

                            if( $self->run ) { $args{'run'} = $self->run; }
                            my $l = LacunaWaX::Model::DBILogger->new(%args);
                            unless( $self->run ) { $self->run( $l->run ); }

                            return $l;
                        }
                    );#}}}
                };#}}}
                service 'logger' => (#{{{
                    dependencies => [
                        depends_on('/Log/Outputs/dbi'),
                    ],
                    class => 'Log::Dispatch',
                    block => sub {
                        my $s = shift;
                        my $Outputs_container   = $s->parent;
                        my $outputs             = $Outputs_container->get_sub_container('Outputs');
                        my $log                 = Log::Dispatch->new;
                        $log->add( $outputs->get_service('dbi')->get );
                        $log;
                    }
                );#}}}
            };#}}}
            container 'Lucy' => as {#{{{
                service 'index' => $self->help_index;
                service 'searcher' => (#{{{
                    dependencies => [
                        depends_on('/Lucy/index'),
                    ],
                    class => 'Lucy::Search::IndexSearcher',
                    block => sub {
                        my $s = shift;
                        my $searcher = Lucy::Search::IndexSearcher->new(
                            index => $s->param('index')
                        );
                        return $searcher;
                    }
                );#}}}
            };#}}}
            container 'Strings' => as {#{{{
                service 'app_name' => 'LacunaWaX';
                service 'developers' => [
                    'Jonathan D. Barton (tmtowtdi@gmail.com)',
                    'Nathan McCalllum (thevasari@gmail.com)',
                    'Swamp Thing',
                ];
            };#}}}
        };

        return $self;
    }

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;

__END__

=head2 Strings container

I originally had a TextResources Model.  The idea was that all text strings 
throughout the program would come from there, hypothetically making it easier to 
support il8n.  

In reality, I don't see this ever actually being translated to any other 
languages, and pulling text strings out of TextResources.pm is enough of a minor 
obstacle that the program has ended up with some strings in TextResources.pm, 
but most of them hard-coded elsewhere.

Instead of trying to be a repository for all strings in the program, the Strings 
container is only meant to contain strings that are or might be repeated, such as 
the app_name, for consistency.

=head2 run

I want all log entries from a given run of the app to have the same 'run' 
value, to make it easy to eyeball all of what happened last run.

The Model::DBILogger output class will lazy_build its run attribute, setting it one 
higher than the current highest run value in the Logs table.

The problem is that my logger class is not a singleton.  This is so I can 
resolve a logger, set its component one time, and have that component setting 
stick for the life of that logger.

Previously, when the logger was a singleton, this would happen:
    
    $log->component("MyComponent");
    $log->info('foo');                  # logs 'foo' set as 'MyComponent'.

    $app->method_that_does_its_own_logging_and_sets_a_different_component();

    $log->info('bar');                  # logs 'bar' set as 'DifferentComponent'


But when loggers were first set up as "not singletons", they were all getting 
their own run values, and I don't want that either.

So now, the flow is:
    - Container gets instantiated once per run of the app.  Its run attribute 
      starts out undef.
    - A logger gets instantiated.
        - If container->run is undef:
            - that logger generates its own run value.
            - THAT run value then gets set as the container's run value.
        - If container->run has a value:
            - the new logger takes the container's run value as its own.

