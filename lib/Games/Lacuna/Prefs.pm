use 5.12.0;
package Games::Lacuna::Prefs;
use Carp qw(confess);
use Data::Dumper; $Data::Dumper::Indent = 1;
use Moose;
use MooseX::NonMoose;
use Moose::Util::TypeConstraints qw(enum);
extends qw( YAML::Any );

use Games::Lacuna::Prefs::Planet;



=pod



All the YAML stuff needs to go.  It's making this needlessly complicated.  All prefs should
be stored in and accessed from the freaking database.  The scheduled process can be run from
the same machine (ubuntu, via cron) as the database as long as we're using sqlite.  

Forcing myself to maintain this reliance on the yaml is killing me.



While working, guarantee_prefs_file contains "membersTEST" in its path structure.  That 
needs to end up as just "members" when done.



=cut





# $Id: Prefs.pm 14 2012-12-10 23:19:27Z jon $
# $URL: https://tmtowtdi.gotdns.com:15000/svn/LacunaWaX/trunk/lib/Games/Lacuna/Prefs.pm $

has 'yaml_file' => ( isa => 'Str', is => 'rw', predicate => 'has_yaml_file' );
has 'prefs'     => ( isa => 'HashRef', is => 'rw', default => sub {{}} );
has 'planets'   => ( isa => 'HashRef[Games::Lacuna::Prefs::Planet]', is => 'rw', default => sub{{}} );
has 'spies'     => ( isa => 'HashRef[Games::Lacuna::Prefs::Spy]', is => 'rw', default => sub{{}} );

### POD {#{{{

=head1 NAME

Games::Lacuna::Prefs - Empire preferences for The Lacuna Expanse; mainly related 
to common scheduled tasks.

=head1 SYNOPSIS

 my $prefs = Games::Lacuna::Prefs->new();

 # Creates the directory structure from the dropbox root to and including the 
 # yaml file if it doesn't already exist, loads that file into $prefs if it does
 # already exist.
 $prefs->guarantee_prefs_file(
    '/local/path/to/dropbox/root',
    'my_empire_name'
 )

 say $prefs->server_uri;
 $prefs->server_uri('http://www.example.com');
 say $prefs->server_uri;    # http://www.example.com

 my $old_uri = $prefs->clear_server_uri();
 say $old_uri;              # http://www.example.com
 say $prefs->server_uri;    # undef

Same deal with planet-specific prefs:

 say $prefs->planets->{'my_planet'}->shipyard;
 $prefs->planets->{'my_planet'}->shipyard('flurble');
 say $prefs->planets->{'my_planet'}->shipyard;          # flurble

Write changes out to the current ->yaml_file:

 $prefs->DumpFile();

Or write to some other file:

 $prefs->DumpFile('some_other_file.yml');

Or write to an existing yaml file, any settings in the file OVERRIDE our 
current $prefs settings:

 $prefs->yaml_file('some_existing_yaml_file.yml');
 $prefs->DumpFile();

=cut

### }#}}}

