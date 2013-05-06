use 5.14.0;
package Games::Lacuna::Webtools::Validation;
use Dancer::Plugin::DBIC;
use DateTime;
use DateTime::Format::Strptime;
use Games::Lacuna::Webtools;
use Validation::Class;








### I'm not using this anymore at all.



my $flurble;










# $Id: Validation.pm 14 2012-12-10 23:19:27Z jon $
# $URL: https://tmtowtdi.gotdns.com:15000/svn/LacunaWaX/trunk/lib/Games/Lacuna/Webtools/Validation.pm $
my $file_revision = '$Rev: 14 $';
our $VERSION = '0.1.' . $file_revision =~ s/\D//gr;


=pod

To validate a form:

 $params = typical form params hashref { form_field_name => form_field_value, ... }

 my $rules = Games::Lacuna::Webtools::Validation->new( params => $params );

 if( $rules->validate({
  form_field_name => 'rule_name_from_below',
 }) ) {



NOTE if the rule_name does not match the form_field_name, your $params will be modified:

 # eg
 say $params->{'fname'};    # jon

 if( $rules->validate({
  fname => 'first_name',
 }) ) {

  say $params->{'fname'};       # NOTHING IT'S NOT DEFINED ANYMORE
  say $params->{'first_name'};  # jon



This is unexpected and fucked up.  And since the args are a hashref, you cannot validate a 
single param against multiple rules.  Which I'd like to do since you only get one error message
per field.

For (eg) a password field that requires 6-12 characters, at least one symbol and one number, I'd
like to return something more specific than just "invalid password" when the user messes up.  
"what did I mess up?"

Your best bet is just to make a single rule below for each individual form field and make 
sure the rule has the same name as the form field.

Doing it that way also means you can simplify your validate call:

 if( $rules->validate('fname', 'mname', 'lname') ) { ... }


=cut


### Speed calc form
field 'from_game_id' => {
    label => 'Game ID',
    error => "Invalid game ID",
    required => 1,
    validation => sub {
        my ($self, $this_field, $all_params) = @_;
        return $this_field->{value} =~ /^\d+$/ ? 1 : 0;
    }
};
field 'from_name' => {
    label => 'Origin planet name',
    error => "Invalid planet name",
    filters => [ "trim" ],
    required => 1,
    validation => sub {
        my ($self, $this_field, $all_params) = @_;
        my $planet = schema('lacuna')->resultset('Planet')->find({ name => $this_field->{'value'} });
        return($planet) ? 1 : 0;
    }
};
field 'target_name' => {
    label => 'Target planet name',
    error => "Invalid planet name",
    filters => [ "trim" ],
    required => 1,
    validation => sub {
        my ($self, $this_field, $all_params) = @_;
        my $planet = schema('lacuna')->resultset('Planet')->find({ name => $this_field->{'value'} });
        return($planet) ? 1 : 0;
    }
};
field 'arrival_time' => {
    label => 'Arrival time',
    error => "Format as YYYY-MM-DD hh:mm:ss",
    filters => [ "trim" ],
    required => 1,
    validation => sub {
        my ($self, $this_field, $all_params) = @_;
        return $this_field->{value} =~ m/^\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d$/
            ? 1 : 0;
    }
};
field 'arrival_time' => {
    label => 'Arrival time',
    error => "Arrival time must be in the future",
    required => 1,
    validation => sub {
        my ($self, $this_field, $all_params) = @_;
        my $gmt = DateTime->now();
        my $db_strptime = DateTime::Format::Strptime->new(pattern => '%Y-%m-%d %T');
        my $desired_arr_dt = $db_strptime->parse_datetime( $this_field->{'value'} );
        return( $gmt < $desired_arr_dt ) ? 1 : 0;
    }
};

### Spy batch rename form
field 'spy_name' => {
    label => 'Spy name',
    error => "Invalid spy name",
    required => 1,
    validation => sub {
        my ($self, $this_field, $all_params) = @_;
        return( $this_field->{'value'} =~ /^[\w\s]+$/ ) ? 1 : 0;
    }
};
field 'planet_id_string' => {
    label => 'Planet identifier',
    error => "Invalid planet identifier",
    required => 1,
    validation => sub {
        my ($self, $this_field, $all_params) = @_;
        return( $this_field->{'value'} =~ /^[\w\s]+$/ ) ? 1 : 0;
    }
};

package Games::Lacuna::Webtools::Validation::Profile;

### And this line blows us completely out of the water.  It's clashing with 
### something.  I don't care what - I'm real close to done with this piece of 
### shit module.
#use Dancer qw(:syntax);

use Dancer::Plugin::DBIC;
use Games::Lacuna::Webtools;
use Validation::Class;
sub user_profile_js {#{{{

=pod

Before producing the user profile form, pull this and add it to the 
'additional_js' key of the hash sent to the output template:

 $t_vars->{'additional_js'} = Games::Lacuna::Webtools::Validation->user_profile_js;
 template 'profile/user.tt', $t_vars;

Keeping JS validation code in a Perl module may or may not be retarded.  The CWT 
is to keep all my validation stuff together so if I add a Perl validation rule 
I'll remember to add a JavaScript one at the same time.

Most validation checks are done onBlur.  However, required checks are a special
case:
    - If you enter an empty required field, then leave it and it's still 
      empty, the field is NOT validated.
        - So if you type something while in the field, then backspace/delete it 
          before you ever leave the field, it's still considered to be 
          continuously empty.
    - If you enter a value in a required field, leave the field, then return and 
      remove your previously-entered value, it WILL be validated.
    - Required fields are checked on form submit whether you ever entered the 
      field or not.

Here's an example of field A being required only if field B is empty - for this 
eg, the sitter_password field must be filled only if the empire_password field
is not.

        sitter_password: {
            required: function(element) {
                    return $("#empire_password").val() == '';
            },
        },

Full docs on this are here:
    http://docs.jquery.com/Plugins/Validation

=cut

    my $js = q%

    $(document).ready(function() {
      $("#profile").validate({
        rules: {
            empire_name: { 
                required: true
            }, 
            pw_new_confirm: { 
                equalTo: "#pw_new",
                minlength: 5
            }, 
            sitter_password: {
                required: function(element) {
                        return $("#empire_password").val() == '';
                },
            },
        },
        messages: {
            pw_new: "New password and confirmation do not match.",
            pw_new_confirm: "New password and confirmation do not match.",
            sitter_password: "Must be set if empire password is empty.",
        },
      });
    });

    %;
    return $js;
}#}}}

mixin 'password' => {
    min_length => 6,
    max_length => 20,
};
field 'pw_current' => {
    label => 'Current password',
    error => "Incorrect current password",
    mixin => 'password',
    validation => sub {
        my ($self, $this_field, $all_params) = @_;
        ### This is what I need to    use Dancer    for above.
        #my $user = schema('users')->resultset('Login')->find({ name => session 'login_name' });
        #return $user->auth( $this_field->{'value'} );
        return 1;
    }
};
field 'pw_new' => {
    label => 'New password',
    error => "Incorrect current password",
    mixin => 'password',
    matches => 'pw_new_confirm',
};
field 'pw_new_confirm' => {
    label => 'New password confirmation',
    error => "Incorrect current password",
    mixin => 'password',
    matches => 'pw_new',
};
field 'empire_name' => {
    label => 'Empire name',
    error => "Invalid empire name",
};
field 'empire_password' => {
    label => 'Empire name',
    error => "Invalid empire name",
    validation => sub {
        my ($self, $this_field, $all_params) = @_;
        return 1 unless $this_field->{'value'};
        ### TBD this shitty fucking module does not document exactly what 
        ### $all_params is so I'm guessing the following is correct.  But I'll 
        ### have to dump it out to be sure.
        return 0 unless $all_params->{'empire_name'};
        ### TBD I should be attempting to log in to the game here but I'm 
        ### getting to the point of "can't be arsed"
    }
};
field 'sitter_password' => {
    label => 'Empire name',
    error => "Invalid empire name",
    validation => sub {
        my ($self, $this_field, $all_params) = @_;
        return 1 unless $this_field->{'value'};
        ### See above.
    }
};
field 'time_zone' => {
    label => 'Time zone',
    error => "Invalid time zone",
};
field 'glyph_home' => {
    label => 'Glyph home',
    error => "Invalid glyph home",
};
field 'submit' => {
    label => 'Submit button',
    error => "Invalid validation module",
};
field 'login_name' => {
    label => 'Path param not on the fucking form but it needs to be defined here anyway',
    error => "Invalid piece of shit validation module",
};

1;
 
