use v5.14;
use warnings;
use utf8;

=pod

This exists to set permissions on the install directory to world-writable on 
various versions of Windows.

The installer requires Admin permisssions to run, but the program does not, 
and is supposed to be run by multiple users.  So the INSTALL/user/ directory 
(at least) needs to have Everyone write permissions on it or the sqlite files 
inside will be locked and cause explosions.

=cut

package LacunaWaX::Model::Directory {
    use Carp;
    use Cwd qw(abs_path);
    use English qw( -no_match_vars );
    use File::Spec;
    use File::Which;
    use POSIX ":sys_wait_h";
    use Moose;

    has 'cacls' => (is => 'rw', isa => 'Str', lazy_build => 1);
    has 'path'  => (is => 'rw', isa => 'Str', trigger => \&_make_path_absolute);

    sub _build_cacls {#{{{
        my $self = shift;
        return q{} unless $OSNAME eq 'MSWin32';
        my $which = q{};
        foreach my $cand(qw(icacls cacls) ) {
            if( $which = which($cand) ) {
                last;
            }
        }
        return $which;
    }#}}}
    sub _make_path_absolute {#{{{
        my $self = shift;
        unless(-e $self->path) {
            croak $self->path . ": No such file or directory.";
        }
        my $ap = abs_path($self->path);
        $self->{'path'} = $ap;
        return $ap;
    }#}}}
    sub make_world_writable {#{{{
        my $self = shift;
        unless($self->path and -e $self->path) {
            croak "You must set the path attribute to a file or directory before calling make_world_writable.";
        }

        my @args;
        given($self->cacls) {
            when(/icacls/) {
                @args = ($self->path, '/grant', 'Everyone:(OI)(CI)F')
            }
            when(/cacls/) {
                ### This is not well-tested.  icacls should be on everything 
                ### but XP, and fixing the directory perms isn't really needed 
                ### on XP.  So this doesn't break, but I'm not convinced (nor 
                ### do I really care) that it's doing anything.
                @args = ($self->path, '/E', '/G', 'Everyone:F')
            }
            ### No options for non-windows because I don't need it.
        }

        my $rv = 0;
        if( $self->cacls ) {
            open my $cperr, '>&', STDERR or croak $ERRNO;       ## no critic qw(RequireBriefOpen)
            open my $cpout, '>&', STDOUT or croak $ERRNO;       ## no critic qw(RequireBriefOpen)
            open STDOUT, File::Spec->devnull or croak $ERRNO;   ## no critic qw(ProhibitTwoArgOpen)
            open STDERR, File::Spec->devnull or croak $ERRNO;   ## no critic qw(ProhibitTwoArgOpen)
            $rv = system $self->cacls, @args;
            open STDERR, '>&', $cperr or croak $ERRNO;
            open STDOUT, '>&', $cpout or croak $ERRNO;
        }
        return $rv; # 0 on success, > 0 on failure.
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;
