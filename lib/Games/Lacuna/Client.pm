
package Games::Lacuna::Client {
    {
        $Games::Lacuna::Client::VERSION = '0.003';
    }
    use 5.0080000;
    use strict;
    use warnings;
    use Carp 'croak';
    use File::Temp qw( tempfile );
    use Cwd        qw( abs_path );

    use constant DEBUG => 1;

    use Games::Lacuna::Client::Module; # base module class
    use Data::Dumper ();
    use YAML::Any ();

    #our @ISA = qw(JSON::RPC::Client);
    use Class::XSAccessor {
    getters => [qw(
        rpc
        uri name password api_key
        cache_dir
    )],
    accessors => [qw(
        debug
        session_id
        session_start
        session_timeout
        session_persistent
        cfg_file
        allow_sleep
        rpc_sleep
        prompt_captcha
        open_captcha
    )],
    };

    require Games::Lacuna::Client::TMTRPC;
    require Games::Lacuna::Client::Alliance;
    require Games::Lacuna::Client::Body;
    require Games::Lacuna::Client::Buildings;
    require Games::Lacuna::Client::Captcha;
    require Games::Lacuna::Client::Empire;
    require Games::Lacuna::Client::Inbox;
    require Games::Lacuna::Client::Map;
    require Games::Lacuna::Client::Stats;

    sub new {#{{{
        my $class = shift;
        my %opt = @_;
        if ($opt{cfg_file}) {
            open my $fh, '<', $opt{cfg_file}
            or croak("Could not open config file for reading: $!");
            my $yml = YAML::Any::Load(do { local $/; <$fh> });
            close $fh;
            $opt{name}     = defined $opt{name} ? $opt{name} : $yml->{empire_name};
            $opt{password} = defined $opt{password} ? $opt{password} : $yml->{empire_password};
            $opt{uri}      = defined $opt{uri} ? $opt{uri} : $yml->{server_uri};
            $opt{open_captcha}   = defined $opt{open_captcha}   ? $opt{open_captcha}   : $yml->{open_captcha};
            $opt{prompt_captcha} = defined $opt{prompt_captcha} ? $opt{prompt_captcha} : $yml->{prompt_captcha};
            for (qw(uri api_key session_start session_id session_persistent cache_dir)) {
            if (exists $yml->{$_}) {
                $opt{$_} = defined $opt{$_} ? $opt{$_} : $yml->{$_};
            }
            }
        }
        my @req = qw(uri name password api_key);
        croak("Need the following parameters: @req")
            if not exists $opt{uri}
            or not exists $opt{name}
            or not exists $opt{password}
            or not exists $opt{api_key};
        $opt{uri} =~ s/\/+$//;

        my $debug = exists $ENV{GLC_DEBUG} ? $ENV{GLC_DEBUG}
                    :                          0;

        my $self = bless {
            session_start      => 0,
            session_id         => 0,
            session_timeout    => 3600*1.8, # server says it's 2h, but let's play it safe.
            session_persistent => 0,
            cfg_file           => undef,
            debug              => $debug,
            %opt
        } => $class;

        # the actual RPC client
        $self->{rpc} = Games::Lacuna::Client::TMTRPC->new(client => $self);

        return $self,
    }#}}}
    sub empire {#{{{
        my $self = shift;
        return Games::Lacuna::Client::Empire->new(client => $self, @_);
    }#}}}
    sub alliance {#{{{
        my $self = shift;
        return Games::Lacuna::Client::Alliance->new(client => $self, @_);
    }#}}}
    sub body {#{{{
        my $self = shift;
        return Games::Lacuna::Client::Body->new(client => $self, @_);
    }#}}}
    sub building {#{{{
        my $self = shift;
        return Games::Lacuna::Client::Buildings->new(client => $self, @_);
    }#}}}
    sub captcha {#{{{
        my $self = shift;
        return Games::Lacuna::Client::Captcha->new(client => $self, @_);
    }#}}}
    sub inbox {#{{{
        my $self = shift;
        return Games::Lacuna::Client::Inbox->new(client => $self, @_);
    }#}}}
    sub map {#{{{
        my $self = shift;
        return Games::Lacuna::Client::Map->new(client => $self, @_);
    }#}}}
    sub stats {#{{{
        my $self = shift;
        return Games::Lacuna::Client::Stats->new(client => $self, @_);
    }#}}}
    sub register_destroy_hook {#{{{
        my $self = shift;
        my $hook = shift;
        push @{$self->{destroy_hooks}}, $hook;
    }#}}}
    sub DESTROY {#{{{
        my $self = shift;
        if ($self->{destroy_hooks}) {
            $_->($self) for @{$self->{destroy_hooks}};
        }
    }#}}}
    sub write_cfg {#{{{
        my $self = shift;
        if ($self->debug) {
            print STDERR "DEBUG: Writing configuration to disk";
        }
        croak("No config file")
            if not defined $self->cfg_file;
        my %cfg = map { ($_ => $self->{$_}) } qw(session_start
                                                session_id
                                                session_timeout
                                                session_persistent
                                                cache_dir
                                                api_key);
        $cfg{server_uri}      = $self->{uri};
        $cfg{empire_name}     = $self->{name};
        $cfg{empire_password} = $self->{password};
        my $yml = YAML::Any::Dump(\%cfg);

        eval {
            my $target = $self->cfg_file();

            # preserve symlinks: operate directly at destination
            $target = abs_path $target;

            # save data to a temporary, so we don't risk trashing the target
            my ($tfh, $tempfile) = tempfile("$target.XXXXXXX"); # croaks on err
            print {$tfh} $yml or die $!;
            close $tfh or die $!;

            # preserve mode in temporary file
            my (undef, undef, $mode) = stat $target or die $!;
            chmod $mode, $tempfile or die $!;

            # rename should be atomic, so there should be no need for flock
            rename $tempfile, $target or die $!;

            1;
        } or do {
            warn("Can not save Lacuna client configuration: $@");
            return;
        };

        return 1;
    }#}}}
    sub assert_session {#{{{
        my $self = shift;

        my $now = time();
        if (!$self->session_id || $now - $self->session_start > $self->session_timeout) {
        if ($self->debug) {
            print STDERR "DEBUG: Logging in since there is no session id or it timed out.\n";
        }
        my $res = $self->empire->login($self->{name}, $self->{password}, $self->{api_key});
        $self->{session_id} = $res->{session_id};
        if ($self->debug) {
            print STDERR "DEBUG: Set session id to $self->{session_id} and updated session start time.\n";
        }
        }
        elsif ($self->debug) {
            print STDERR "DEBUG: Using existing session.\n";
        }
        $self->{session_start} = $now; # update timeout
        return $self->session_id;
    }#}}}
    sub get_config_file {#{{{
        my ($class, $files, $optional) = @_;
        $files = ref $files eq 'ARRAY' ? $files : [ $files ];
        $files = [map {
            my @values = ($_);
            my $dist_file = eval {
                require File::HomeDir;
                File::HomeDir->VERSION(0.93);
                require File::Spec;
                my $dist = File::HomeDir->my_dist_config('Games-Lacuna-Client');
                File::Spec->catfile(
                $dist,
                $_
                ) if $dist;
            };
            warn $@ if $@;
            push @values, $dist_file if $dist_file;
            @values;
        } grep { $_ } @$files];

        foreach my $file (@$files) {
            return $file if ( $file and -e $file );
        }

        die "Did not provide a config file (" . join(',', @$files) . ")" unless 
        $optional;
        return;
    }#}}}

}

1;
