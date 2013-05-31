use v5.14;
use warnings;

package LacunaWaX::Servers {
    use Moose;

    has 'schema' => (
        is          => 'ro',
        isa         => 'LacunaWaX::Model::Schema',
        required    => 1,
    );
    has 'servers' => (
        is      => 'ro',
        isa     => 'HashRef[LacunaWaX::Model::Schema::Servers]',
        traits  => ['Hash'],
        handles => {
            ids     => 'keys',
            records => 'values',
            pairs   => 'kv',
            get     => 'get',
        },
        lazy_build => 1,
    );

    sub _build_servers {
        my $self = shift;
        my $servers_rs  = $self->schema->resultset('Servers')->search();
        my $hr = {};
        while(my $rec = $servers_rs->next) {
            $hr->{$rec->id} = $rec;
        }
        return $hr;
    }

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

1;

