package Games::Lacuna::Webtools::Schema::Result::Login;
use 5.010;
use Crypt::Eksblowfish::Bcrypt qw(bcrypt);
use DateTime;
use DateTime::Format::ISO8601;
use DateTime::Format::MySQL;
use MIME::Base64;
use base 'DBIx::Class::Core';

use Dancer qw(:syntax);


__PACKAGE__->table('Logins');
__PACKAGE__->load_components(qw/FilterColumn/);
__PACKAGE__->add_columns( 
    id              => {data_type => 'integer', size => 32, is_auto_increment => 1, is_nullable => 0, extra => {unsigned => 1} },
    username        => {data_type => 'varchar', size => 64, is_nullable => 0},
    password        => {data_type => 'varchar', size => 60, is_nullable => 0},  # 60 is exact for a blowfish hash
    active          => {data_type => 'integer', size => 1,  is_nullable => 0, default_value => 0},
    admin_notes     => {data_type => 'text',                is_nullable => 0, default_value => q//},
    create_date     => {data_type => 'datetime', is_nullable => 1},
    last_login_date => {data_type => 'datetime', is_nullable => 1},
);
__PACKAGE__->set_primary_key( 'id' ); 
__PACKAGE__->add_unique_constraint( username => ['username'] ); 
__PACKAGE__->has_many(
    login_roles => 'Games::Lacuna::Webtools::Schema::Result::Login_Role', 
    { 'foreign.Logins_id' => 'self.id' }
);
__PACKAGE__->many_to_many( roles => 'login_roles', 'role' );
__PACKAGE__->has_one(
    game_prefs => 'Games::Lacuna::Webtools::Schema::Result::GamePrefs', 
    { 'foreign.Logins_id' => 'self.id' }
);
__PACKAGE__->has_many(
    planet_prefs => 'Games::Lacuna::Webtools::Schema::Result::PlanetPrefs', 
    { 'foreign.Logins_id' => 'self.id' }
);
__PACKAGE__->has_many(
    spy_prefs => 'Games::Lacuna::Webtools::Schema::Result::SpyPrefs', 
    { 'foreign.Logins_id' => 'self.id' }
);
__PACKAGE__->has_many(
    station_prefs => 'Games::Lacuna::Webtools::Schema::Result::StationPrefs', 
    { 'foreign.Logins_id' => 'self.id' }
);
__PACKAGE__->has_many(
    res_pushes => 'Games::Lacuna::Webtools::Schema::Result::ResPushes', 
    { 'foreign.Logins_id' => 'self.id' }
);
__PACKAGE__->has_many(
    messages_received => 'Games::Lacuna::Webtools::Schema::Result::Message', 
    { 'foreign.to_id' => 'self.id' }
);
__PACKAGE__->has_many(
    messages_unread => 'Games::Lacuna::Webtools::Schema::Result::Message', 
    { 'foreign.to_id' => 'self.id' },
    {
        where => { perused => 0 }
    }
);
__PACKAGE__->has_many(
    messages_sent => 'Games::Lacuna::Webtools::Schema::Result::Message', 
    { 'foreign.from_id' => 'self.id' }
);

__PACKAGE__->filter_column( password => {
    filter_to_storage => '_password_to_hash'
});
### Nothing in here is automatically updating either the create_date or the 
### last_login_date.  If you want to use them in your app, your app will have 
### to manage updating them.  But if you do choose to update them, the filters 
### are already set up.  
### Just sending   DateTime->now()   as the arg to create_date() is fine.
### These dates need to be recorded in GMT.  Alter them on display according 
### to the user's time_zone
__PACKAGE__->filter_column( create_date => {
    filter_to_storage   => '_datetime_to_column',
    filter_from_storage => '_column_to_datetime',
});
__PACKAGE__->filter_column( last_login_date => {
    filter_to_storage   => '_datetime_to_column',
    filter_from_storage => '_column_to_datetime',
});

sub authenz {#{{{
    my $self = shift;
    my $pw_cand = shift;

=pod

Returns true if the candidate password string matches the user's saved password
AND the user's record is currently marked as 'active'.

This is the method your webapp should use when attempting to log in a user.

 my $login = $schema->resultset('Login')->find({ username => 'jon' });
 my $pw_attempt = 'foo';

 if( $login->auth($pw_attempt) ) {
  ### user's password was correct and their record is active.  Let em log in.
 }
 else {
  ### Either the password entered by the user was wrong OR an administrator 
  ### marked their record as inactive.  Doesn't matter which, the user should 
  ### not be allowed to log in.
 }

The candidate string may either be a raw string, as from user input (as in the 
example above), or it may be an already-hashed password string as taken directly 
from the database.

=cut

    return 0 unless $self->active;
    return 1 if $self->is_password($pw_cand);
    return 0;
}#}}}
sub authorz {#{{{
    my $self  = shift;
    my $group = shift || q{};

=pod

Requires one argument, a group name.  Returns true if the current user is a 
member of that group.

If that one required argument is not passed, this will always return false.

 if( $user->authorz('admin') ) {
    ... user is logged in and is a member of the admin group.
 }

=cut

    return 0 unless $group;
    return 1 if $self->roles->find({ name => $group });
    return 0;
}#}}}
sub is_password {#{{{
    my $self = shift;
    my $cand = shift;

=pod

Returns true if the candidate string matches the user's saved password.

The candidate string may either be a raw string as from user input, or an 
already-hashed password string as taken directly from the database.

 my $login = $schema->resultset('Login')->find({ username => 'jon' });

 # this can be either a password string as entered by a human...
 my $pw_attempt = 'foo';

 # ...or an already-hashed password from the database
 my $pw_attempt = $login->password;

 # Either way...
 say +( $login->is_password($pw_attempt) ) ? "You got it right!" : "You got it wrong!";

=cut

    return 1 if $self->_password_to_hash($cand) eq $self->password;
    return 0;
}#}}}
sub looks_like_hash {#{{{
    my $self = shift;
    my $cand = shift;

=pod

Returns true if the passed-in string looks like a bcrypt hash.

When registering a new user, check the password they input using this keep 
smartass users from attempting to paste a bcrypt hash string into the password 
field.

 if( $login->looks_like_hash($user_entered_password) ) {
  die "Please stop using pre-hashed passwords as your password"
 }

=cut

    return( $cand =~ m/^\$2a?\$\d\d/ ) ? 1 : 0;
}#}}}

sub _salt {#{{{
    my $self = shift;

=pod

If the current login already has a password, this returns it.  If not, this 
generates a new salt.

=cut

    ### Docs for Crypt::Eksblowfish::Bcrypt say the salt must be 22 base64 
    ### digits.  It actually needs to be 21 base64 digits and a period.
    #my $salt = '$2a$08$' . substr (encode_base64("This is my super-secret salt"), 0, 21) . q{.};

    ### When a new user is being added, $self->password will be set to just 
    ### the user-entered string at this point.
    return $self->looks_like_hash( $self->password )
            ? $self->password 
            : ('$2a$08$' . substr (encode_base64( time() . $$ . 'flurble'), 0, 21) . q{.});
}#}}}
sub _password_to_hash {#{{{
    my $self = shift;
    my $cand = shift;

=pod

If the argument looks like a blowfish hashed string, it's returned untouched.  
Otherwise, it's assumed to be a plaintext password and is hashed with our salt 
and the hash is returned.

 my $hashed_password = $user->_password_to_hash('my_password');
 my $rehash = $user->_password_to_hash($hashed_password);

 say "same" if( $hashed_password eq $rehash );  # prints 'same'

In general, you won't need to call this; plaintext passwords passed in are 
automatically filtered into hashes before being added to the database.

=cut

    my $s = $self->_salt;
    return( $self->looks_like_hash($cand) )  ? $cand : bcrypt($cand, $self->_salt);
}#}}}
sub _datetime_to_column {#{{{
    my $self = shift;
    my $cand = shift;

=pod

A datetime going in to the database may be passed in as either a DateTime 
object or an ISO8601 datetime string.  Either way, the value actually stored in 
the database will be and ISO8601 datetime string.

If anything else is sent, the attempt to add the invalid value will die.

Dates in the SQLite database are ISO8601:
    yyyy-mm-ddThh:mm:ss
Dates in MySQL are similar but don't include the 'T' separator:
    yyyy-mm-dd hh:mm:ss

=cut
    
    return $cand->iso8601 if ref $cand eq 'DateTime';
    return undef unless $cand;
    die "Invalidd date format"
        unless $cand =~ m/^\d{4}-\d\d-\d\d[T ]\d\d:\d\d:\d\d$/;
    return $cand;
}#}}}
sub _column_to_datetime {#{{{
    my $self = shift;
    my $cand = shift;

=pod

Coming out of the database, dates will be DateTime objects.  These can be 
safely saved back to the database as they are without any manipulation.

Dates in the SQLite database are ISO8601:
    yyyy-mm-ddThh:mm:ss
Dates in MySQL are similar but don't include the 'T' separator:
    yyyy-mm-dd hh:mm:ss

=cut
    
    ### It's nullable so a false value will be undef.
    return undef unless $cand;

    given( $cand ) {
        when( m/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d$/ ) {
            return DateTime::Format::ISO8601->parse_datetime($cand);
        }
        when( m/^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$/ ) {
            return DateTime::Format::MySQL->parse_datetime($cand);
        }
        default {
            die "Invalid datetime format in database -$cand-"
        }
    }
    #die "Invalid datetime format in database -$cand-"
    #    unless $cand =~ m/^\d{4}-\d\d-\d\d[T ]\d\d:\d\d:\d\d$/;
    #return DateTime::Format::ISO8601->parse_datetime($cand);
}#}}}

1;
