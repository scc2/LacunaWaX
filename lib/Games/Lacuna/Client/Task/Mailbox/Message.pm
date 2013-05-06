package Games::Lacuna::Client::Task::Mailbox::Message;
use 5.14.0;
#use CHI;
use Data::Dumper;  $Data::Dumper::Indent = 1;
use Moose;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use utf8;

BEGIN {
    ### $Id: Message.pm 14 2012-12-10 23:19:27Z jon $
    ### $URL: https://tmtowtdi.gotdns.com:15000/svn/LacunaWaX/trunk/lib/Games/Lacuna/Client/Task/Mailbox/Message.pm $
    my $revision = '$Rev: 14 $';
    $Games::Lacuna::CLient::Task::Station::VERSION = '0.2.' . join '', $revision =~ m/(\d+)/;
}

### 'alliance' is not doc'd as a legal tag, but I just got an explosion 
### complaining that it was used as a tag.  I'd guess it was added to the code 
### but not the docs.
my @legal_tags = qw(
    tutorial correspondence medal intelligence alert attack colonization complaint 
    excavator mission parliament probe spies trade alliance
);
subtype 'Tag', as 'Maybe[ArrayRef]', where { grep{ (lc $_ ~~ @legal_tags) or not $_ }@$_; };

no Moose::Util::TypeConstraints;

has 'client'        => ( isa => 'Games::Lacuna::Client', is => 'rw' );
#has 'chi'           => ( isa => 'Object', is  => 'rw', lazy_build => 1 );
has 'mdate_parser'  => ( isa => 'DateTime::Format::Builder', is  => 'rw', lazy_build => 1 );

has 'id'            => ( isa => 'Int', is => 'rw' );
has 'subject'       => ( isa => 'Str', is => 'rw' );
has 'date'          => ( isa => 'Str', is => 'rw' );
has 'datetime'      => ( isa => 'DateTime', is => 'rw' );
has 'to_id'         => ( isa => 'Int', is => 'rw' );
has 'from_id'       => ( isa => 'Int', is => 'rw' );
has 'to'            => ( isa => 'Str', is => 'rw' );
has 'from'          => ( isa => 'Str', is => 'rw' );
has 'has_read'      => ( isa => 'Int', is => 'rw' );
has 'has_replied'   => ( isa => 'Int', is => 'rw' );
has 'tags'          => ( isa => 'Tag', is => 'rw' );

#sub _build_chi {#{{{
#    CHI->new( 
#        driver     => 'RawMemory',
#        expires_in => '15 minutes',
#        global     => 1,
#        namespace  => __PACKAGE__,
#    );
#}#}}}
sub _build_mdate_parser {#{{{

=pod
    
 my $datestring_from_mail_message = '07 03 2012 06:46:03 +0000';
 my $dt = $mbox->mdate_parser( $datestring_from_mail_message );
 
 say $dt->year;   # 2012
 say $dt->hour;   # 6
 say $dt->minute; # 46
 ...etc...

So $dt is just a DateTime object.

=cut

    my $p = DateTime::Format::Builder->new();
    $p->parser(
        regex => qr|(\d\d) (\d\d) (\d{4}) (\d\d):(\d\d):(\d\d) \+(\d{4})|,
        params => [qw( day month year hour minute second )]
    );
    return $p;
}#}}}

1;
__END__

=head1 AUTHOR

Jonathan D. Barton, E<lt>jdbarton@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Jonathan D. Barton

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut

