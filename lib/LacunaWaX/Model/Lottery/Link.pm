
package LacunaWaX::Model::Lottery::Link {
    use v5.14;
    use utf8;
    use open qw(:std :utf8);
    use Moose;
    use Try::Tiny;
    use URI;
    use URI::Query;

    has 'name'  => (is => 'rw', isa => 'Str', required => 1);
    has 'url'   => (is => 'rw', isa => 'Str', required => 1);

    has 'uri'       => (is => 'rw', isa => 'URI',           lazy_build => 1);
    has 'query'     => (is => 'rw', isa => 'URI::Query',    lazy_build => 1);

    sub _build_query {#{{{
        my $self  = shift;
        my $query = URI::Query->new($self->uri->query);
        return $query;
    }#}}}
    sub _build_uri {#{{{
        my $self = shift;
        my $uri  = URI->new($self->url);
        return $uri;
    }#}}}

    sub change_building {#{{{
        my $self = shift;
        my $bid  = shift || return;
        $self->query->replace(building_id => $bid);
        $self->uri->query($self->query);
        $self->url($self->uri->as_string);
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

1;

__END__

=head1 NAME

LacunaWaX::Model::Lottery::Link - Link to a voting site

=head1 SYNOPSIS

 use LacunaWaX::Model::Lottery::Link;

 $l = LacunaWaX::Model::Lottery::Link->new(
  name => $name,
  url  => $url
 );

=head1 DESCRIPTION

You won't normally need to use this module or construct objects from it 
explicitly.  Instead, you'll use L<LacunaWaX::Model::Lottery::Links|the Links 
module> to construct a list of links.

=cut
