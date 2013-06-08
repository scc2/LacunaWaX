
package LacunaWaX::Dialog::LogViewer {
    use v5.14;
    use Moose;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_CLOSE EVT_RADIOBOX EVT_SIZE);
    use LacunaWaX::Dialog::NonScrolled;
    extends 'LacunaWaX::Dialog::NonScrolled';

    has 'sizer_debug' => (is => 'rw', isa => 'Int',  lazy => 1, default => 0);

    has 'component_labels'  => (is => 'rw', isa => 'ArrayRef',      lazy_build => 1);
    has 'component_values'  => (is => 'rw', isa => 'HashRef',       lazy_build => 1);
    has 'list_log'          => (is => 'rw', isa => 'Wx::ListCtrl',  lazy_build => 1);
    has 'rdo_component'     => (is => 'rw', isa => 'Wx::RadioBox',  lazy_build => 1);

    sub BUILD {
        my $self = shift;

        $self->SetTitle( $self->title );
        $self->SetSize( $self->size );
    
        $self->main_sizer->AddSpacer(5);
        $self->main_sizer->Add($self->rdo_component, 0, 0, 0);
        $self->main_sizer->Add($self->list_log, 0, 0, 0);

        $self->init_screen();
        return $self;
    }
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
    sub _build_list_log {#{{{
        my $self = shift;

        ### When this ListCtrl gets built, the dialog isn't fully formed yet, so 
        ### we have to use the hard-coded $self->size rather than 
        ### $self->GetClientSize.
        my $width  = $self->size->width - 20;
        my $height = $self->size->height - $self->rdo_component->GetSize->height - 50;

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
    sub _build_size {#{{{
        my $self = shift;
        my $s = Wx::Size->new(650, 700);
        return $s;
    }#}}}
    sub _build_title {#{{{
        my $self = shift;
        return 'Log Viewer';
    }#}}}
    sub _set_events {#{{{
        my $self = shift;
        EVT_CLOSE(      $self,                              sub{$self->OnClose(@_)});
        EVT_RADIOBOX(   $self, $self->rdo_component->GetId, sub{$self->OnRadio(@_)});
        EVT_SIZE(       $self,                              sub{$self->OnResize(@_)} );
        return 1;
    }#}}}

    sub list_width {#{{{
        my $self = shift;
        return $self->GetClientSize->width - 10;
    }#}}}
    sub list_height {#{{{
        my $self = shift;
        return $self->GetClientSize->height - $self->rdo_component->GetSize->height - 10;
    }#}}}

    sub OnClose {#{{{
        my($self, $dialog, $event) = @_;
        $self->Destroy;
        $event->Skip();
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
                rows => 100,
            }
        );

        $self->list_log->DeleteAllItems;
        my $row = 0;
        while(my $r = $rs->next) {
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
        return 1;
    }#}}}
    sub OnResize {#{{{
        my $self    = shift;
        my $dialog  = shift;
        my $event   = shift;    # Wx::SizeEvent

        $self->list_log->SetSize( $self->list_width, $self->list_height );
        return 1;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;