sub DumpFile {#{{{
    my $self = shift;
    my $target = shift || $self->yaml_file;

=pod

Dumps the current preferences out to a file.  The file dumped to can be passed 
as an arg or, failing an arg, the prefs will be dumped to $self->yaml_file.  

Dies if $self->yaml_file has not been set and no arg is passed.

 my $p = Games::Lacuna::Prefs->new({
    yaml_file => 'some_file.yml',
 });
 ...
 # Dumps current preferences back out to 'some_file.yml'
 $p->DumpFile();

 my $p = Games::Lacuna::Prefs->new();
 ...
 # Dumps current preferences out to 'some_other_file.yml'
 $p->DumpFile( 'some_other_file.yml' );

=cut

    unless( $target and -f $target ) {
        die "DumpFile failed: no target file provided.";
    }

    while( my($pname, $pobj) = each %{$self->planets} ) {
        $self->prefs->{'planet'}{$pname} = $pobj;
    }

    return YAML::Any::DumpFile($target, $self->prefs);
}#}}}
sub ensure_planet {#{{{
    my $self  = shift;
    my $pname = shift;

=pod

Before you go adding prefs to a planet, you should be sure that planet's prefs 
object exists.

 $p->planets->{'new_planet'}->trash_run_at(0.8);

BOOOM! There wasn't already a 'new_planet' key in the $p->planets hashref, so 
we end up with undefined death.

 $p->ensure_planet('new_planet');
 $p->planets->{'new_planet'}->trash_run_at(0.8);

Joy!

=cut

    unless( defined $self->planets->{$pname} ) {
        $self->planets->{$pname} = Games::Lacuna::Prefs::Planet->new();
    }
    return $self->planets->{$pname};
}#}}}
sub ensure_spy {#{{{
    my $self  = shift;
    my $spy_id = shift;

=pod

Before you go adding prefs to a spy, you should be sure that spy's prefs 
object exists.

 $p->spies->{'spy_id'}->task('train_int');

BOOOM! There wasn't already a record for 'spy_id' in the $p->spies hashref, 
so we end up with undefined death.

 $p->ensure_spy('spy_id');
 $p->spies->{'spy_id'}->task('train_int');

Joy!

=cut

    unless( defined $self->spies->{$spy_id} ) {
        $self->spies->{$spy_id} = Games::Lacuna::Prefs::Spy->new();
    }
    return $self->spies->{$spy_id};
}#}}}
sub guarantee_prefs_file {#{{{
    my $self = shift;
    my $dropbox_path = shift;
    my $empire_name = shift;

=pod

Given the current host-specific path to the Dropbox folder and an empire name, 
this guarantees that a prefs.yml file exists in the correct location and is 
a writable, valid YAML file.  The full path to that file is set as the value 
for this object's yaml_file attribute.

If the prefs file did already exist, this will load that file into $self->prefs.

This is most likely going to go away eventually; I much prefer the idea of 
maintaining all of the prefs in the database instead of in this silly YAML file.

Note that an empty file I<is> considered 'valid YAML'.

As long as the Dropbox path passed in exists, the rest of the following 
directory structure does not need to; it will be created for you.

"The correct location" is:

 <LOCAL_DROPBOX_PATH>/Lacuna/SMA/members/<EMPIRE_NAME>/prefs.yml

The full path to the file is returned.

 my $y = $prefs->guarantee_prefs_file(
  'C:/Documents and Settings/Jon/My Documents/My Dropbox',
  'tmtowtdi',
 );

 # The output of these is identical:
 say $prefs->yaml_file;
 say $y;
 # C:/Documents and Settings/Jon/My Documents/My Dropbox/Lacuna/SMA/members/tmtowtdi/prefs.yml

 # Dumps the current prefs out to the file mentioned above.
 $prefs->DumpFile();

=cut

    $dropbox_path =~ s{[/\\]$}{};
    my @dropbox_path_pieces = qw(Lacuna SMA membersTEST);

    unless(-e -d -x "$dropbox_path") {
        confess "Invalid dropbox path: $dropbox_path";
    }
    unless( $empire_name ) {
        die "No empire name sent.";
    }

    foreach my $p( @dropbox_path_pieces ) {
        $dropbox_path .= '/' . $p;
        unless(-e $dropbox_path) {
            mkdir $dropbox_path or die "Unable to create $dropbox_path: $!";
        }
        unless(-e -d -x $dropbox_path) {
            die "Invalid dropbox path: $dropbox_path";
        }
    }

    my $empire_path = "$dropbox_path/$empire_name";
    if(-e $empire_path) {
        unless(-d -x -w $empire_path) {
            die "$empire_path: exists but is not a directory or bad permissions";
        }
    }
    else {
        mkdir $empire_path or die "Unable to create directory $empire_path: $!";
    }

    my $yaml_path = "$empire_path/prefs.yml";
    if(-e $yaml_path) {
        unless(-f -w $yaml_path) {
            die "$yaml_path exists but is not a life or bad permissions";
        }
    }
    else {
        open my $y, '>', $yaml_path or die "Failed to open prefs.yml: $!";
        close $y;
    }

    ### This passes fine on an empty file.
    eval{ YAML::Any::LoadFile($yaml_path) };
    if( $@ ) {
        die "$yaml_path exists but is not a valid YAML file.";
    }

    $self->yaml_file($yaml_path);
    return $yaml_path;
}#}}}

