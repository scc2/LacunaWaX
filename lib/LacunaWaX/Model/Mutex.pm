
package LacunaWaX::Model::Mutex {
    use v5.14;
    use Carp;
    use English qw( -no_match_vars );
    use LacunaWaX::Model::Container;
    use Moose;
    use Try::Tiny;

    has 'bb'            => (is => 'rw', isa => 'LacunaWaX::Model::Container',   required   => 1);
    has 'name'          => (is => 'rw', isa => 'Str',                           required   => 1);
    has 'lockfile'      => (is => 'rw', isa => 'Str',                           lazy_build => 1);
    has 'filehandle'    => (is => 'rw', isa => 'FileHandle',                    lazy_build => 1);

    sub BUILD {
        my $self = shift;
        $self->filehandle;
        return $self;
    }
    sub DEMOLISH {#{{{
        my $self = shift;
        $self->lock_un;
        return 1;
    }#}}}
    sub _build_filehandle {#{{{
        my $self = shift;
        open my $fh, q{>}, $self->lockfile or croak $ERRNO;
        close $fh or croak $ERRNO;
        open $fh, q{<}, $self->lockfile or croak $ERRNO;    ## no critic qw(RequireBriefOpen)
        return $fh;
    }#}}}
    sub _build_lockfile {#{{{
        my $self = shift;
        my $dir = $self->bb->resolve( service => '/Directory/user' );
        my $f = join q{/}, ($dir, $self->name);
        return $f;
    }#}}}

    sub lock_sh {#{{{
        my $self = shift;
        return flock $self->filehandle, 1;
    }#}}}
    sub lock_shnb {#{{{
        my $self = shift;
        return flock $self->filehandle, 1|4;
    }#}}}
    sub lock_ex {#{{{
        my $self = shift;
        return flock $self->filehandle, 2;
    }#}}}
    sub lock_exnb {#{{{
        my $self  = shift;
        return flock $self->filehandle, 2|4;
    }#}}}
    sub lock_un {#{{{
        my $self = shift;

        ### If the filehandle is already closed, attempting to call lock_un (8) 
        ### will result in the warning "flock() on unclosed filehandle", which 
        ### we really don't care about.
        ### In that case, close() will also complain, which again, we don't care 
        ### about.
        ### Last, if the file is already gone and unlink() fails, we don't care 
        ### about that either.
        ### Try::Tiny isn't catching the warning, 'no warnings' is.  The try 
        ### blocks are just for good measure.
        no warnings;    ## no critic qw(ProhibitNoWarnings)
        my $rv1 = try { flock $self->filehandle, 8; };
        my $rv2 = try { close $self->filehandle or croak $ERRNO; };
        my $rv3 = try { unlink $self->lockfile; };
        use warnings;

        return $rv1;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;

__END__

=head1 NAME

LacunaWaX::Model::Mutex - Provide mutual exclusion facilities for LacunaWaX.

=head1 SYNOPSIS

 $bb = <LacunaWaX::Model::Container object>;
 $m  = LacunaWaX::Model::Mutex->new( bb => $bb, name => 'schedule' );

 unless( $m->lock_shnb ) {
  $log->info("Shared lock not possible right now; I'll have to block to get one.");
  $m->lock_sh;
 }

 unless( $m->lock_exnb ) {
  $log->info("Exclusive lock not possible right now; I'll have to block to get one.");
  $m->lock_ex;
 }

 $m->lock_un;

=head1 DESCRIPTION

Meant to resemble flock, but allows for locking of a process rather than a file 
(though it can certainly also be used to lock a file).  Multiple exclusive 
locks may be obtained, provided each mutex has a different name:

 $m1 = LacunaWaX::Model::Mutex->new( bb => $bb, name => 'lock_one' );
 $m2 = LacunaWaX::Model::Mutex->new( bb => $bb, name => 'lock_two' );

 $m1->lock_ex;
 $m2->lock_ex;  

The second lock request above does not block, since the two mutexes have 
different names, and are therefore meant to lock different things.

Checking for an existing lock first is not required, but it allows you to log 
the fact that you're about to start blocking, or to do something else entirely 
if you don't want to block.  To check for an existing lock, call one of the 
non-blocking methods first, as in the synopsis.

=head1 REFERENCE

=head2 METHODS

=head3 Constructor

 $bb = <LacunaWaX::Model::Container object>;
 $m  = LacunaWaX::Model::Mutex->new( bb => $bb, name => 'schedule' );

Requires a LacunaWaX::Model::Container to be passed in so Model::Mutex can determine where it 
should create its lockfiles.

Also requires a name.  Mutexes will only block other mutexes that have the same 
name.  The lockfiles use by Mutex.pm are created using that name, so do not pass 
names that are invalid inode identifiers.

=head3 lock_sh, lock_ex

Obtain a shared or exclusive lock.  Just like flock, multiple simultaneous 
shared locks are fine, but an exclusive lock must be the only (exclusive or 
shared) lock at any given time.

Both block until they're able to obtain the requested lock.

=head3 lock_shnb, lock_exnb

Obtain a shared or exclusive lock, but do not block if the lock cannot be 
obtained.

Both return false if the lock could not be grabbed.  Normally, you'll just call 
the blocking version directly afterwards, but you'll at least know that you're 
about to block, and can log that fact or whatever else you need to do.

=head3 lock_un

Releases any current lock.  This will be called implicitly when your Mutex 
object passes out of scope or is otherwise destroyed.

 $m->lock_un;   # explicit unlock
 undef $m;      # implicit unlock on object destruction

The lockfile itself will be removed when the last Mutex unlocks it.

