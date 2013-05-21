
package LacunaWaX::MainFrame::StatusBar {
    use v5.14;
    use Moose;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_SIZE EVT_TIMER);
    with 'LacunaWaX::Roles::GuiElement';

    has 'status_bar'        => (is => 'rw', isa => 'Wx::StatusBar', lazy_build => 1                 );
    has 'gauge'             => (is => 'rw', isa => 'Wx::Gauge',     lazy_build => 1                 );
    has 'caption'           => (is => 'rw', isa => 'Str',           lazy_build => 1                 );
    has 'old_w'             => (is => 'rw', isa => 'Int',           lazy => 1,          default => 0);
    has 'old_h'             => (is => 'rw', isa => 'Int',           lazy => 1,          default => 0);

    sub BUILD {
        my $self = shift;
        $self->bar_reset; # Resets the whole bar, including the gauge.
        return $self;
    }
    sub _build_status_bar {#{{{
        my $self = shift;

        my $y;
        unless( $y = $self->parent->GetStatusBar ) {
            ### Don't recreate the statusbar if it already exists, as in the 
            ### transition from the intro panel to the main splitter window.
            $y = $self->parent->CreateStatusBar(2);
        }
        return $y;
    }#}}}
    sub _build_caption {#{{{
        my $self = shift;
        return $self->app->bb->resolve(service => '/Strings/app_name')
    }#}}}
    sub _build_gauge {#{{{
        my $self = shift;
        my $rect = $self->status_bar->GetFieldRect(1);
        my $g = Wx::Gauge->new(
            $self->status_bar,  # parent
            -1,                 # id
            100,                # value range
            Wx::Point->new($rect->x, $rect->y), 
            Wx::Size->new($rect->width, $rect->height), 
            wxGA_HORIZONTAL
        );
        $g->SetValue(0);
        return $g;
    }#}}}
    sub _set_events {#{{{
        my $self = shift;
        EVT_SIZE(   $self->status_bar,                  sub{$self->OnResize(@_)}    );
        return 1;
    }#}}}

    sub bar_reset {#{{{
        my $self = shift;
        $self->status_bar->DestroyChildren();
        $self->status_bar->SetStatusWidths(-5, -1);
        $self->status_bar->SetStatusText($self->caption, 0);

        my $rect = $self->status_bar->GetFieldRect(1);
        $self->gauge( $self->_build_gauge );
        $self->app->Yield;

        $self->status_bar->Update;
        return $self->status_bar;
    }#}}}
    sub change_caption {#{{{
        my $self = shift;
        my $new_text = shift;
        my $old_text = $self->status_bar->GetStatusText(0);
        $self->caption($new_text);
        $self->status_bar->SetStatusText($new_text, 0);
        return $old_text;
    }#}}}

    sub OnResize {#{{{
        my($self, $status_bar, $event) = @_;

        if( $self->app->has_main_frame ) {
            my $mf = $self->app->main_frame;
            my $current_size = $mf->frame->GetSize;
            if( $current_size->width != $self->old_w or $current_size->height != $self->old_h ) {
                $self->bar_reset;    # otherwise the throbber gauge gets all screwy
                $self->old_w( $current_size->width );
                $self->old_h( $current_size->height );
            } 
        }
        return 1;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

1;
