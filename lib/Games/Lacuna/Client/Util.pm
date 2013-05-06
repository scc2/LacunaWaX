package Games::Lacuna::Client::Util;
use feature ':5.10';
use Moose;
use DateTime;
use DateTime::Format::ISO8601;
use DateTime::Format::Strptime;
use File::Slurp;            # read_file(), write_file()
use YAML::XS;               # Load(), Dump()

BEGIN {
    my $file_id  = '$Id: Util.pm 14 2012-12-10 23:19:27Z jon $';
    my $file_url = '$URL: https://tmtowtdi.gotdns.com:15000/svn/LacunaWaX/trunk/lib/Games/Lacuna/Client/Util.pm $';
    my $revision = '$Rev: 14 $';
    $Games::Lacuna::Client::Util::VERSION = '0.1.' . join '', $revision =~ m/(\d+)/;
}

### Top POD {#{{{

=head1 NAME

Games::Lacuna::Client::Util - Utility grab-bag for Games::Lacuna::Client::*

=head1 SYNOPSIS

 my $ute = Games::Lacuna::Client::Util->new( time_zone => 'Africa/Abidjan' );

 say $ute->iso_datestring;

=head1 DESCRIPTION

This module provides some basic utilities helpful when working with the Lacuna 
Expanse API via Games::Lacuna::Client.  

=head1 Attributes

=head2 time_zone

The datetime string returned by iso_datestring() will be in this timezone.  
Defaults to America/New_York, simply because that's the author's timezone.  

=head2 game_strptime, db_strptime

L<DateTime::Format::Strptime> objects.  Created for you; you don't need to pass 
them in.

Allows you to parse dates both as returned by the game's API and as stored in 
the local database into DateTime objects.

The game returns dates as 21 10 2010 04:35:53 +0000
The database stores dates as 2010-10-21T04:35:53 (GMT is assumed here)

 $game_time     = '21 10 2010 04:35:53 +0000';
 $game_datetime = $ute->game_strptime->parse_datetime($game_time);
 say $game_datetime->hour; # 4

 $db_time     = '2010-10-21T04:35:53';
 $db_datetime = $ute->db_strptime->parse_datetime($db_time);
 say $db_datetime->hour; # still 4

=head1 Methods

=cut

### }#}}}

has 'time_zone' => (
    isa => 'Str',
    is => 'rw',
    default => 'America/New_York',
);
has 'game_strptime' => (
    isa => 'DateTime::Format::Strptime',
    is => 'rw',
    default => sub { DateTime::Format::Strptime->new( pattern => '%d %m %Y %T %z' ) },
);
has 'db_strptime' => (
    isa => 'DateTime::Format::Strptime',
    is => 'rw',
    default => sub { DateTime::Format::Strptime->new( pattern => '%Y-%m-%dT%T' ) },
);

