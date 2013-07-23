
package LacunaWaX::MainFrame::MenuBar::File::Connect {
    use v5.14;
    use Moose;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_MENU);
    with 'LacunaWaX::Roles::GuiElement';

    use MooseX::NonMoose::InsideOut;
    extends 'Wx::Menu';

    has 'connections' => (is => 'rw', isa => 'HashRef[Wx::MenuItem]', lazy => 1, default => sub{ {} },
        documentation => q{
            Keys are the IDs from the Servers table.
            Values are MenuItem objects.
        }
    );

    sub FOREIGNBUILDARGS {#{{{
        return; # Wx::Menu->new() takes no arguments
    }#}}}
    sub BUILD {
        my $self    = shift;
        my $schema  = $self->get_main_schema;

        ### Build one submenu per server.  Immediately gray out servers for 
        ### which the user has not yet set username/password.
        for my $srvr_id( sort{$a<=>$b}$self->server_ids ) {
            my $srvr_rec = $self->server_record_by_id($srvr_id);

            ### OnConnect is relying on the MenuItem name being exactly 
            ### $srvr_rec->name - don't change that.
            my $menu_item = $self->Append( -1, $srvr_rec->name, "Connect to " . $srvr_rec->url );
            $self->connections->{$srvr_rec->id} = $menu_item;

            if(
                my $prefs = $schema->resultset('ServerAccounts')->search({ 
                    server_id           => $srvr_id,
                    default_for_server  => 1,
                })->single
            ) {
                unless( $prefs->username and $prefs->password ) { $self->Enable($menu_item->GetId, 0); }
            }
            else { $self->Enable($menu_item->GetId, 0); }
        }

        return $self;
    }
    sub _set_events {#{{{
        my $self = shift;
        foreach my $server_id( keys %{ $self->connections } ) {
            my $menu_item = $self->connections->{$server_id};
            EVT_MENU( $self->parent, $menu_item->GetId, sub{$self->get_main_frame->OnGameServerConnect($server_id)} );
        }
        return 1;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

1;
