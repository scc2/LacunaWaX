
package LacunaWaX::Model::Client::Spy {
    use Moose;
    use Try::Tiny;

    has 'hr'                => ( is => 'rw', isa => 'HashRef', required => 1 );
    has 'id'                => ( is => 'rw', isa => 'Int', lazy_build => 1 );
    has 'name'              => ( is => 'rw', isa => 'Str', lazy_build => 1 );
    has 'assignment'        => ( is => 'rw', isa => 'Str', lazy_build => 1 );
    has 'level'             => ( is => 'rw', isa => 'Int', lazy_build => 1 );
    has 'politics'          => ( is => 'rw', isa => 'Int', lazy_build => 1 );
    has 'mayhem'            => ( is => 'rw', isa => 'Int', lazy_build => 1 );
    has 'theft'             => ( is => 'rw', isa => 'Int', lazy_build => 1 );
    has 'intel'             => ( is => 'rw', isa => 'Int', lazy_build => 1 );
    has 'offense'           => ( is => 'rw', isa => 'Int', lazy_build => 1 );
    has 'defense'           => ( is => 'rw', isa => 'Int', lazy_build => 1 );
    has 'assigned_to_id'    => ( is => 'rw', isa => 'Int', lazy_build => 1 );
    has 'based_from_id'     => ( is => 'rw', isa => 'Int', lazy_build => 1 );
    has 'is_available'      => ( is => 'rw', isa => 'Int', lazy_build => 1 );
    has 'seconds_remaining' => ( is => 'rw', isa => 'Int', lazy_build => 1 );
    has 'mission_count_off' => ( is => 'rw', isa => 'Int', lazy_build => 1 );
    has 'mission_count_def' => ( is => 'rw', isa => 'Int', lazy_build => 1 );

### POD {#{{{
=pod

Passed a hashref, as from an Int Min's view_spies or view_all_spies, returns a 
spy object.

=cut
### }#}}}

    sub BUILD {
        my $self = shift;
    }
    sub _build_id {#{{{
        my $self = shift;
        return $self->hr->{'id'};
    }#}}}
    sub _build_name {#{{{
        my $self = shift;
        return $self->hr->{'name'};
    }#}}}
    sub _build_assignment {#{{{
        my $self = shift;
        return $self->hr->{'assignment'};
    }#}}}
    sub _build_level {#{{{
        my $self = shift;
        return $self->hr->{'level'};
    }#}}}
    sub _build_politics {#{{{
        my $self = shift;
        return $self->hr->{'politics'};
    }#}}}
    sub _build_mayhem {#{{{
        my $self = shift;
        return $self->hr->{'mayhem'};
    }#}}}
    sub _build_theft {#{{{
        my $self = shift;
        return $self->hr->{'theft'};
    }#}}}
    sub _build_intel {#{{{
        my $self = shift;
        return $self->hr->{'intel'};
    }#}}}
    sub _build_offense {#{{{
        my $self = shift;
        return $self->hr->{'offense_rating'};
    }#}}}
    sub _build_defense {#{{{
        my $self = shift;
        return $self->hr->{'defense_rating'};
    }#}}}
    sub _build_assigned_to_id {#{{{
        my $self = shift;
        return $self->hr->{'assigned_to'}{'body_id'};
    }#}}}
    sub _build_based_from_id {#{{{
        my $self = shift;
        return $self->hr->{'based_from'}{'body_id'};
    }#}}}
    sub _build_is_available {#{{{
        my $self = shift;
        return $self->hr->{'is_available'};
    }#}}}
    sub _build_seconds_remaining {#{{{
        my $self = shift;
        return $self->hr->{'seconds_remaining'};
    }#}}}
    sub _build_mission_count_off {#{{{
        my $self = shift;
        return $self->hr->{'mission_count'}{'offensive'};
    }#}}}
    sub _build_mission_count_def {#{{{
        my $self = shift;
        return $self->hr->{'mission_count'}{'defensive'};
    }#}}}
}

1;
