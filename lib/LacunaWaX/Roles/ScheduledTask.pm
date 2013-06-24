use v5.14;

package LacunaWaX::Roles::ScheduledTask {
    use LacunaWaX::Model::Client;
    use LacunaWaX::Model::Container;
    use Moose::Role;
    use Try::Tiny;

    has 'game_client' => (
        is          => 'rw', 
        isa         => 'LacunaWaX::Model::Client', 
        documentation => q{
            Do not pass this in; it will be created as-needed on a per-server 
            basis by calls to game_connect().
        },
    );
    has 'bb' => (
        is          => 'rw',
        isa         => 'LacunaWaX::Model::Container',
        required    => 1,
    );
    has 'logger' => (
        is          => 'rw',
        isa         => 'Log::Dispatch',
        lazy_build  => 1,
    );
    has 'schema' => (
        is          => 'rw',
        isa         => 'LacunaWaX::Model::Schema',
        lazy_build  => 1,
    );

    sub _build_logger {#{{{
        my $self = shift;
        return $self->bb->resolve( service => '/Log/logger' );
    }#}}}
    sub _build_schema {#{{{
        my $self = shift;
        return $self->bb->resolve( service => '/Database/schema' );
    }#}}}

    sub game_connect {#{{{
        my $self      = shift;
        my $server_id = shift;

        ### This will fail if the user hasn't filled out their creds yet, which 
        ### includes if they haven't got a PT account.
        my $client = try {
            LacunaWaX::Model::Client->new (
                bb          => $self->bb,
                server_id   => $server_id,
                interactive => 0,
                allow_sleep => 1,   # allow to sleep 60 seconds on RPC Limit error
                rpc_sleep   => 2,   # time to sleep between each request
            )
        }
        catch {
            return;
        };

        return unless $client;

        $self->game_client( $client );
        return $self->game_client->ping;
    }#}}}

    no Moose::Role;
}

1;
