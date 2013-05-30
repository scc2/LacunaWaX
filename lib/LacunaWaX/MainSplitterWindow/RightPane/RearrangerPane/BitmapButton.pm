
package LacunaWaX::MainSplitterWindow::RightPane::RearrangerPane::BitmapButton {
    use v5.14;
    use Moose;
    use Try::Tiny;
    use Wx qw(:everything);
    with 'LacunaWaX::Roles::GuiElement';

    ### Wx::Menu is a non-hash object.  Extending such requires 
    ### MooseX::NonMoose::InsideOut instead of plain MooseX::NonMoose.
    use MooseX::NonMoose::InsideOut;
    extends 'Wx::BitmapButton';

    has 'sizer_debug' => (is => 'rw', isa => 'Int',  lazy => 1, default => 0);

    has 'bitmap'        => (is => 'rw', isa => 'Wx::Bitmap' );
    has 'bldg_id'       => (is => 'rw', isa => 'Maybe[Int]' );
    has 'name'          => (is => 'rw', isa => 'Maybe[Str]' );
    has 'level'         => (is => 'rw', isa => 'Maybe[Int]' );
    has 'efficiency'    => (is => 'rw', isa => 'Maybe[Int]' );
    has 'orig_x'        => (is => 'rw', isa => 'Maybe[Int]' );
    has 'orig_y'        => (is => 'rw', isa => 'Maybe[Int]' );
    has 'x'             => (is => 'rw', isa => 'Maybe[Int]' );
    has 'y'             => (is => 'rw', isa => 'Maybe[Int]' );

    sub FOREIGNBUILDARGS {## no critic qw(RequireArgUnpacking) {{{
        my $self = shift;
        my %args = @_;
        return ( $args{'parent'}, -1, $args{'bitmap'} );
    }#}}}
    sub BUILD {
        my($self, @params) = @_;
        $self->update_button_tooltip();
        return $self;
    };
    sub _set_events { }

    sub id_for_tooltip {#{{{
        my $self = shift;
        return $self->bldg_id;
    }#}}}
    sub level_for_label {#{{{
        my $self = shift;
        return sprintf "%02d", $self->level;
    }#}}}
    sub level_for_tooltip {#{{{
        my $self = shift;
        return $self->level;
    }#}}}
    sub name_for_tooltip {#{{{
        my $self = shift;
        return $self->name || 'Empty';
    }#}}}
    sub tooltip_contents {#{{{
        my $self = shift;
        return $self->name_for_tooltip . ' (level ' . $self->level_for_tooltip .  ', ID ' . $self->id_for_tooltip .')';
    }#}}}
    sub update_button_tooltip {#{{{
        my $self = shift;
        $self->SetToolTip( $self->tooltip_contents );
        return 1;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;
