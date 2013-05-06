use v5.14;
use utf8;       # so literals and identifiers can be in UTF-8
use strict;     # quote strings, declare variables
use warnings;   # on by default
use warnings    qw(FATAL utf8);    # fatalize encoding glitches
use open        qw(:std :utf8);    # undeclared streams in UTF-8 - does not get along with use autodie.
use charnames   qw(:full :short);  # unneeded in v5.16
use Data::Dumper;

use File::Copy qw(move);

my @imgs = glob '* (Custom).png';

for my $old(@imgs) {
    if( $old =~ /(\w+) \(Custom\)\.png/ ) {
        my $new = $1 . '_50x50.png';
        say "-$old- -$new-";
        #move($old, $new);
    }
}

