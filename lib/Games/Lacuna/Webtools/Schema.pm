package Games::Lacuna::Webtools::Schema;
use base qw(DBIx::Class::Schema);

__PACKAGE__->load_namespaces();

sub create_new_user {#{{{
    my $self = shift;
    my $user = shift;
    my $pass = shift;

=pod

Manages minimal creation of a new website user record.  

Right now that requires:
    - a record in Logins, containing username and password (hashed).
        - Password hashing is being handled by the Login schema so we dont' have 
          to worry about it here
    - A record in GamePrefs.  The only value that needs to be there is the 
      Logins_id, which needs to be the ->id of the Logins record from the 
      previous step.

All other values get added elsewhere.

If you pass a username that already exists, this will ensure that username has 
an associated GamePrefs record, and will update that user record's create_date.  
You should check to see if a given username already exists in the database 
before passing it off here.



 require 'connect.pl';
 my $schema = users_schema();
 ### Or anywhere else you might get your hands on a GLWSchema object

 my $new_user = $schema->create_new_user( 'new_website_login_name', 'new_website_password' );

=cut

    my $u = $self->resultset('Login')->find_or_create({ 
        username => $user,
        password => $pass,
    });
    $u->create_date( DateTime->now() );

    my $gp = $self->resultset('GamePrefs')->find_or_create({ 
        login => $u,
    });
    
    return $u;
}#}}}

1;
