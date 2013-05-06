
=pod

This is being use'd by StatusBar.pm, but it doesn't actually do anything.

=cut

package LacunaWaX::MainFrame::StatusBar::Timer {
    use v5.14;
    use strict;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_TIMER);
    use base 'Wx::Timer';

    sub new {
        my $class = shift;
        my $gauge = shift;
        my $self = $class->SUPER::new($gauge, -1);
        bless $self, $class;
        return $self;
    }
    sub Notify {
        say 'pulsing gauge';
    }

}

1;
