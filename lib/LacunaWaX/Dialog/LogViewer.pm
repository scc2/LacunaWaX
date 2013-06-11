
package LacunaWaX::Dialog::LogViewer {
    use v5.14;
    use Moose;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_BUTTON EVT_CLOSE EVT_RADIOBOX EVT_SIZE);
    use LacunaWaX::Dialog::NonScrolled;
    extends 'LacunaWaX::Dialog::NonScrolled';

    has 'sizer_debug' => (is => 'rw', isa => 'Int',  lazy => 1, default => 0);

    has 'count' => (
        is      => 'ro',
        isa     => 'Int',
        default => 0,
        traits  => ['Number'],
        handles => {
            set_count => 'set',
        },
        documentation => q{
            The total number of log entries that can be shown.  Changes 
            per-component, so each time a new radio button is chosen.
        }
    );
    has 'results' => (
        is      => 'rw',
        isa     => 'DBIx::Class::ResultSet',
        documentation => q{
            All records for the currently-selected component.  Changes when the 
            user selects a new radio button.
        }
    );
    has 'page' => (
        is      => 'ro',
        isa     => 'Int',
        default => 1,
        traits  => ['Number'],
        handles => {
            set_page  => 'set',
            prev_page => 'sub',
            next_page => 'add',
        },
        documentation => q{
            The page we're currently on.  Resets to 1 each time the user choses 
            a new component radio button.
        }
    );
    has 'recs_per_page' => (
        is      => 'ro',
        isa     => 'Int',
        default => 100,
    );

    has 'component_labels'  => (is => 'rw', isa => 'ArrayRef',      lazy_build => 1);
    has 'component_values'  => (is => 'rw', isa => 'HashRef',       lazy_build => 1);
    has 'list_log'          => (is => 'rw', isa => 'Wx::ListCtrl',  lazy_build => 1);
    has 'rdo_component'     => (is => 'rw', isa => 'Wx::RadioBox',  lazy_build => 1);
    has 'szr_log'           => (is => 'rw', isa => 'Wx::Sizer', lazy_build => 1, documentation => 'vertical' );

    ### Pagination components
    has 'btn_next'          => (is => 'rw', isa => 'Wx::Button',        lazy_build => 1);
    has 'btn_prev'          => (is => 'rw', isa => 'Wx::Button',        lazy_build => 1);
    has 'szr_pagination'    => (is => 'rw', isa => 'Wx::Sizer', lazy_build => 1, documentation => 'horizontal' );
    has 'lbl_page'          => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);

    sub BUILD {
        my $self = shift;

        $self->SetTitle( $self->title );
        $self->SetSize( $self->size );

        $self->szr_log->Add($self->list_log, 2, 0, 0);
        $self->add_pagination( $self->szr_log );
    
        $self->main_sizer->AddSpacer(5);
        $self->main_sizer->Add($self->rdo_component, 0, 0, 0);
        $self->main_sizer->Add($self->szr_log, 0, 0, 0);

        $self->init_screen();
        return $self;
    }
    sub _build_btn_next {#{{{
        my $self = shift;
        my $v = Wx::Button->new($self, -1, 
            "Next",
            wxDefaultPosition, 
            Wx::Size->new(50, 30)
        );
        $v->SetFont( $self->get_font('/para_text_1') );
        my $enabled = ($self->count > $self->recs_per_page) ? 1 : 0;
        $v->Enable($enabled);
        return $v;
    }#}}}
    sub _build_btn_prev {#{{{
        my $self = shift;
        my $v = Wx::Button->new($self, -1, 
            "Prev",
            wxDefaultPosition, 
            Wx::Size->new(50, 30)
        );
        $v->SetFont( $self->get_font('/para_text_1') );
        $v->Enable(0); # Always start the Prev button disabled.
        return $v;
    }#}}}
    sub _build_component_labels {#{{{
        my $self = shift;
        ### If you update a label, also update the values below.
        my $v = [ 'Clear', 'Archmin', 'Autovote', 'Lottery', 'Spies' ];
        return $v;
    }#}}}
    sub _build_component_values {#{{{
        my $self = shift;
        ### If you update a value, also update the labels above.
        my $v = {
            Clear           => 'This does not appear in the table so this will clear the list',
            Archmin         => 'Archmin',
            Autovote        => 'Autovote',
            Lottery         => 'Lottery',
            Spies           => 'Spies',
        };
        return $v;
    }#}}}
    sub _build_lbl_page {#{{{
        my $self = shift;
        my $cnt  = shift || 0;;

        my $v = Wx::StaticText->new( $self, -1, 
            q{Page 1},
            wxDefaultPosition, 
            Wx::Size->new(-1, 20)
        );
        $v->SetFont( $self->get_font('/para_text_2') );
        return $v;
    }#}}}
    sub _build_list_log {#{{{
        my $self = shift;

        ### When this ListCtrl gets built, the dialog isn't fully formed yet, so 
        ### we have to use the hard-coded $self->size rather than 
        ### $self->GetClientSize.
        my $width  = $self->size->width - 20;
        my $height = $self->size->height 
                     - $self->rdo_component->GetSize->height 
                     - $self->btn_next->GetSize->height
                     - 50;

        my $v = Wx::ListCtrl->new(
            $self, -1, 
            wxDefaultPosition, 
            Wx::Size->new($width, $height),
            wxLC_REPORT
            |wxSUNKEN_BORDER
            |wxLC_SINGLE_SEL
        );
        $v->InsertColumn(0, 'Date');
        $v->InsertColumn(1, 'Run');
        $v->InsertColumn(2, 'Component');
        $v->InsertColumn(3, 'Message');
        $v->SetColumnWidth(0,wxLIST_AUTOSIZE_USEHEADER);
        $v->SetColumnWidth(1,wxLIST_AUTOSIZE_USEHEADER);
        $v->SetColumnWidth(2,wxLIST_AUTOSIZE_USEHEADER);
        $v->SetColumnWidth(3,wxLIST_AUTOSIZE_USEHEADER);
        $v->Arrange(wxLIST_ALIGN_TOP);
        $self->yield;
        return $v;

    }#}}}
    sub _build_rdo_component {#{{{
        my $self = shift;
        my $v = Wx::RadioBox->new(
            $self, -1, 
            "Component", 
            wxDefaultPosition, 
            Wx::Size->new(390,50), 
            $self->component_labels,
            1, 
            wxRA_SPECIFY_ROWS
        );
        $v->SetSize( $v->GetBestSize );
        return $v;
    }#}}}
    sub _build_size {#{{{
        my $self = shift;
        my $s = Wx::Size->new(650, 700);
        return $s;
    }#}}}
    sub _build_szr_log {#{{{
        my $self = shift;

        ### szr_log contains the ListCtrl and also the Pagination sizer.
        ### 
        ### The original idea was that when the user resizes the window, the 
        ### ListCtrl should resize with it, which should also resize its sizer 
        ### and push the Pagination sizer down so everything would Look Right.
        ###
        ### What's happening, though, is that the ListCtrl is being resized, 
        ### but when that happens it's not increasing the sizes of the sizers, 
        ### so the pagination controls end up floating in the middle of the 
        ### ListCtrl.
        ###
        ### Since we do have pagination, and the ListCtrl automatically gets a 
        ### scrollbar when needed, resizing that ListCtrl isn't really 
        ### necessary, so I'm currently just skipping it.  But it would be 
        ### nice to figure out why things aren't working the way I want.

        return $self->build_sizer($self, wxVERTICAL, 'Log List');
    }#}}}
    sub _build_szr_pagination {#{{{
        my $self = shift;
        return $self->build_sizer($self, wxHORIZONTAL, 'Pagination');
    }#}}}
    sub _build_title {#{{{
        my $self = shift;
        return 'Log Viewer';
    }#}}}
    sub _set_events {#{{{
        my $self = shift;
        EVT_BUTTON(     $self, $self->btn_prev->GetId,      sub{$self->OnPrev(@_)}          );
        EVT_BUTTON(     $self, $self->btn_next->GetId,      sub{$self->OnNext(@_)}          );
        EVT_CLOSE(      $self,                              sub{$self->OnClose(@_)}         );
        EVT_RADIOBOX(   $self, $self->rdo_component->GetId, sub{$self->OnRadio(@_)}         );
        EVT_SIZE(       $self,                              sub{$self->OnResize(@_)}        );
        return 1;
    }#}}}

    sub add_pagination {#{{{
        my $self = shift;
        my $szr  = shift;

        my $width = $self->list_log->GetSize->width;
        $width -= $self->btn_prev->GetSize->width;
        $width -= $self->btn_next->GetSize->width;
        $width -= $self->lbl_page->GetSize->width;
        $width /= 2;
        $self->szr_pagination->Add($self->btn_prev, 0, 0, 0);
        $self->szr_pagination->AddSpacer($width);
        $self->szr_pagination->Add($self->lbl_page, 0, 0, 0);
        $self->szr_pagination->AddSpacer($width);
        $self->szr_pagination->Add($self->btn_next, 0, 0, 0);

        $szr->Add($self->szr_pagination, 1, 0, 0);
        return $szr;
    }#}}}
    sub list_width {#{{{
        my $self = shift;
        return $self->GetClientSize->width - 10;
    }#}}}
    sub list_height {#{{{
        my $self = shift;
        return $self->GetClientSize->height 
               - $self->rdo_component->GetSize->height 
               - $self->btn_next->GetSize->height
               - 10;
    }#}}}
    sub show_page {#{{{
        my $self = shift;

        $self->list_log->DeleteAllItems;

        my $offset  = $self->page - 1;
        my $start   = $self->recs_per_page * $offset;
        my $end     = $start + $self->recs_per_page - 1;
        my $slice   = $self->results->slice($start, $end);

        my $row = 0;
        while(my $r = $slice->next) {
            $self->list_log->InsertStringItem($row, $r->datetime->dmy . q{ } . $r->datetime->hms);
            $self->list_log->SetItem($row, 1, $r->run);
            $self->list_log->SetItem($row, 2, $r->component);
            $self->list_log->SetItem($row, 3, $r->message);
            $row++;
            $self->yield;
        }
        $self->list_log->SetColumnWidth(0, wxLIST_AUTOSIZE);
        $self->list_log->SetColumnWidth(1, wxLIST_AUTOSIZE_USEHEADER);
        $self->list_log->SetColumnWidth(2, wxLIST_AUTOSIZE_USEHEADER);
        $self->list_log->SetColumnWidth(3, wxLIST_AUTOSIZE);

        $self->update_pagination();
    }#}}}
    sub update_pagination {#{{{
        my $self = shift;
        my $cnt  = shift || 0;

        my $next_enabled = ($self->page * $self->recs_per_page <  $self->count) ? 1 : 0;
        $self->btn_next->Enable($next_enabled);

        my $prev_enabled = ($self->page > 1) ? 1 : 0;
        $self->btn_prev->Enable($prev_enabled);

        my $text = "Page " . $self->page;
        $self->lbl_page->SetLabel($text);
    }#}}}

    sub OnClose {#{{{
        my($self, $dialog, $event) = @_;
        $self->Destroy;
        $event->Skip();
        return 1;
    }#}}}
    sub OnNext {#{{{
        my $self    = shift;
        my $panel   = shift;
        my $event   = shift;

        $self->next_page(1);
        $self->show_page;

        return 1;
    }#}}}
    sub OnRadio {#{{{
        my $self    = shift;
        my $dialog  = shift;    # Wx::Dialog
        my $event   = shift;    # Wx::CommandEvent

        my $cmp_label  = $self->rdo_component->GetString( $self->rdo_component->GetSelection );
        my $cmp_search = $self->component_values->{$cmp_label} || q{};

        my $schema = $self->get_log_schema;
        my $rs = $schema->resultset('Logs')->search(
            [
                {component => $cmp_search},
                {component => 'Schedule'},
            ],
            {
                order_by => [
                    { -desc => ['run'] },
                    ### 'id' instead of 'datetime', so consecutive records with 
                    ### the same timestamp will show up in the correct order.
                    { -asc  => ['id'] },
                ],
                ### Max (MorL) of 24 planets, 90 spies per planet, == max 2160 
                ### spies trained during Schedule_train_spies, so that many 
                ### useful log entries are possible.
                ### CHECK
                ### However, displaying that many records is slow and ugly.  I 
                ### should have some pagination in here instead of trying to 
                ### show everything on one screen.
#                rows => $self->recs_per_page,
            }
        );

        $self->results( $rs );
        $self->set_page(1);
        $self->set_count( $rs->count );
        $self->show_page();

        return 1;
    }#}}}
    sub OnResize {#{{{
        my $self    = shift;
        my $dialog  = shift;
        my $event   = shift;    # Wx::SizeEvent

        #$self->list_log->SetSize( $self->list_width, -1 );
        #$self->resize_pagination();
        ##$self->Layout;
        return 1;
    }#}}}
    sub OnPrev {#{{{
        my $self    = shift;
        my $panel   = shift;
        my $event   = shift;

        $self->prev_page(1);
        $self->show_page;

        return 1;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;
