use v5.14;

package Games::Lacuna::Client::TMTRPC {
    use Moose;
    use JSON::RPC::LWP;
    use Exception::Class (
        'LacunaException',
        'LacunaRPCException' => {
            isa         => 'LacunaException',
            description => 'The RPC service generated an error.',
            fields      => [qw(code text)],
        },
    );

    has client => ( is => 'ro', isa => 'Games::Lacuna::Client', required => 1, weak_ref => 1    );
    has json   => ( is => 'rw', isa => 'JSON::RPC::LWP',        lazy_build => 1                 );

    sub _build_json {#{{{
        my $self = shift;
        return JSON::RPC::LWP->new;
    }#}}}
    sub call {#{{{
        my $self    = shift;
        my $uri     = shift;
        my $method  = shift;
        my $params  = shift;
        my $depth   = shift || 1;

        my $resp = $self->json->call($uri, $method, $params);
        if($self->client->rpc_sleep) {
            for(1..$self->client->rpc_sleep) {
                ### Preferable to one long sleep for allowing the GUI to update 
                ### if needed.
                sleep 1;
                &{$self->client->yield_method} if $self->client->can('yield_method');
            }
        }

        if( $resp and $resp->has_error and $self->client->debug ) {
            say 'Code: ' . $resp->error->code . '-';
            say 'Message: ' . $resp->error->message;
            say 'Allow sleep: ' . $self->client->allow_sleep;
            say 'RPC sleep: ' . $self->client->rpc_sleep;

            if( $resp->error->code eq '1010' or $resp->error->code eq '-32603' ) {
                say "Code says too many RPCs.";
            }
            if( $resp->error->message =~ /slow down/i or $resp->error->message =~ /Internal error/i ) {
                say 'Message says too many RPCs.';
            }
        }

        ### I've begun getting error code -32603 ("Internal error.") instead of 
        ### the expected 1010 ("Slow down!...") error after quacking the duck 60 
        ### times in the browser and then running this.  I don't know why that 
        ### is, but I'm getting it consistently, so I'm just going to treat that 
        ### as a synonym for the 1010 error.
        ### I'm getting other errors as documented.
        if( 
                $resp 
            and $resp->has_error 
            and ($resp->error->code eq '1010' or $resp->error->code eq '-32603')
            ### At this point, it _is_ 'message', not 'text'.  'text' is 
            ### available outside.
            ### (same as message but without /^RPC Error (9999): /)
            and ($resp->error->message =~ /slow down/i or $resp->error->message =~ /Internal error/i)
            and $self->client->allow_sleep
        ) {
            if( $depth > 3 ) {
                LacunaRPCException->throw(
                    error   => "RPC Error (999): Likely infinite recursion",
                    code    => 999,
                    text    => 'Likely infinite recursion.',
                )
            }
            
            sleep 61;
            $resp = $self->call($uri, $method, $params, ++$depth);
            return $resp;   # already deflated!
        }

        LacunaRPCException->throw(
            error   => "RPC Error (" . $resp->error->code . "): " . $resp->error->message,
            code    => $resp->error->code,
            text    => $resp->error->message,
        ) if $resp->error;

        return $resp->deflate;
    }#}}}
}

1;

