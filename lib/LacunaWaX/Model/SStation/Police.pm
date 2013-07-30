
package LacunaWaX::Model::SStation::Police {
    use v5.14;
    use utf8;
    use open qw(:std :utf8);
    use Data::Dumper;
    use Moose;
    use POSIX qw(ceil);
    use Try::Tiny;
    use URI;
    use URI::Query;

    has 'precinct' => (
        is          => 'rw',
        isa         => 'Games::Lacuna::Client::Buildings::PoliceStation', 
        required    => 1,
    );

    has 'game_client' => (
        is          => 'rw', 
        isa         => 'LacunaWaX::Model::Client', 
        required    => 1,
    );

    has 'alliance_members' => (
        is          => 'rw',
        isa         => 'ArrayRef',
        traits      => ['Array'],
        lazy_build  => 1,
        handles => {
            isa_member => 'first',
        }
    );

    sub _build_alliance_members {#{{{
        my $self = shift;
        my $ar = [];
        $ar = try {
            $self->game_client->get_alliance_members('as array ref');
        }
        catch {
            my $msg = (ref $_) ? $_->text : $_;
            "Unable to get current player's alliance members: $msg";
        };

        return $ar;
    }#}}}
    sub has_hostile_spies {#{{{
        my $self = shift;

=pod

Returns true if there are any spies onsite not set to Counter Espionage.

view_foreign_spies() gives each spy's name, task, level, and time to next 
mission.  It does not report the spy's owner, or if he's a friendly or not.

So the best logic we can go with is, if there's a spy on a SS who's not set to 
Counter Espionage, he's likely a problem.

Only detects spies whose level is < the police station's level.

Unlike incoming_hostiles, there _is_ a reasonable chance, as when the station 
is under attack, that there will be more than 25 defending spies taking up the 
entire first page of results.  So this does page all the way through all spies 
onsite.

CHECK that's completely untested; I have no SSs with > 25 spies, and none with 
any hostiles (that I know of).

=cut

        my $page = my $max_page = my $loops = 0;
        while(1) {
            $page++;
            $loops++;
            if( $loops > 20 ) {
                die "well shit.";
            }
            last if $max_page and $page > $max_page;
            my $spies = $self->precinct->view_foreign_spies($page);
            $max_page = ceil( $spies->{'spy_count'} / 25 ) unless $max_page;
            $max_page ||= 1;    # in case there are 0 spies onsite
            foreach my $s( @{$spies->{'spies'}} ) {
                if( $s->{'task'} eq 'Counter Espionage' ) {
                }
                else {
                    return 1;
                }
            }
        }

        return 0;
    }#}}}
    sub incoming_hostiles {#{{{
        my $self = shift;

=pod

If there are incoming ships, checks to see if the sending empire is a member 
of the current user's alliance.  If not, the ship is hostile and a true value 
is returned.  If no or only allied ships are incoming, returns false.

Note that this will only check the first page of incoming ships.  The chances 
of 25 allied ships heading in and taking up the entire first page, to be 
followed on subsequent pages by hostile ships, is so low that I'm not going to 
bother trying to page through all of the results.

=cut

        my $ships_inc = try {
            $self->precinct->view_foreign_ships(1);
        };

        if( $ships_inc->{'number_of_ships'} ) {
            for my $s( @{$ships_inc->{'ships'}} ) {
                my $empire = $s->{'from'}{'empire'}{'name'};
                unless( $self->isa_member(sub{$_->{'name'} eq $empire}) ) {
                    return 1;
                }
            }
        }

        return 0;
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
