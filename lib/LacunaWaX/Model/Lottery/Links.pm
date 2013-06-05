
=head1 NAME

LacunaWaX::Model::Lottery::Links - Iterator for Entertainment District lottery 
links.

=head1 DESCRIPTION

Lottery links are common across an entire empire.  There are currently 15 of 
them, each of which can be clicked on once per empire every 24 hours.  If an 
empire clicks one of those links, every other Entertainment District owned by 
that empire, regardless of its location, will display the other 14 links.

Although these 15 links result in the clicker ending up on the same 15 external 
websites, the links do feed through the lacunaexpanse game server first, to 
record the fact that the link has been clicked and to enter the clicker in the 
lottery.

Since there are separate lotteries for each zone in the game, the links to the 
game server I<do change depending upon the zone from which they were accessed>, 
although the final URLs (of the destination voting sites) do not change 
depending upon zone.

This means that the list of links represented by this module will be almost, but 
not quite, the same, regardless of originating Entertainment District.

When the list of links is first accessed, it will be cached.  So subsequent 
accesses to the list will return the same URLs.

Hitting these URLs will record the player as having played the lottery in the 
zone of the Entertainment District that first accessed the URLs.

To play the lottery in several differnt zones, it's vital therefore that you 
call the change_planet() method before hitting the lottery URLs.

=head1 SYNOPSIS

 use LacunaWaX::Model::Lottery::Links;
 use Try::Tiny;

 $links = try {
  LacunaWaX::Model::Lottery::Links->new(
   client      => LacunaWaX::Model::Client object
   planet_id   => Integer ID of planet with an Entertainment District
  );
 }
 catch {
  die "could not get Links object; probably no entertainment district on planet.";
 };

 while( $l = links->next ) {
  say $l->name . " goes to " . $l->url;
 }

 $links->reset_idx;     # now we can start over again with next()

...later, with a $different_planet...

 if( $links->planet_id ne $different_planet->id ) {
  $links->change_planet( $different_planet->id );
  while( $l = links->next ) {
   say $l->name . " goes to " . $l->url;
  }
 }

 say "There are " . $links->count . " links in total.";
 say "There are " . $links->remaining . " links left in the list.";
 say "We are at the beginning of the list." if $links->at_start;
 say "We are at the end of the list." if $links->at_end;

=head1 METHODS

=cut


