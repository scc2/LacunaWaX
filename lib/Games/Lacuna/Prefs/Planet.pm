use 5.12.0;
package Games::Lacuna::Prefs::Planet;
use Data::Dumper; $Data::Dumper::Indent = 1;
use Moose;
use Moose::Util::TypeConstraints qw(enum);

# $Id: Planet.pm 14 2012-12-10 23:19:27Z jon $
# $URL: https://tmtowtdi.gotdns.com:15000/svn/LacunaWaX/trunk/lib/Games/Lacuna/Prefs/Planet.pm $

BEGIN {
    my $revision = '$Rev: 14 $';
    ### Non-destructive substitution requires 5.14.0; hold off on forcing that 
    ### for now.
    $Games::Lacuna::Prefs::Planet::VERSION = '0.1.' . join '', $revision =~ m/(\d+)/;
}

has 'name' => ( isa => 'Str', is => 'rw');

has hours_between_excavators    => ( isa => 'Maybe[Int]', is => 'rw', clearer => 'clear_hours_between_excavators', );
has trash_run_at                => ( isa => 'Maybe[Int]', is => 'rw', clearer => 'clear_trash_run_at', );
has recycle_for                 => ( isa => 'Maybe[Int]', is => 'rw', clearer => 'clear_recycle_for', );
has shipyard                    => ( isa => 'Maybe[Str]', is => 'rw', clearer => 'clear_shipyard', );
has glyph_transport             => ( isa => 'Maybe[Str]', is => 'rw', clearer => 'clear_glyph_transport', );
has train_spies_intel           => ( isa => 'Maybe[ArrayRef[Str]]', is => 'rw', clearer => 'clear_train_spies_intel', );
has train_spies_politics        => ( isa => 'Maybe[ArrayRef[Str]]', is => 'rw', clearer => 'clear_train_spies_politics', );
has train_spies_mayhem          => ( isa => 'Maybe[ArrayRef[Str]]', is => 'rw', clearer => 'clear_train_spies_mayhem', );
has train_spies_theft           => ( isa => 'Maybe[ArrayRef[Str]]', is => 'rw', clearer => 'clear_train_spies_theft', );

#has res_push => ( isa => 'Maybe[ArrayRef[Str]]', is => 'rw' );

sub _top_level {#{{{
    my $self = shift;
    my $key = shift;
    my $val = shift;

=pod

WTF is this doing here in Planet.pm?  I think it's an artifact of copying this file
from ../Prefs.pm but be sure of that before deleting it.


Setter/getter for preferences.  To completely delete a preference, send a 
hashref rather than a string as the argument.  If the hashref has a key named 
'delete' set to a true value, the preference will go away.

On deletion, the previous value will be returned.

 my $original_uri = $prefs->server_uri;
 $prefs->server_uri('http://www.example.com');

 my $uri_before_deletion = $prefs->server_uri({ delete => 1});
 say $uri_before_deletion;      # http://www.example.com
 say $prefs->server_uri;        # undef

=cut

    if( ref $val eq 'HASH' and $val->{'delete'} ) {
        return delete $self->prefs->{$key};
    }
    if( defined $val and $val ne '' ) {
        return $self->prefs->{$key} = $val;
    }
    return $self->prefs->{$key};
}#}}}

__PACKAGE__->meta->make_immutable;

1;

