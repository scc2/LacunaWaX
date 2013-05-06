


###
### EnumerateWindows.pm
###
### This was meant to test out the wxTopLevelWindows list, but that variable 
### appears not to be available to wxperl.
###
### So this isn't really doing anything.
###
### However, it's still a good skeleton for creating new Test dialogs.
### 


package LacunaWaX::Dialog::Test {
    use v5.14;
    use Data::Dumper;
    use Moose;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_BUTTON EVT_CLOSE EVT_SIZE);
    with 'LacunaWaX::Roles::GuiElement';

    use MooseX::NonMoose::InsideOut;
    extends 'Wx::Dialog';

    has 'sizer_debug' => (is => 'rw', isa => 'Int',  lazy => 1, default => 1);

    has 'title' => (is => 'rw', isa => 'Str', lazy => 1, default => 'Enumerate Windows');

    has 'btn_show'          => (is => 'rw', isa => 'Wx::Button',        lazy_build => 1);
    has 'lbl_instructions'  => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);

    has 'szr_main'          => (is => 'rw', isa => 'Wx::Sizer', lazy_build => 1, documentation => q{vertical});
    has 'szr_instructions'  => (is => 'rw', isa => 'Wx::Sizer', lazy_build => 1, documentation => q{vertical});

    sub FOREIGNBUILDARGS {#{{{
        my $self = shift;
        my %args = @_;

        ### Although this block correctly spits the title attribute's value to 
        ### STDOUT...
            #my $title = $self->title;
            #say "--$title--";
            #return;
        ###
        ### $self is really not available yet when FOREIGNBUILDARGS gets called.  
        ### Attempting to use that $title value in the array we're returning 
        ### results in a screen full of uninitialized warnings.
        ###
        ### So just use an empty string for the title argument below, and then 
        ### remember to call SetTitle in BUILD, which happens /after/ the object 
        ### has actually been created.

        return (
            undef, -1, 
            q{},        # the title
            wxDefaultPosition,
            wxDefaultSize,
            wxRESIZE_BORDER|wxDEFAULT_DIALOG_STYLE
        );
    }#}}}
    sub BUILD {
        my($self, @params) = @_;

        $self->SetTitle( $self->title );

        $self->szr_instructions->Add($self->lbl_instructions, 0, 0, 0);

        $self->szr_main->Add($self->szr_instructions, 0, 0, 0);
        $self->szr_main->Add($self->btn_show, 0, 0, 0);

        $self->SetSizer($self->szr_main);

        return $self;
    };
    sub _build_btn_show {#{{{
        my $self = shift;
        my $v = Wx::Button->new(
            $self, -1,
            "Show windows"
        );
        $v->SetFont( $self->app->wxbb->resolve(service => '/Fonts/para_text_1') );
        return $v;
    }#}}}
    sub _build_lbl_instructions {#{{{
        my $self = shift;
        my $v = Wx::StaticText->new(
            $self, -1, 
            "Here are some instructions",
            wxDefaultPosition, 
            Wx::Size->new(300, 25)
        );
        return $v;
    }#}}}
    sub _build_szr_main {#{{{
        my $self = shift;
        my $v = $self->build_sizer($self, wxVERTICAL, 'Main Sizer');
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
        EVT_BUTTON( $self,  $self->btn_show->GetId,    sub{$self->OnShowButton(@_)} );
    }#}}}

    sub OnClose {#{{{
        my $self    = shift;
        my $dialog  = shift;
        my $event   = shift;
        $self->Destroy;
        $event->Skip();
    }#}}}
    sub OnShowButton {#{{{
        my $self    = shift;
        my $dialog  = shift;
        my $event   = shift;
say "Show button";

    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;
