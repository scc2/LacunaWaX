#!/usr/bin/env perl

use v5.14;
use FindBin;
use lib $FindBin::Bin . "/../lib";
say $FindBin::Bin . "/../lib";
use LacunaWaX::Model::Container;
use LacunaWaX::Model::Schema;
use version;


my $root_dir    = "$FindBin::Bin/..";
my $db_file     = $root_dir . '/user/lacuna_app.sqlite';
my $db_log_file = $root_dir . '/user/lacuna_log.sqlite';

=pod

Careful about adding text below.  The output is arranged so the "Hit 
<ENTER>..." prompts will display on the last line of a CMD window; 
adding text will likely move those prompts down.

So if you do add text, be sure to run this IN A CMD WINDOW NOT IN YOUR 
RESIZED Console, DUMMY to make sure that everything shows up where it 
should.

=cut


clear_screen();
say <<EOT;



    If you started LacunaWaX, and can see its icon running in your 
    task bar, but can't find the actual LacunaWaX window, this will 
    reset its position for you.



    First, be sure to close down LacunaWaX if it's running - 
    right-click on its button in the task bar and chose "Close".

    Next, start the Windows Task Manager - if you see any instances of 
    LacunaWaX.exe running, end them.



    You must be sure that LacunaWaX is not running before we continue.





EOT

print "Hit <ENTER> when you're sure that LacunaWaX is not running: ";
my $h = <STDIN>;




my $c = LacunaWaX::Model::Container->new(
    name        => 'my container',
    root_dir    => $root_dir,
    db_file     => $db_file,
    db_log_file => $db_log_file,
);
my $schema = $c->resolve( service => '/Database/schema' );

if( my $x = $schema->resultset('AppPrefsKeystore')->search({ name => 'MainWindowX' })->single ) {
    $x->delete;
}
if( my $y = $schema->resultset('AppPrefsKeystore')->search({ name => 'MainWindowY' })->single ) {
    $y->delete;
}

clear_screen();
say <<EOT;

    Reset complete!

    You should be all set.  The next time you start LacunaWaX, its 
    window should start out in the center of your screen.


















EOT
print "Hit <ENTER> to dismiss this window: ";
$h = <STDIN>;

sub clear_screen {#{{{
    given($^O) {
        when('MSWin32') { system 'cls'; }
        default         { system 'clear'; }
    }
}#}}}



