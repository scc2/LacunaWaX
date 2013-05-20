
package LacunaWaX::Dialog::About {
    use Moose;
    use Try::Tiny;
    with 'LacunaWaX::Roles::GuiElement';

    has 'info'  => (is => 'rw', isa => 'Wx::AboutDialogInfo');

    sub BUILD {
        my $self = shift;

        $self->info( Wx::AboutDialogInfo->new() );
        $self->info->SetName(
            $self->app->bb->resolve(service => '/Strings/app_name')
        );
        $self->info->SetVersion(
            "$LacunaWaX::VERSION - wxPerl $Wx::VERSION"
        );
        $self->info->SetCopyright(
            'Copyright 2012, 2013 Jonathan D. Barton'
        );
        $self->info->SetDescription(
            'A GUI for helping manage The Lacuna Expanse.'
        );
        ### Full license in ROOT/LICENSE
        $self->info->SetLicense(
            'This is free software; you can redistribute it and/or modify it under
            the same terms as the Perl 5 programming language system itself.'
        );
        for my $d( @{$self->app->bb->resolve(service => '/Strings/developers')} ) {
            $self->info->AddDeveloper($d);
        }

        return $self;
    }
    sub _set_events { }
    sub show {#{{{
        my $self = shift;
        Wx::AboutBox($self->info);
        return;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

1;