package LacunaWaX::Model::Lottery::Links {
    use v5.14;
    use utf8;
    use open qw(:std :utf8);
    use Moose;
    use Try::Tiny;

    use LacunaWaX::Model::Lottery::Link;

    has 'client'    => (is => 'rw', isa => 'LacunaWaX::Model::Client',  required => 1, weak_ref => 1);
    has 'planet_id' => (is => 'rw', isa => 'Int',                       required => 1               );

    has 'idx' => (is => 'rw', isa => 'Int', lazy_build => 1);

    has 'links' => (
        is          => 'rw', 
        isa         => 'ArrayRef[LacunaWaX::Model::Lottery::Link]',  
        lazy_build  => 1,
    );

    sub BUILD {
        my $self = shift;

=head2 CONSTRUCTOR

  LacunaWaX::Model::Lottery::Links->new(
   client      => LacunaWaX::Model::Client object
   planet_id   => Integer ID of planet with an Entertainment District
  );

Both attributes are required.

If the planet_id passed in is invalid, or it's an ID of a planet without an 
Entertainment District, the constructor call will die.

=cut

        $self->links;
    }
    sub _build_idx {#{{{
        return 0;
    }#}}}
    sub _build_links {#{{{
        my $self = shift;

        ### Example Entertainment District URL
        ### https://us1.lacunaexpanse.com/entertainment/vote?session_id=934365d1-eb31-42d3-a878-9f1c93fe2a76&building_id=3181174&site_url=http%3A%2F%2Fwww.mmorpg100.com%2Fin.php%3Fid%3D6844

        my $links = $self->client->get_lottery_links( $self->planet_id );
        my $ar = [];
        foreach my $hr( @$links ) {
            my $l = LacunaWaX::Model::Lottery::Link->new(
                name => $hr->{'name'},
                url  => $hr->{'url'}
            );
            push @{ $ar }, $l;
        }

        return $ar;
    }#}}}
    sub _build_planet_id {#{{{
        my $self = shift;
        return $self->client->planet_id( $self->planet_name );
    }#}}}

    sub _dec_idx {#{{{
        my $self = shift;
        my $i = $self->idx;
        $self->idx( $i - 1 ) if $i > 0;
        return $self->idx;
    }#}}}
    sub _inc_idx {#{{{
        my $self = shift;
        my $i = $self->idx;
        $self->idx( $i + 1 );
        return $self->idx;
    }#}}}

    sub at_end {#{{{
        my $self = shift;

=head2 at_end

Returns true if we're currently at the end of our list of links.

=cut

        return( $self->idx >= $self->count ) ? 1 : 0;
    }#}}}
    sub at_start {#{{{
        my $self = shift;

=head2 at_start

Returns true if we're currently at the start of our list of links.

=cut

        return( $self->idx <= 0 ) ? 1 : 0;
    }#}}}
    sub change_building {#{{{
        my $self = shift;
        my $bid  = shift || die "Building ID must be given";

=head2 change_building

Changes the building to which our links are currently pointing.  This will 
change the zone that the lottery is recorded as being played at.

 my $this_planets_ent_district = get_entertainment_district;
 $links->change_building( $this_planets_ent_district->id );

However, it's generally more convenient to call L<change_planet|change_planet>.

=cut

        ### Do not use the ->next or ->prev iterators here; we don't want to 
        ### change the user's idx on him if he's already partway through the 
        ### list.
        foreach my $l(@{ $self->links }) {
            $l->change_building($bid);
        }
    }#}}}
    sub change_planet {#{{{
        my $self = shift;
        my $pid  = shift || die "Planet ID must be given";
        my $ent  = shift;

=head2 change_planet

Given a planet ID, finds that planet's Entertainment District and updates all 
links to use that building's ID.  After which, hitting the links' URLs will 
record the lottery as having been played in the current planet's zone.

Maintains your current location in the list of links

 for(1..2) {
    my $l = $links->next;
    # do stuff with your $l
 }

 my $this_planet = get_another_planet();
 $links->change_planet( $this_planet->id );

 for(1..2) {
    my $l = $links->next;
    # These links will now use $this_planet's ent dist, but will be the
    # third and fourth links in the original list.
 }

=cut

        unless( $ent and ref $ent eq 'Games::Lacuna::Client::Buildings::Entertainment' ) {
            $ent = $self->client->get_building($pid, 'Entertainment');
            unless( $ent and ref $ent eq 'Games::Lacuna::Client::Buildings::Entertainment' ) {
                die "No Entertainment district was found on this planet!  Change is impossible.";
            }
        }

        $self->planet_id($pid);
        $self->change_building($ent->{'building_id'});
    }#}}}
    sub count {#{{{
        my $self = shift;

=head2 count

 say $links->count . " links are in the list";

Returns the number of links in the list.  Any links that have already been 
clicked (eg in the browser client) will not be available for 24 hours from being 
clicked.  Already-clicked links will not be reflected in the list or in this 
count.

=cut

        return scalar @{ $self->links };
    }#}}}
    sub remaining {#{{{
        my $self = shift;

=head2 remaining

Returns the number of links remaining in the list, relative to your current 
location in the list.

 say $links->remaining . " links are left.";    # eg 10
 $links->next;
 $links->next;
 say $links->remaining . " links are left.";    # 8

=cut
        return $self->count - $self->idx;
    }#}}}
    sub reset_idx {#{{{
        my $self = shift;

=head2 reset_idx

Resets the internal pointer back to the start of the list.

 say $links->remaining . " links are left.";    # eg 10
 $l = $links->next;
 say $l->name;          # Some Site 1
 $l = $links->next;
 say $l->name;          # Some Site 2
 say $links->remaining . " links are left.";    # 8

 $links->reset_idx;
 say $links->remaining . " links are left.";    # back to 10 again
 $l = $links->next;
 say $l->name;          # Some Site 1 again

=cut

        $self->idx( 0 );
        return 0;
    }#}}}
    sub next {#{{{
        my $self = shift;

=head2 next

Returns the next LacunaWaX::Model::Lottery::Link object in the list.  Returns 
undef upon reaching the end of the list, and then resets the pointer.

***
That's true for now, but I'm now unsure if that's the 'correct' behavior.  
Once next() reaches the end of the list, I'm beginning to think that it should 
be the user's responsibility to reset the list to the beginning (with 
reset_idx) rather than doing it automatically.

It's a little academic right now, since nothing is relying on either behavior.
***

 while(my $l = $links->next ) {
    say $l->name;
 }
 say "I have shown you all the links in the list."

 while(my $l = $links->next ) {
    say $l->name;
 }
 say "Now I did it again."

=cut

        if( $self->at_end ) {
            $self->reset_idx;
            return;
        }
        my $l = $self->links->[$self->idx];
        $self->_inc_idx();
        return $l;
    }#}}}
    sub prev {#{{{
        my $self = shift;

=head2 prev

Do not use this.

This was added for completeness, but I'm running into the problem of being 
confused about the difference between next, current, and previous.

In a list of (1, 2, 3, 4, 5):
 
 say $links->next;  # show 1, update the index to point at 2
 say $links->next;  # show 2, update the index to point at 3

 say $links->prev;  # show 3, update the index to point back at 2

If you're on 2 and call prev(), you're certainly not going to be expecting to 
get back '3'.


Rather than overcomplicate the module by trying to fix that problem, I'm going 
to skip it.  I don't see any real-world need to call prev(), so fixing it would 
be fixing a non-existent problem.

=cut

        if( $self->at_start ) {
            return;
        }
        my $l = $self->links->[$self->idx];
        $self->_dec_idx();
        return $l;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

1;