BEGIN {#{{{
    my $revision = '$Rev: 14 $';
    ### Non-destructive substitution requires 5.14.0; hold off on forcing that 
    ### for now.
    $Games::Lacuna::Prefs::VERSION = '0.1.' . join '', $revision =~ m/(\d+)/;
}#}}}
sub BUILD {#{{{
    my( $self, $params ) = @_;

    if( $self->has_yaml_file ) {
        $self->prefs( YAML::Any::LoadFile($params->{'yaml_file'}) );
    }

    ### I'm not using Moose's regular accessors because I want to maintain 
    ### prefs as a hashref so I can use YAML's LoadFile and DumpFile.
    my $meta = __PACKAGE__->meta;
    foreach my $top_level_key( qw(
                        server_uri session_persistent empire_name empire_password 
                        api_key time_zone log_level glyph_home dry_run
                    ) ) {
        next if $self->can($top_level_key);
        $meta->add_method(
            $top_level_key => sub {
                my($self, $val) = @_;
                return $self->_top_level($top_level_key, $val);
            }
        );
        $meta->add_method(
            "clear_$top_level_key" => sub {
                my($self, $val) = @_;
                return $self->_top_level($top_level_key, {delete => 1});
            }
        );
    }

    ### This assumes we've read prefs from the yaml file first.  Needs to go 
    ### away when the yaml file does.
    while( my($name, $hr) = each %{$self->prefs->{'planet'}} ) {
        my $ppref = Games::Lacuna::Prefs::Planet->new( $hr );
        ### TBD need to deal with res_push; we're currently totally ignoring it.
        $self->planets->{$name} = $ppref;
    }

    $meta->make_immutable;
}#}}}
sub _top_level {#{{{
    my $self = shift;
    my $key = shift;
    my $val = shift;

    if( ref $val eq 'HASH' and $val->{'delete'} ) {
        ### Allows us to send {delete => 1} instead of a string in $val so we 
        ### know for sure the caller wants the pref deleted.  User never needs 
        ### to do that; it's done from ->clear_PREFNAME().
        return delete $self->prefs->{$key};
    }
    if( defined $val and $val ne '' ) {
        return $self->prefs->{$key} = $val;
    }
    return $self->prefs->{$key};
}#}}}
after 'yaml_file' => sub {#{{{
    my $self      = shift;
    my $file_path = shift;
    my $dont_load = shift;

    return unless $file_path;
    return if $dont_load;

    ### purposely using the hash ref here rather than the accessor to avoid 
    ### recursion.
    my $temp = YAML::Any::LoadFile($file_path);

=pod

After setting the path to the yaml file by calling either the ->yaml_file 
accessor or ->guarantee_prefs_file, this loads that file's settings into
$self->prefs.

 # empty prefs
 my $p = Games::Lacuna::Prefs->new();

 $p->yaml_file('/path/to/existing/yaml/file');

 # Returns the glyph_home setting from '/path/to/existing/yaml/file', provided
 # glyph_home was set in that file.
 say $p->glyph_home;

Caution: calling ->yaml_file() or ->guarantee_prefs_file() on a $prefs object 
that you've already been working on will overwrite any of your $prefs attributes 
with any values already in the file.  You can avoid this by passing a true value 
(for "don't load") to ->yaml_file after the file path.

# existing.yml #####################################
---
glyph_home: existing_glyph_home

####################################################

 
 $p->glyph_home('foo');
 $p->yaml_file('existing.yml');
 say $p->glyph_home();  # 'existing_glyph_home'

...however...

 $p->glyph_home('foo');
 $p->yaml_file('existing.yml', 1);  <-- true value for "don't load"
 say $p->glyph_home();  # 'foo'

=cut

    while(my($n,$v) = each %$temp) {
        if( $self->can($n) ) {
            $self->$n($v);
        }
    }
    while( my($name, $thingy) = each %{$temp->{'planet'}} ) {
        my $ppref;
        if( ref $thingy eq 'HASH') {
            ### If the prefs file was written by hand it may be a hashref...
            $ppref = Games::Lacuna::Prefs::Planet->new( $thingy );
        }
        elsif( ref $thingy eq 'Games::Lacuna::Prefs::Planet' ) {
            ### ...but if it was written programmatically it'll likely already 
            ### be an object.
            $ppref = $thingy;
        }
        ### TBD need to deal with res_push; we're currently totally ignoring it.
        $self->planets->{$name} = $ppref;
    }
};#}}}

1;

