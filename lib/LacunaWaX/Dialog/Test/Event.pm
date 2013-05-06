

package LacunaWaX::TestEvent {
    use v5.14;
    use base 'Wx::PlCommandEvent';

    our @EXPORT_OK = qw(EVT_MYEVENT);

    sub EVT_MYEVENT {
        my $button = shift;
        my $func   = shift;

        my $event = Wx::PlCommandEvent->new('EVT_MYEVENT', $button->GetId);
        $event->SetEventObject($button);

        my $type = $event->GetEventType; say "--$type--";    # 0
        my $dat = $event->GetClientData; say "--$dat--" . (ref $dat);    # undef
        #my $obj = $event->GetClientObject;  # boom

        $button->$func($event);
    }
}

1;

