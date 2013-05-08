
package LacunaWaX::MainFrame::MenuBar {
    use v5.14;
    use Moose;
    use Wx qw(:everything);
    with 'LacunaWaX::Roles::GuiElement';

    ### Wx::MenuBar is a non-hash object.  Extending such requires 
    ### MooseX::NonMoose::InsideOut instead of plain MooseX::NonMoose.
    use MooseX::NonMoose::InsideOut;
    extends 'Wx::MenuBar';

    use LacunaWaX::MainFrame::MenuBar::Edit;
    use LacunaWaX::MainFrame::MenuBar::File;
    use LacunaWaX::MainFrame::MenuBar::Help;
    use LacunaWaX::MainFrame::MenuBar::Tools;

    has 'show_test'   => (is => 'rw', isa => 'Int',  lazy => 1, default => 0,
        documentation => q{
            If true, the Tools menu will include a "Test Dialog" entry, which 
            will display Dialog/Test.pm, which I'm using to play with controls 
            etc.
            Should generally be off.
        }
    );

    has 'menu_file'     => (is => 'rw', isa => 'LacunaWaX::MainFrame::MenuBar::File',          lazy_build => 1);
    has 'menu_edit'     => (is => 'rw', isa => 'LacunaWaX::MainFrame::MenuBar::Edit',          lazy_build => 1);
    has 'menu_tools'    => (is => 'rw', isa => 'LacunaWaX::MainFrame::MenuBar::Tools',         lazy_build => 1);
    has 'menu_help'     => (is => 'rw', isa => 'LacunaWaX::MainFrame::MenuBar::Help',          lazy_build => 1);

    has 'menu_list'     => (is => 'rw', isa => 'ArrayRef', lazy => 1,
        default => sub {
            [qw(
                menu_file
                menu_edit
                menu_tools
                menu_help
            )]
        },
        documentation => q{
            If you add a new menu to the bar, be sure to add its name to this list please.
        }
    );

    sub FOREIGNBUILDARGS {#{{{
        return; # Wx::Menu->new() takes no arguments
    }#}}}
    sub BUILD {
        my $self = shift;

        $self->Append( $self->menu_file,   "&File");
        $self->Append( $self->menu_edit,   "&Edit");
        $self->Append( $self->menu_tools,  "&Tools");
        $self->Append( $self->menu_help,   "&Help");

        return $self;
    }
    sub _build_menu_file {#{{{
        my $self = shift;
        my $v = LacunaWaX::MainFrame::MenuBar::File->new(
            ancestor    => $self,
            app         => $self->app,
            parent      => $self->parent,   # MainFrame, not this Menu, is the parent.
        );
        return $v;
    }#}}}
    sub _build_menu_file_connect {#{{{
        my $self = shift;
        my $v = LacunaWaX::MainFrame::MenuBar::File::Connect->new(
            ancestor    => $self,
            app         => $self->app,
            parent      => $self->parent,   # MainFrame, not this Menu, is the parent.
        );
        return $v;
    }#}}}
    sub _build_menu_edit {#{{{
        my $self = shift;
        my $v = LacunaWaX::MainFrame::MenuBar::Edit->new(
            ancestor    => $self,
            app         => $self->app,
            parent      => $self->parent,   # MainFrame, not this Menu, is the parent.
        );
        return $v;
    }#}}}
    sub _build_menu_help {#{{{
        my $self = shift;
        my $v = LacunaWaX::MainFrame::MenuBar::Help->new(
            ancestor    => $self,
            app         => $self->app,
            parent      => $self->parent,   # MainFrame, not this Menu, is the parent.
        );
        return $v;
    }#}}}
    sub _build_menu_tools {#{{{
        my $self = shift;
        my $v = LacunaWaX::MainFrame::MenuBar::Tools->new(
            ancestor    => $self,
            app         => $self->app,
            parent      => $self->parent,   # MainFrame, not this Menu, is the parent.
            show_test   => $self->show_test,
        );
        return $v;
    }#}}}
    sub _set_events { }

    ### Display or gray out any menu items that need it based on whether we're 
    ### currently connected or not.
    ### Individual menu classes should respond to this as needed.
    sub show_connected {#{{{
        my $self = shift;
        foreach my $submenu( @{$self->menu_list} ) {
            $self->$submenu->show_connected if $self->$submenu->can('show_connected');
        }
    }#}}}
    sub show_not_connected {#{{{
        my $self = shift;
        foreach my $submenu( @{$self->menu_list} ) {
            $self->$submenu->show_connected if $self->$submenu->can('show_connected');
        }
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

1;
