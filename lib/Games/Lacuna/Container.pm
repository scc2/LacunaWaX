use v5.14;
use utf8;       # so literals and identifiers can be in UTF-8
use warnings;   # on by default
use warnings    qw(FATAL utf8);    # fatalize encoding glitches
use open        qw(:std :utf8);    # undeclared streams in UTF-8 - does not get along with use autodie.
use charnames   qw(:full :short);  # unneeded in v5.16

### $Id: Container.pm 34 2012-12-18 02:10:44Z jon $
### $URL: https://tmtowtdi.gotdns.com:15000/svn/LacunaWaX/trunk/lib/Games/Lacuna/Container.pm $
BEGIN {
    my $file_revision = '$Rev: 34 $';
    our $VERSION = '0.1.' . $file_revision =~ s/\D//gr;
}

package Games::Lacuna::Container {
    use Bread::Board;
    use FindBin;
    use Moose;
    use MooseX::NonMoose;
    use Sys::Hostname;
    use Time::Duration::Parse;
    use Try::Tiny;

    ### This exists, commented, as a reminder not to get clever and add it.  
    ### It doesn't play well with Bread::Board.
    #use Moose::Util::TypeConstraints;

    extends 'Bread::Board::Container';

### POD {#{{{

=head1 NAME

Games::Lacuna::Container - return app container.

=head1 SYNOPSIS

All options shown:
 
 $container = Games::Lacuna::Container->new({
  name          => 'MyContainer',
  empire        => 'SomeEmpireName',
  password      => 'SomeEmpireName's password',
  log_file      => '/path/to/logfile.txt',
  ### The following are shown for completeness, but the values below are the 
  ### defaults.
  uri           => 'https://us1.lacunaexpanse.com',
  api_key       => '02484d96-804d-43e9-a6c4-e8e80f239573',
  caller_type   => 'local',
  no_cache      => 1,
  sql_options   => { mysql_enable_utf8 => 1, quote_names => 1 },
  log_to_screen => 1,
  log_to_db     => 1,   # *** Be very careful with this; see below. ***
 });

...but more commonly, you'll skip file logging and accept the defaults, so...

 $container = Games::Lacuna::Container->new({
  name     => 'MyContainer',
  empire   => 'SomeEmpireName',
  password => 'SomePassword',     # either sitter or full password works
 });

...either way...

 my $client = $c->resolve( service => 'Game_server/connection' )
  or die "Could not connect; maybe bad password.";
 say $client->name();

 my $planet = Games::Lacuna::Client::Task::Planet->new({ client => $client, name => 'bmots1' });

If you haven't got a user's empire name and password yet, say at the pre-login 
phase in a web app, you can request a minimal container:

 $min_cont = Games::Lacuna::Container->new({ name => 'MyContainer' });

Since you haven't provided 'empire' or 'password', an attempt to access the 
Game_server/connection service will fail, noisily:

 my $client = $min_cont->resolve( service => 'Game_server/connection' );    # BOOM!

However, you I<can> access the schema services:

 my $ms = $min_cont->resolve( service => 'Database/main_schema' );
 my $us = $min_cont->resolve( service => 'Database/users_schema' );

...and now you can use those schemas to log your user in or whatever else you 
need to do.

=head1 ATTRIBUTES

'Required' and 'Optional' below refer only to what's needed to instantiate a 
Games::Lacuna::Container object.

The various services provided by that GLC object have differing ideas of 
what's required.  eg you must provide both 'empire' and 'password' if you 
attempt to resolve a Game_server/connection service out of your container.

=over 4

=item * name

B<Required>; string.  Name of the Bread::Board container.  Can be any arbitrary 
string.

=item * empire

Optional, string.  Name of the empire to log in as.

=item * password

Optional, string.  Password for the given empire, either sitter or full password.

=item * uri

Optional, string.  The URI to which we'll send requests.  Defaults to 
'https://us1.lacunaexpanse.com'.

=item * api_key

Optional, string.  The API key sent with the request.  Defaults to my API key.

=item * sql_options

Optional, hashref.  Defaults to a reasonable set of DBI connect options to be 
passed to all services connecting to the database.

=item * caller_type

Optional, string, must be either 'web' or 'local' if sent.  Defaults to 'local'.  
Determines behavior if the 60 RPC per minute limit is reached.  When caller_type 
is 'local', the process will sleep for a minute, then re-issue the server 
request that initiated the 60 RPC/minute error.  When caller_type is 'web', the 
process dies (sleeping for a minute during a web request is generally Not Good).

=item * no_cache

Optional, boolean.  Defaults to 1.  Most of the GLCT modules perform some 
caching of their own results.  When no_cache is true, they'll knock that off.

These internal caches are RawMemory caches, so they're useful only in 
single-process jobs, such as a CLI task scheduler, and useless for something 
like a web app.

=item cache_root_dir

Optional, string, lazy.  Defaults to $FindBin::Bin/../cache/.  Whether you set 
this or the default is used, the value will be checked to ensure it's an 
existing, writable directory.  Only used for the Cache/fast_mmap service.

=item cache_global

Optional, boolean.  Defaults to 1.  This setting is used in most of the CHI 
docs' examples, but I'm unable to find anything telling me WTF it actually 
does.  Best bet is probably to leave it alone.

=item * cache_expires_variance

Optional, float between 0.0 and 1.0.  Defaults to 0.25.  Allows cached items 
to expire a little before their set expiration time to avoid a mad rush of 
expensive calls when all the caches expire at the same time.

0.0 means "expire exactly when the expiry is up".  1.0 means "expire any time 
  between right now and the stated expiry time".

=item * cache_size

Optional, string.  Defaults to "1m".  Only applies to the Cache/fast_mmap 
service.

=item * cache_max_items

Optional, integer.  Defaults to 20.  Only applies to the Cache/raw_memory 
service.  Since items in a RawMemory cache are not serialized, it's impossible 
to determine their size.  So, max_items simply specifies the number of items 
allowed in the cache.

=item * cache_namespace

Optional, string.  Defaults to 'Games::Lacuna::Container'.

=item * log_file

Optional, string, defaults to empty string.  Path to log file.  When empty (the 
default), no file logging is performed.  As with log_to_screen, this only has 
affect in the constructor.

=item * log_file_min_level

Optional, string, defaults to 'info'.  Minimum level a logging event has to be 
to end up in the log file.  If the log_file attribute has been left empty, this 
is meaningless.  See valid_log_levels() or the Log::Dispatch docs for a list of 
valid log levels.

=item * log_to_screen

Optional, boolean, defaults to true.  Turn screen logging on or off.  Only 
applicable in the constructor; once logging is set on or off, further changes 
to this attribute will have no effect.

=item * log_to_db

Optional, boolean, defaults to false.  When on, log messages of level notice 
or higher are added to the lacuna.ScheduleLog table.  These table entries 
include the current empire name, and are visible to that empire (user) through 
the web app.

B<CAUTION> - the database connection used when this attribute is on becomes a 
zombie connection in a webapp when the webapp forwards from one route to 
another; the connection created in the forwarding route zombifies.

Best bet is to only use this is non-forking, non-persistent applications (like 
the periodic task scheduler).

=item * log_time_zone

Optional, string, defaults to 'UTC'.  TZ applied to the timestamps produced by 
the logger.

=back

=head1 CACHE SERVICES

None of the cache services are singletons, so you can get a new cache with new 
settings (to a point) by modifying your $container object and re-requesting 
the cache:

 my $cont = Games::Lacuna::Container->new(
  cache_namespace => 'First Namespace',
  ...
 );
 my $cache_one = $cont->resolve( service => 'Cache/fast_mmap' );

 $cache_one->set("foo", "bar");

 # Outputs 'bar'
 say $cache_one->get("foo");

 # $cache_two _is_ a different object from $cache_one, but since they're 
 # sharing a namespace, the following will still output 'bar'.
 my $cache_two = $cont->resolve( service => 'Cache/fast_mmap' );
 say $cache_two->get("foo");

 # Since $cache_three is using a different namespace, it does not have access to
 # 'foo' like the previous two caches did, and the attempt to get 'foo' will 
 # produce an uninitialized warning:
 $cont->cache_namespace( 'Second Namespace' );
 my $cache_three = $cont->resolve( service => 'Cache/fast_mmap' );
 say $cache_three->get("foo");    # "Use of uninitialized blah...".


If you need to change something fundamental about your cache settings when 
getting a >= second cache, you I<must> change its namespace:

 my $cont = Games::Lacuna::Container->new(
  cache_size => '1m',
  ...
 );
 my $c1 = $cont->resolve( service => 'Cache/fast_mmap' );   # 1 meg cache

 $cont->cache_namespace('New Namespace');
 $cont->cache_size('5m');
 my $c2 = $cont->resolve( service => 'Cache/fast_mmap' );   # 5 meg cache

 # This will die (not warn); it's still using 'New Namespace', but attempting to 
 # resize that (already existing and sized) namespace.
 $cont->cache_size('10m');
 my $c3 = $cont->resolve( service => 'Cache/fast_mmap' );   # boom - "Truncate of existing share file..."

=head2 Cache/fast_mmap

I<Can> be shared between processes.  I<Cannot> store GLOB or CODE items.  
Useful for web apps.

=head2 Cache/raw_memory

I<Cannot> be shared between processes.  I<Can> store GLOB and CODE items.  
Useful for single-process (CLI) apps, completely useless for web apps.

=head1 DATABASE CONNECTIONS

When used in a non-forked, non-threaded job, like the periodic task scheduler,  
all of the database-related services in here work just fine.

But when used in a forked job, like a Dancer web app, DB connections get a 
little finicky.

The DBIC schemas ('Database/users_schema') and ('/Database/main_schema') both 
use the default 'prototype' lifecycle, and work that way.  If they get changed 
to a 'Singleton' lifecycle, they will produce zombie database connections.

The Log::Dispatch::DBI service ('Log/Outputs/dbi') produces a zombie database 
connection when used in a Dancer app regardless of its lifecycle, so it's 
important to not pass log_to_db => 1 in your Container constructor in that 
situation.

=cut

### }#}}}

    ### Game server connection
    has 'empire'        => ( is => 'rw', isa => 'Str' );
    has 'password'      => ( is => 'rw', isa => 'Str' );
    has 'uri'           => ( is => 'rw', isa => 'Str', default => 'https://us1.lacunaexpanse.com' );
    has 'api_key'       => ( is => 'rw', isa => 'Str', default => '02484d96-804d-43e9-a6c4-e8e80f239573' );
    has 'caller_type'   => ( is => 'rw', isa => 'Str', default => 'local', trigger => \&_check_caller_type );
    has 'no_cache'      => ( is => 'rw', isa => 'Str', default => 1  );

    ### Logging
    has 'log_file'              => ( is => 'rw', isa => 'Str',  default => q{}, documentation => q{Optional, but ensure it's defined} );
    has 'log_file_min_level'    => ( is => 'rw', isa => 'Str',  default => q{info}, trigger => \&_check_log_file_min_level );
    has 'log_to_screen'         => ( is => 'rw', isa => 'Bool', default => 1 );
    has 'log_to_db'             => ( is => 'rw', isa => 'Bool', default => 0 );
    has 'log_time_zone'         => ( is => 'rw', isa => 'Str',  default => 'UTC' );

    ### Database
    has 'sql_options' => (
        is      => 'rw',
        isa     => "HashRef[Any]",
        lazy    => 1,
        default => sub{ {mysql_enable_utf8 => 1, quote_names => 1} },
    );

    ### Cache
    has 'cache_root_dir'            => ( is => 'rw', isa => 'Str', lazy_build => 1,         trigger => \&_check_cache_root_dir );
    has 'cache_global'              => ( is => 'rw', isa => 'Int', default => 1 );
    has 'cache_expires_in'          => ( is => 'rw', isa => 'Str', default => '15 minutes', trigger => \&_check_cache_expires_in );
    has 'cache_expires_variance'    => ( is => 'rw', isa => 'Num', default => 0.25 );
    has 'cache_size'                => ( is => 'rw', isa => 'Str', default => '50m' );
    has 'cache_max_items'           => ( is => 'rw', isa => 'Int', default => 20 );
    has 'cache_namespace'           => ( is => 'rw', isa => 'Str', default => 'LacunaWaX');

    sub _build_cache_root_dir {#{{{
        my $self = shift;
        return "$FindBin::Bin/../cache" if $self->_check_cache_root_dir( "$FindBin::Bin/../cache" );
    };#}}}
    sub _check_cache_expires_in {#{{{
        my $self = shift;
        my $new_expiry = shift;
        return Time::Duration::Parse::parse_duration($new_expiry);  # will die on bad expiry spec.
    };#}}}
    sub _check_cache_root_dir {#{{{
        my $self = shift;
        my $new_dir = shift;
        my $old_dir = shift;
        if( -d -w $new_dir ) {
            return 1;
        }
        else {
            if( $old_dir and -d -w $old_dir ) {
                warn "Default cache directory '$new_dir' does not exist or not writable; keeping old cache directory '$old_dir'.";
                return $old_dir;
            }
            die "Default cache directory '$new_dir' does not exist or not writable; caching impossible.";
        }
    };#}}}
    sub _check_caller_type {#{{{
        ### This trigger is emulating an enum, which we could get out of 
        ### Moose::Util::TypeConstraints.  However, we cannot use that, as it 
        ### contains a prototype that disagrees with Bread::Board, hence this 
        ### trigger.
        my $self     = shift;
        my $new_type = shift;
        my $old_type = shift;
        unless( $new_type ~~ [qw(web local)] ) {
            die "Invalid caller_type '$new_type'; must be 'web' or 'local'."
        }
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
            die "Invalid log_file_min_level '$new_type'; see valid_log_levels() for valid options.";
        }
    }#}}}

    sub valid_log_levels {
        return qw(debug info notice warning error critical alert emergency);
    }
    sub BUILD {
        my $self = shift;

        container $self => as {
            container 'Cache' => as {#{{{
                service 'cache_size'        => $self->cache_size;
                service 'expires_variance'  => $self->cache_expires_variance;
                service 'global'            => $self->cache_global;
                service 'max_items'         => $self->cache_max_items;
                service 'namespace'         => $self->cache_namespace;
                service 'root_dir'          => $self->cache_root_dir;

                service 'fast_mmap' => (#{{{
                    lifecycle    => 'Singleton',
                    dependencies => {
                        cache_size          => depends_on('Cache/cache_size'),
                        expires_variance    => depends_on('Cache/expires_variance'),
                        namespace           => depends_on('Cache/namespace'),
                        root_dir            => depends_on('Cache/root_dir'),
                    },
                    block => sub {
                        my $s = shift;
                        my $chi = CHI->new(
                            driver              => 'FastMmap',
                            root_dir            => $self->cache_root_dir,
                            expires_variance    => $self->cache_expires_variance,
                            cache_size          => $self->cache_size,

                            ### $s->param('namespace') is locked once set.  If 
                            ### we were using that below, the user would not 
                            ### be able to change the cache_namespace 
                            ### attribute of his container and then request a 
                            ### cache with a different namespace.
                            #namespace           => $s->param('namespace'),

                            ### By directly accessing $self->cache_namespace 
                            ### instead, we _can_ return a cache with a 
                            ### different namespace.
                            namespace           => $self->cache_namespace,
                        );
                        return $chi;
                    },
                );#}}}
                service 'raw_memory' => (#{{{
                    dependencies => {
                        expires_variance    => depends_on('Cache/expires_variance'),
                        global              => depends_on('Cache/global'),
                        max_items           => depends_on('Cache/max_items'),
                    },
                    block => sub {
                        use CHI;
                        my $s = shift;
                        my $chi = CHI->new(
                            driver              => 'RawMemory',
                            expires_variance    => $s->param('expires_variance'),
                            global              => $s->param('global'),
                            max_items           => $s->param('max_items'),
                        );
                        return $chi;
                    },
                );#}}}
            };#}}}
            container 'Database' => as {#{{{
                service 'db_name'       => 'lacuna';
                service 'host'          => (Sys::Hostname::hostname() eq 'jon-vostro') ? 'tmtowtdi.gotdns.com' : 'Titus';
                service 'port'          => 3306;
                service 'username'      => 'lacuna';
                service 'password'      => 'vrbansk';
                service 'sql_options'   => $self->sql_options;
                service 'dsn' => (#{{{
                    dependencies => {
                        db_name     => depends_on('Database/db_name'),
                        host        => depends_on('Database/host'),
                        port        => depends_on('Database/port'),
                    },
                    block => sub {
                        my $s = shift;
                        my $dsn = 'DBI:mysql:'
                                . 'database=' . $s->param('db_name') . ';'
                                . 'host='     . $s->param('host') . ';'
                                . 'port='     . $s->param('port');
                        return $dsn;
                    },
                );#}}}
                service 'connection' => (#{{{
                    class        => 'DBI',
                    lifecycle    => 'Singleton',
                    ### The two schemas below are making their own 
                    ### connections, so are not using this connection service.  But 
                    ### the Log/dbi service _is_ using it.
                    dependencies => {
                        dsn         => (depends_on('Database/dsn')),
                        username    => (depends_on('Database/username')),
                        password    => (depends_on('Database/password')),
                        sql_options => (depends_on('Database/sql_options')),
                    },
                    block => sub {
                        my $s = shift;
                        return DBI->connect(
                            $s->param('dsn'),
                            $s->param('username'),
                            $s->param('password'),
                            $s->param('sql_options'),
                        );
                    },
                );#}}}
                service 'main_schema' => (#{{{
                    ### making this a singleton is what's leaving the zombie 
                    ### db connections, so leave this commented.
                    #lifecycle => 'Singleton',
                    dependencies => [
                        depends_on('Database/dsn'),
                        depends_on('Database/username'),
                        depends_on('Database/password'),
                        depends_on('Database/sql_options'),
                    ],
                    class => 'Games::Lacuna::Schema',
                    block => sub {
                        my $s = shift;
                        my $conn = Games::Lacuna::Schema->connect(
                            $s->param('dsn'),
                            $s->param('username'),
                            $s->param('password'),
                            $s->param('sql_options'),
                        );
                        return $conn;
                    }
                );#}}}
                service 'users_schema' => (#{{{
                    ### making this a singleton is what's leaving the zombie 
                    ### db connections, so leave this commented.
                    #lifecycle => 'Singleton',
                    dependencies => [
                        depends_on('dsn'),
                        depends_on('Database/username'),
                        depends_on('Database/password'),
                        depends_on('Database/sql_options'),
                    ],
                    class => 'Games::Lacuna::Webtools::Schema',
                    block => sub {
                        my $s = shift;
                        my $conn = Games::Lacuna::Webtools::Schema->connect(
                            $s->param('dsn'),
                            $s->param('username'),
                            $s->param('password'),
                            $s->param('sql_options'),
                        );
                        return $conn;
                    }
                );#}}}
            };#}}}
            container 'Log' => as {#{{{
                service 'log_file'      => $self->log_file;
                service 'log_time_zone' => $self->log_time_zone;

                container 'Outputs' => as {#{{{
                    service 'file' => (#{{{
                        dependencies => [
                            depends_on('../Log/log_file'),
                            depends_on('../Log/log_time_zone'),
                        ],
                        class => 'Log::Dispatch::FileRotate',
                        block => sub {
                            my $s = shift;
                            use DateTime;
                            return unless $s->param('log_file');
                            unless(-e $s->param('log_file') ) {
                                ### doesn't exist - can we create?
                                open my $f, '>', $s->param('log_file') 
                                    or die "Unable to create log '" . $s->param('log_file') . q{'.};
                                close $f;
                            }
                            unless(-e -f -w $s->param('log_file') ) {
                                die "Log file '" . $s->param('log_file') . "' - not a file or not writable.";
                            }
                            Log::Dispatch::FileRotate->new(
                                binmode     => ':utf8',
                                filename    => $s->param('log_file'),
                                max         => 3,               # no. of old files to keep
                                min_level   => 'info',
                                mode        => 'append',
                                name        => 'file',
                                newline     => 1,
                                size        => 1 * 1024 * 1024, # fill to 1mb before rotating
                                callbacks   => sub {
                                    my %h = @_; 
                                    return sprintf "[%s] - %s - %s",
                                            DateTime->now( time_zone => $s->param('log_time_zone') ), 
                                            uc $h{'level'}, 
                                            $h{'message'}; 
                                }
                            )
                        }
                    );#}}}
                    service 'screen' => (#{{{
                        class => 'Log::Dispatch::Screen',
                        dependencies => [
                            depends_on('../Log/log_time_zone'),
                        ],
                        block => sub {
                            my $s = shift;
                            use DateTime;
                            Log::Dispatch::Screen->new(
                                min_level   => 'debug',
                                name        => 'screen',
                                newline     => 1,
                                stderr      => 1,

                                callbacks   => sub {
                                    my %h = @_; 
                                    return sprintf "[%s] - %s - %s", 
                                            DateTime->now( time_zone => $s->param('log_time_zone') ), 
                                            uc $h{'level'}, 
                                            $h{'message'}; 
                                }
                            )
                        }
                    );#}}}
                    service 'dbi' => (#{{{
                        ### Sends notice or higher level events to the 
                        ### SchedulerLog table.  Includes the name of the 
                        ### current empire.  These entries are displayed to 
                        ### the user in the webapp's profile page.  
                        ### periodic_tasks.pl wipes all entries for an empire 
                        ### when it begins.
                        class => 'Log::Dispatch::LacunaSchedulerDBI',
                        #lifecycle => 'Singleton',
                        dependencies => {
                            log_time_zone   => depends_on('/Log/log_time_zone'),
                            dbh             => depends_on('/Database/connection'),
                        },
                        block => sub {
                            my $s = shift;
                            use DateTime;
                            Log::Dispatch::LacunaSchedulerDBI->new(
                                min_level   => 'notice',
                                name        => 'dbi',
                                dbh         => $s->param('dbh'),
                                table       => 'ScheduleLog',
                                empire      => $self->empire,
                                time_zone   => $s->param('log_time_zone'),
                                callbacks   => sub{ my %h = @_; return sprintf "%s", $h{'message'}; }
                            )
                        }
                    );#}}}
                };#}}}
                service 'logger' => (#{{{
                    lifecycle => 'Singleton',
                    dependencies => [
                        depends_on('Outputs/file'),
                        depends_on('Outputs/screen'),
                    ],
                    class => 'Log::Dispatch',
                    block => sub {
                        my $s = shift;
                        my $Outputs_container   = $s->parent;
                        my $outputs             = $Outputs_container->get_sub_container('Outputs');
                        my $log                 = Log::Dispatch->new;
                        $log->add( $outputs->get_service('file')->get )   if $self->log_file;
                        $log->add( $outputs->get_service('screen')->get ) if $self->log_to_screen;
                        $log;
                    }
                );#}}}
                service 'logger_with_db' => (#{{{
                    lifecycle => 'Singleton',
                    dependencies => [
                        depends_on('Outputs/file'),
                        depends_on('Outputs/screen'),
                        depends_on('Outputs/dbi'),
                    ],
                    class => 'Log::Dispatch',
                    block => sub {
                        my $s = shift;
                        my $Outputs_container   = $s->parent;
                        my $outputs             = $Outputs_container->get_sub_container('Outputs');
                        my $log                 = Log::Dispatch->new;
                        $log->add( $outputs->get_service('file')->get )   if $self->log_file;
                        $log->add( $outputs->get_service('screen')->get ) if $self->log_to_screen;
                        $log->add( $outputs->get_service('dbi')->get );
                        $log;
                    }
                );#}}}
            };#}}}
            container 'Game_server' => as {#{{{
                service 'empire_name'   => $self->empire || q{};
                service 'password'      => $self->password || q{};
                service 'uri'           => $self->uri;
                service 'api_key'       => $self->api_key;
                service 'caller_type'   => $self->caller_type;
                service 'no_cache'      => $self->no_cache;

                service 'connection' => (#{{{
                    class        => 'Games::Lacuna::Client::App',
                    lifecycle    => 'Singleton',
                    dependencies => {
                        name            => depends_on('empire_name'),
                        password        => depends_on('password'),
                        api_key         => depends_on('api_key'),
                        chi             => depends_on('/Cache/raw_memory'),     # Must be raw_memory for this, NOT fast_mmap.
                        caller_type     => depends_on('caller_type'),
                        logger          => ($self->log_to_db) ?  depends_on('/Log/logger_with_db') : depends_on('/Log/logger'),
                        no_cache        => depends_on('no_cache'),
                        schema          => depends_on('/Database/main_schema'),
                        uri             => depends_on('uri'),
                        users_schema    => depends_on('/Database/users_schema'),
                    },
                    block => sub {
                        my $s = shift;
                        use Games::Lacuna::Client::App;
                        my $conn = try {
                            my $c = Games::Lacuna::Client::App->new(
                                name            => $s->param('name'),
                                password        => $s->param('password'),
                                api_key         => $s->param('api_key'),
                                chi             => $s->param('chi'),
                                caller_type     => $s->param('caller_type'),
                                logger          => $s->param('logger'),
                                no_cache        => $s->param('no_cache'),
                                schema          => $s->param('schema'),
                                uri             => $s->param('uri'),
                                users_schema    => $s->param('users_schema'),
                            );
                            ### UF says the game was getting repeated login 
                            ### attempts from a user who was already over 
                            ### their RPC limit.  If this is trying to 
                            ### reconnect, ensure that there's at least a 
                            ### short sleep in between attempts.
                            sleep 3;
                            return $c;
                        }
                        catch {
                            return 0;
                        };
                        return $conn;
                    }
                );#}}}
                service 'empire' => (#{{{
                    class        => 'Games::Lacuna::Client::Task::Empire',
                    dependencies => {
                        client => depends_on('Game_server/connection'),
                    },

                    ### If this is set as a singleton:
                    ###     - Brand new user accesses the profile page; he has 
                    ###     not yet entered his empire name or sitter.
                    ###
                    ###     - He enters empire name and sitter in form and 
                    ###     hits submit, beginning a single web request
                    ###
                    ###     - Web request grabs client from BreadBoard (ok)
                    ###
                    ###     - That same web request then grabs empire from 
                    ###     BreadBoard
                    ###         - But the empire was set as a singleton, so 
                    ###         was created when the web request started, 
                    ###         before we'd processed his empire name and 
                    ###         password.
                    ###         - So attempts to resolve the empire out of the 
                    ###         BreadBoard explode in firey death.
                    ### 
                    ###
                    ### So don't make this a singleton.  Or, if you do, be 
                    ### sure to create a new empire on the web app's edit 
                    ### profile handler like this:
                    #       my $empire = Games::Lacuna::Client::Task::Empire->new({ client => $client });
                    ###
                    ### instead of trying to resolve it out of the BreadBoard.
                    ###
                    #lifecycle    => 'Singleton',

                );#}}}
            };#}}}
        };
    }
}

1;