sub cartesian_distance {#{{{
    my $self = shift;
    my($x1, $y1, $x2, $y2) = @_;

=head2 cartesian_distance

Returns the distance between two points on a Cartesian plane, represented as 
(x1, y1) and (x2, y2), 

 print $ute->cartesian_distance(1,1, 2,2);  # 1.4142135623731

DANGER
The number returned by this is quite likely to be a float with a lot of 
precision; attempting to perform math on this number without Math::BigFloat 
will end in heartache and despair.

=cut

    return sqrt( ($x2 - $x1)**2 + ($y2 - $y1)**2 );
}#}}}
sub display_image {#{{{
    my $self     = shift;
    my $filename = shift;

=head2 display_image

Given a full path to an image file, this displays that image to the user.

 $ute->display_image("/path/to/some/image.png");

B<TBD>
This is obviously pretty low-tech right now.  Could use some checking to 
ensure the file is an image and some other method of display than Windows' 
start(), which relies on the default image viewer and doesn't at all account 
for Linux or CLI-only or pretty much anything other than Windows.

=cut
    system("start $filename");

}#}}}
sub hall_recipes {#{{{
    return [
        [qw(goethite halite gypsum trona)],
        [qw(gold anthracite uraninite bauxite)],
        [qw(kerogen methane sulfur zircon)],
        [qw(monazite fluorite beryl magnetite)],
        [qw(rutile chromite chalcopyrite galena)],
    ];
}#}}}
sub halls_to_level {#{{{
    my $self    = shift;
    my $current = shift;
    my $max     = shift;

=pod

Returns the number of halls needed to get from one level to another.

 say "It will take " 
    . $ute->halls_to_level(4, 10)
    . " halls to go from level 4 to level 10.";

=cut

    return $self->tri($max) - $self->tri($current);
}#}}}
sub triangle {#{{{

=pod

Just an alias to tri().

=cut

    return shift->tri(@_);
}#}}}
sub tri {#{{{
    my $self = shift;

=pod

Returns the triangle of an integer.

 say $ute->tri(4);  # 10
 say $ute->tri(5);  # 15
 say $ute->tri(30); # 465

The value returned is the correct triangle number.  However, since you need a 
plan to get yourself to level 1, the actual number of halls required for 
raising a building to a given level will actually be one less than this number 
(since you don't need one halls to get to level 1).

 say $ute->tri(2);  # 3
 say $ute->tri(2) - 1 . " halls needed to get a glyph bldg to level 2.";

=cut

    my $num = shift;
    return( $num * ($num+1) / 2 ); 
}#}}}
sub iso_datestring {#{{{
    my $self = shift;
    my $dt   = shift;

=head2 iso_datestring

Returns an ISO8601 datetime string in the format compatible with 
yaml_parse_datetimes.

Accepts a DateTime object.  If one is not passed in, the string returned will 
represent NOW in the current time zone.
 
 my $ute = Games::Lacuna::Client::Util->new( time_zone => 'Africa/Abidjan' );
 say $ute->iso_datestring; # 2011-11-01T18:29:01

 $ute->time_zone('America/New_York');
 say $ute->iso_datestring; # 2011-11-01T14:29:01

=cut

    $dt = ($dt and ref $dt eq 'DateTime') ? $dt : DateTime->now( time_zone => $self->time_zone );
    return $dt->ymd . 'T' . $dt->hms;
}#}}}
sub ore_types {#{{{

=head2 ore_types

Simply returns an alphabetical list (NOT A REF) of all types of ore in the game.

There's nothing programmatic about this; it's simply a hardcoded list.  This is 
not likely to be a problem, but the possibility does exist that ore types will
be added or removed at some point in the future, at which point any code using 
this method (if the method doesn't get modified) will break.

=cut

    return sort qw(
        anthracite
        bauxite
        beryl
        chalcopyrite
        chromite
        fluorite
        galena
        goethite
        gold
        gypsum
        halite
        kerogen
        magnetite
        methane
        monazite
        rutile
        sulfur
        trona
        uraninite
        zircon
    );

}#}}}
sub trim {#{{{
    my( $self, $s ) = @_;

=pod

Simple whitespace trimmer.

 my $s = "    hi     ";
 say '-' . $ute->trim($s) . '-';    # -hi-

=cut

    $s =~ s/^\s*(.*?)\s*$/$1/;
    return $s;
}#}}}
sub read_yaml {#{{{
    my $self = shift;
    my $file = shift;

=head2 read_yaml

Given a string file path, reads that file and passes its contents through a 
YAML parser.  Returns the resulting structure.

YAML values in our specific ISO8601 datetime string format will automatically 
be converted to DateTime objects.  The format we're using is
    YYYY-MM-DDThh:mm:ss

Any other format, even if it's an accepted ISO8601 format, will not be 
auto-converted into a DateTime object.

=cut

    my $str = read_file($file);
    my $yaml = Load $str;
    $self->yaml_parse_datetimes( $yaml );
    return $yaml;
}#}}}
sub write_yaml {#{{{
    my $self = shift;
    my($file, $ref) = @_;

=head2 write_yaml

Given a file path and a Perl reference, formats the reference into YAML and 
writes the result into the file.  If the file exists, it will be overwritten.

If any of the values in the given reference are objects of class DateTime, 
they'll first be converted into the specific ISO8601 format readable by 
read_yaml():  
    YYYY-MM-DDThh:mm:ss

Simply dumping the DateTime object without first converting it back to a 
string would work programmatically, but it would make the YAML hard to read 
for a human.  

=cut

    $self->yaml_format_datetimes($ref);
    my $str = "### This file is automatically generated.
### The data will be read before the file is re-written, so manual changes to 
### the YAML will stick.  However, any comments you add manually will 
### disappear.
";
    $str .= Dump $ref;
    write_file($file, $str);
}#}}}
sub yaml_parse_datetimes {#{{{
    my $self = shift;
    my $ref = shift;

=head2 yaml_parse_datetimes

Given a Perl data structure, assumes that structure is the result of reading a 
YAML file and transmogrifies strings in the proper format into DateTime 
objects.

Returns nothing; the structure is modified in-place.

The only string date/time format that gets turned into DateTime objects is

 YYYY-MM-DD . "T" . hh:mm:ss

=cut

    if( ref $ref eq 'ARRAY' ) {
        foreach my $e(@$ref) {
            if( ref $e eq 'ARRAY' or ref $e eq 'HASH' ) {
                $self->yaml_parse_datetimes($e);
            }
            elsif( my $reftype = ref $e ) {
                die "All members must be either arrayref, hashref, or scalar.  Got '$reftype' reference.";
            }
            else {
                return $ref unless $ref =~ /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d$/;
                $e = DateTime::Format::ISO8601->parse_datetime( $ref );
            }

        }
    }
    elsif( ref $ref eq 'HASH' ) {
        while(my($n,$v) = each %$ref) {
            next unless $v;
            if( ref $v eq 'ARRAY' or ref $v eq 'HASH' ) {
                $self->yaml_parse_datetimes($v);
            }
            elsif( my $reftype = ref $v ) {
                die "All members must be either arrayref, hashref, or scalar.  Got '$reftype' reference.";
            }
            else {
                return unless $v =~ /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d$/;
                $ref->{$n} = DateTime::Format::ISO8601->parse_datetime( $v );
            }
        }
    }
}#}}}
sub yaml_format_datetimes {#{{{
    my $self = shift;
    my $ref  = shift;

=head2 yaml_format_datetimes

Accepts any Perl reference.  Walks the reference and turns any DateTime objects 
into a simple string in the format

 YYYY-MM-DD . "T" . hh:mm:ss

Returns nothing; the structure is modified in-place.

=cut

    if( ref $ref eq 'ARRAY' ) {
        foreach my $e(@$ref) {
            if( ref $e eq 'ARRAY' or ref $e eq 'HASH' ) {
                $self->yaml_format_datetimes($e);
            }
            elsif( ref $e eq 'DateTime' ) {
                $e = "$e";
            }
        }
    }
    elsif( ref $ref eq 'HASH' ) {
        while(my($n,$v) = each %$ref) {
            if( ref $v eq 'ARRAY' or ref $v eq 'HASH' ) {
                $self->yaml_format_datetimes($v);
            }
            elsif( ref $v eq 'DateTime' ) {
                $ref->{$n} = "$v";
            }
        }
    }
}#}}}

1;

__END__

=head1 SEE ALSO

API docs at L<http://us1.lacunaexpanse.com/api/>.

L<Games::Lacuna::Client>
L<Games::Lacuna::Client::Task>

=head1 AUTHOR

Jonathan D. Barton, E<lt>jdbarton@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Jonathan D. Barton

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut

