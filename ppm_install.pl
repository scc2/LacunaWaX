
use v5.14;
use autodie;
use version;
use warnings;

my $mods_file = 'cpanfile';


=pod

Parses $mods_file.  Checks that each listed module is installed and at the 
required version (at least).  Installs the module if it is not installed or a 
high enough version.

The idea here is that Carton and cpanfile are not working for me on Windows, 
but I'm hoping they do work for me on Ubuntu.  If they do, this will allow me 
to maintain a single prereqs list and have it work on both OSs.


***
This is still very much experimental.  Don't expect it to work properly, or at
all, yet.
***


These require arguments sent to their use statements
        Package::DeclarationManager
        Sub::Exporter::Progressive
...so the simple 'use $mod' test used below will always fail for them.

The 'use ExtUtils::MakeMaker' spits out the
    Set up gcc environment - 3.4.5 (mingw-vista special r3)

=cut

open my $f, '<', $mods_file;
LINE:
while( my $line = <$f> ) {
    chomp $line;

    ### Fairly naive parse, but I control the input file so I'm calling it OK.
    $line =~ s/^\s+//;

    next if $line =~ /^(
        \#              # I've seen no docu that says this is a valid cpanfile comment, so may need to be removed.  I'm using it as a comment now as convenience.
        |on
        |feature
        |}
    )
    /xs;

    #next if $line =~ /^#/;      # I don't know if this is really a valid comment character in a cpanfile
    #next if $line =~ /^on/;
    #next if $line =~ /^feature/;
    #next if $line =~ /^}/;
    my( $cmd, $mod, $ver ) = split /\s+/, $line;
#say "-$cmd- -$mod- -$ver-"; next;
    for($mod,$ver) {
        $_ =~ s/[',;]//g;
    }

    next LINE if already_installed($mod, $ver) and verify_version($mod, $ver);

    say "Installing $mod version $ver";
    install($mod);

    unless( verify_version($mod, $ver) ) {
        say "$mod could not be installed to the required version $ver.";
    }

}
sub already_installed {#{{{
    my $mod         = shift;
    my $reqd_ver    = shift;

    eval("use $mod");
    if($@) {
#say "not installed";
        return 0;
    }
    else {
#say "installed";
        return 1;
    }
}#}}}
sub install {#{{{
    my $mod = shift;
    ### "-f" forces a reinstall.  Will upgrade to latest available version.  
    ### But will always reinstall, even if the currently-installed version is 
    ### identical to the "new" version.  So don't just run this without 
    ### checking version numbers elsewhere; it'll be a monumental waste of 
    ### time and bandwidth.
    system('ppm', 'install', '-f', $mod);
    return 1;
}#}}}
sub verify_version {#{{{
    my $mod         = shift;
    my $reqd_ver    = version->parse(shift);

    return ( cmp_vers( $mod, $reqd_ver ) >= 0 ) ? 1 : 0;
}#}}}
sub cmp_vers {#{{{
    my $mod         = shift;
    my $reqd_ver    = version->parse(shift);

    ### Yeah yeah varvarname mjd blah blah
    no strict 'refs';
    my $has_ver = version->parse(${$mod . '::VERSION'});
    use strict 'refs';

    return( $has_ver <=> $reqd_ver );
}#}}}

