package Games::Lacuna::Client::Task::Mailbox;
use 5.14.0;
#use CHI;
use Data::Dumper;  $Data::Dumper::Indent = 1;
use DateTime;
use DateTime::Format::Builder;
use Games::Lacuna::Client::Task::Mailbox::Message;
use List::Util;
### Message.pm needs to use Moose for M::U::TypeConstraints.  Since we're 
### use'ing Message.pm, we need to use Moose rather than Moo as well.
#use Moo;  
use Moose;
use Try::Tiny;
use utf8;

BEGIN {
    ### $Id: Mailbox.pm 14 2012-12-10 23:19:27Z jon $
    ### $URL: https://tmtowtdi.gotdns.com:15000/svn/LacunaWaX/trunk/lib/Games/Lacuna/Client/Task/Mailbox.pm $
    my $revision = '$Rev: 14 $';
    $Games::Lacuna::CLient::Task::Mailbox::VERSION = '0.1.' . join '', $revision =~ m/(\d+)/;
}

### POD {#{{{

=head1 SYNOPSIS

 my $mbox = $client->mailbox;

You must check the box before looking inside it:

 $msgs = $mbox->in_inbox;   # $msgs is empty!

 $mbox->check_inbox;
 $msgs = $mbox->in_inbox;   # $msgs is non-empty.

in_inbox, in_archive, in_trash all return hashrefs keyed off the Message ID.  
Values will be GLCT::Mailbox::Message objects.

=head2 Built-in DateTime Parser

Most of the time you'll just want to use $msg->datetime, which is a DateTime 
object created from $msg->date, the datestring returned by the server.

You can access the parser that created that datetime object, eg if you need to 
convert a server-generated datetime string you encounter somewhere else:

 $string = '07 03 2012 05:11:52 +0000';
 $dt = $msg_obj->mdate_parser->parse_datetime( $string );
 say $dt->year; # 2012

=cut

### }#}}}

has 'client' => ( isa => 'Games::Lacuna::Client::App',   is => 'rw' );
has 'inbox'  => ( isa => 'Games::Lacuna::Client::Inbox', is  => 'rw', lazy_build => 1 );

has 'in_inbox'   => ( isa => 'HashRef', is  => 'rw', default => sub {{}} );
has 'in_archive' => ( isa => 'HashRef', is  => 'rw', default => sub {{}} );
has 'in_trash'   => ( isa => 'HashRef', is  => 'rw', default => sub {{}} );

sub _build_inbox {#{{{
    my $self = shift;
    $self->client->inbox;
}#}}}
sub _check_box {#{{{
    my $self           = shift;
    my $box            = shift;
    my $requested_page = shift || 1;

=pod

 $self->_check_box('inbox', 1);     # get page 1 of inbox
 $self->_check_box('inbox', 2);     # get page 2 of inbox
 $self->_check_box('inbox', 'all'); # get all messages in inbox

 $self->_check_box('trashed');  # get page 1 (default) of trash
 $self->_check_box('archived'); # get page 1 (default) of archive

The first arg must be 'inbox', 'trashed', or 'archived'.
The second arg can be a page number, undef, or 'all'.  Actually, any string 
that contains no digits will be read as 'all'.
 
=cut

    my $meth = 'view_' . $box;
    my $msg_objects = [];
    my $curr_page = ($requested_page =~ /^\d+$/) ? $requested_page : 1;
    my $c = $self->client;
    while(1) {
        ### inbox() _is_ a method of the Client.  Yes, I know it's confusing.

        my $msgs = try {
            $c->call( $c->inbox, $meth, [{ page_number => $curr_page }] );
        }
        catch {
            $c->log->debug("Checking box '$box' page '$curr_page' failed: $_");
        };

        unless( $msgs and defined $msgs->{'messages'} ) {
            $c->log->debug("I was unable to read any messages from the inbox ($curr_page).");
            return $msg_objects;
        }
        $msgs = $msgs->{'messages'};

        for my $m(@$msgs) {
            my $msg = try {
                $c->call( 'Games::Lacuna::Client::Task::Mailbox::Message', 'new', [$m] );
            }
            catch {
                $c->log->debug("Creating message object failed: $_");
            };
            $msg or return;
            $msg->datetime( $msg->mdate_parser->parse_datetime($msg->date) );
            push $msg_objects, $msg;
        }
        last if $requested_page =~ /\d+/;
        last unless (scalar @$msgs) == 25;
        $curr_page++;
    }
    return $msg_objects;
}#}}}

sub check_inbox {#{{{
    my $self = shift;
    my $page = shift || 1;

    my $msgs = $self->_check_box('inbox', $page);
    foreach my $m(@$msgs) {
        $self->in_inbox->{$m->id} = $m;
    }
}#}}}
sub check_archive {#{{{
    my $self = shift;
    my $page = shift || 1;

    my $msgs = $self->_check_box('archived', $page);
    foreach my $m(@$msgs) {
        $self->in_archive->{$m->id} = $m;
    }
}#}}}
sub check_trash {#{{{
    my $self = shift;
    my $page = shift || 1;

    my $msgs = $self->_check_box('trashed', $page);
    foreach my $m(@$msgs) {
        $self->in_trash->{$m->id} = $m;
    }
}#}}}
sub delete {#{{{
    my $self = shift;
    my $del  = shift;
    ref $del eq 'ARRAY' and scalar @$del or return {};

    my $inbox = $self->client->inbox;
    my $rv = $self->client->call( $inbox, 'trash_messages', [$del] );

=pod

 $rv = {
    success => [ deleted_id_1, deleted_id_2, ... ],
    failure => [ not_deleted_id_1, not_deleted_id_2, ... ],
 }

=cut

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

