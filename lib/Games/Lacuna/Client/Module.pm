package Games::Lacuna::Client::Module;
{
  $Games::Lacuna::Client::Module::VERSION = '0.003';
}
use 5.0080000;
use strict;
use warnings;
use Carp 'croak';

use Class::XSAccessor {
  getters => [qw(client uri)],
};

require Games::Lacuna::Client;

sub api_methods_without_session { croak("unimplemented"); }
sub api_methods_with_session { croak("unimplemented"); }

sub module_prefix {
  my $self = shift;
  my $class = ref($self)||$self;
  $class =~ /::(\w+)+$/ or croak("unimplemented");
  return lc($1);
}

sub session_id {
  my $self = shift;
  return $self->client->assert_session();
}

sub new {
  my $class = shift;
  my %opt = @_;
  my $client = $opt{client} || croak("Need Games::Lacuna::Client");

  my $self = bless {
    %opt,
  } => $class;
  $self->{uri} = $self->client->uri . '/' . $self->module_prefix;

  return $self;
}

sub init {
  my $class = shift;

  $class->_generate_api_methods($class->api_methods);
}

sub _generate_api_methods {
  my $class = shift;
  my $method_specs = shift || croak("Missing method specs");

  foreach my $method_name (keys %$method_specs) {
    my $target = $class->_find_target_name($method_name);
    my $spec = $method_specs->{$method_name};
    $class->_generate_method_per_spec($target, $method_name, $spec);
  }
}

sub _generate_method_per_spec {
  my $class       = shift;
  my $target      = shift;
  my $method_name = shift;
  my $spec        = shift;

  my $default_args  = $spec->{default_args};

  my $sub = sub {
    my $self = shift;
    my $client = $self->client;

    # prepend the default parameters to the arguments
    my $params = [
      (map $self->$_(), @$default_args),
      @_
    ];


    ### JDB
    ###
    ### The following comments and block were from a fix I made a while ago; 
    ### GLC has updated since then so I'm removing my 'fix' because I don't 
    ### think it's needed anymore (07/2012).
    ###
    ### For whatever reason, the $params that come in on a call to 
    ### Alliance::view_profile are:
    ###     session_id
    ###     undef
    ###     alliance_id
    ###
    ### ...and the call never works.
    ###
    ### I can't figure out where that 'undef' is coming from.  But just 
    ### yoinking it out of $params, leaving us with
    ###     session_id
    ###     alliance_id
    ###
    ### ...the call works, assuming you provided a correct alliance_id.
    #if( $method_name eq 'view_profile' ) {
    #    splice @$params, 1, 1;
    #}


    if ($client->debug) {
      print STDERR "DEBUG: " . __PACKAGE__ . " request " . Data::Dumper::Dumper([$self->uri, $method_name, $params]);
    }

    ### JDB
    ### Added 07/2012
    ### this next (original) line is the one that's been producing the error 
    ### in cleanup ($client->rpc is undefined then):
    #my $ret = $client->rpc->call($self->uri, $method_name, $params);

    ### JDB my fix is a bit of a kludge, but is stopping the warnings.
    my $ret = q{};
    if( $client->rpc and ref $client->rpc eq 'Games::Lacuna::Client::TMTRPC') {
        $ret = $client->rpc->call($self->uri, $method_name, $params);
    }
    else {
        return;
    }
    ### end JDB

    if ($client->debug) {
      print STDERR "DEBUG: " . __PACKAGE__ . " result " . Data::Dumper::Dumper($ret);
    }

    if (ref $ret eq 'HASH' and exists $ret->{result} and ref $ret->{result} eq 'HASH') {
        $self->client->{rpc_count} =
            $ret->{result}{status} ? $ret->{result}{status}{empire}{rpc_count} :
            $ret->{result}{empire} ? $ret->{result}{empire}{rpc_count} :
            $self->client->{rpc_count};
    }

    return $ret->{result};
  };

  no strict 'refs';
  *{"$target"} = $sub;
}

sub _find_target_name {
  my $class = shift;
  my $method_name = shift;
  no strict 'refs';
  my $target = "${class}::$method_name";
  if (defined &{"$target"}) {
    $target = "${class}::_$method_name";
  }
  return $target;
}

1;
__END__

=head1 NAME

Games::Lacuna::Client::Empire - The empire module

=head1 SYNOPSIS

  use Games::Lacuna::Client;

=head1 DESCRIPTION

=head1 AUTHOR

Steffen Mueller, E<lt>smueller@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Steffen Mueller

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
