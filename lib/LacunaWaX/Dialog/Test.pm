


###
### HTMLWindow.pm
###
### Displays an HTML window with a simple page that links to a second simple 
### page.
### 
### I'm planning on using this structure to create help documents.
###


package LacunaWaX::Dialog::Test {
    use v5.14;
    use Data::Dumper;
    use File::Slurp;
    use Moose;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_BUTTON EVT_CLOSE EVT_SIZE);
    with 'LacunaWaX::Roles::GuiElement';

    use MooseX::NonMoose::InsideOut;
    extends 'Wx::Dialog';

    has 'sizer_debug' => (is => 'rw', isa => 'Int',  lazy => 1, default => 1);

    has 'title' => (is => 'rw', isa => 'Str', lazy => 1, default => 'HTML Window');

    has 'fs_html'           => (is => 'rw', isa => 'Wx::FileSystem',    lazy_build => 1);
    has 'htm_window'        => (is => 'rw', isa => 'Wx::HtmlWindow',    lazy_build => 1);
    has 'lbl_instructions'  => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'szr_html'          => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => q{vertical});
    has 'szr_instructions'  => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => q{vertical});
    has 'szr_main'          => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => q{vertical});

    sub FOREIGNBUILDARGS {## no critic qw(RequireArgUnpacking) {{{
        my $self = shift;
        my %args = @_;

        return (
            undef, -1, 
            q{},        # the title
            wxDefaultPosition,
            Wx::Size->new(600, 700),
            wxRESIZE_BORDER|wxDEFAULT_DIALOG_STYLE
        );
    }#}}}
    sub BUILD {
        my($self, @params) = @_;
        $self->Show(0);

        $self->SetTitle( $self->title );
        $self->szr_instructions->Add($self->lbl_instructions, 0, 0, 0);
        $self->szr_html->Add($self->htm_window, 0, 0, 0);

        $self->szr_main->Add($self->szr_instructions, 0, 0, 0);
        $self->szr_main->Add($self->szr_html, 0, 0, 0);

        unless( $self->load_html_file('index.html') ) {
            ### Produces an ugly window flash, but since this is something that 
            ### really should never happen, I'm not too concerned about 
            ### momentary ugliness.
            $self->Destroy;
            return;
        }

        $self->SetSizer($self->szr_main);
        $self->Show(1);
        return $self;
    };
    sub _build_fs_html {#{{{
        my $self = shift;
        my $v    = Wx::FileSystem->new();
        $v->ChangePathTo($self->app->bb->root_dir . '/doc/html', 1);
        return $v;
    }#}}}
    sub _build_htm_window {#{{{
        my $self = shift;

        my $v = Wx::HtmlWindow->new(
            $self, -1, 
            wxDefaultPosition, 
            Wx::Size->new(500, 500),
            wxHW_SCROLLBAR_AUTO
        );
        return $v;
    }#}}}
    sub _build_lbl_instructions {#{{{
        my $self = shift;
        my $text = 'Instructions go here';
        my $v = Wx::StaticText->new(
            $self, -1, 
            $text,
            wxDefaultPosition, 
            Wx::Size->new(500, 25)
        );
        return $v;
    }#}}}
    sub _build_szr_main {#{{{
        my $self = shift;
        my $v = $self->build_sizer($self, wxVERTICAL, 'Main Sizer');
        return $v;
    }#}}}
    sub _build_szr_html {#{{{
        my $self = shift;
        my $v = $self->build_sizer($self, wxVERTICAL, 'HTML Window');
        return $v;
    }#}}}
    sub _build_szr_instructions {#{{{
        my $self = shift;
        my $v = $self->build_sizer($self, wxVERTICAL, 'Instructions');
        return $v;
    }#}}}
    sub _set_events {#{{{
        my $self = shift;
        EVT_CLOSE(  $self,  sub{$self->OnClose(@_)}     );
        return 1;
    }#}}}

    sub load_html_file {#{{{
        my $self = shift;
        my $file = shift || return;

        ### GetPath does end with a /
        my $fqfn = $self->fs_html->GetPath() . $file;
        unless(-e $fqfn) {
            $self->app->poperr("$fqfn: No such file or directory");
            return;
        }

        $self->htm_window->LoadFile( $self->fs_html->GetPath() . $file );
        return 1;
    }#}}}

    sub OnClose {#{{{
        my $self    = shift;
        my $dialog  = shift;
        my $event   = shift;
        $self->Destroy;
        $event->Skip();
        return 1;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;
