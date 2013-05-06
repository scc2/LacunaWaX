
package LacunaWaX::MainSplitterWindow::RightPane::RearrangerPane::SavedBuilding {
    use Moose;
    use Try::Tiny;
    use Wx qw(:everything);

    has 'bitmap'                => (is => 'rw', isa => 'Wx::Bitmap' );
    has 'bldg_id'               => (is => 'rw', isa => 'Maybe[Int]' );
    has 'efficiency'            => (is => 'rw', isa => 'Maybe[Int]' );
    has 'id'                    => (is => 'rw', isa => 'Maybe[Int]', documentation => 'ID of the Wx::BitmapButton' );
    has 'level'                 => (is => 'rw', isa => 'Maybe[Int]' );
    has 'name'                  => (is => 'rw', isa => 'Maybe[Str]' );
    has 'orig_x'                => (is => 'rw', isa => 'Maybe[Int]' );
    has 'orig_y'                => (is => 'rw', isa => 'Maybe[Int]' );

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;
