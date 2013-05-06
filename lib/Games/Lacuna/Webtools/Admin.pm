package Games::Lacuna::Webtools::Admin;

use v5.14;
use warnings;   # on by default

use Dancer qw(:moose);
use Dancer::Plugin::FlashMessage;
use Dancer::Session::YAML;

use Data::Dumper;

# $Id: Admin.pm 14 2012-12-10 23:19:27Z jon $
# $URL: https://tmtowtdi.gotdns.com:15000/svn/LacunaWaX/trunk/lib/Games/Lacuna/Webtools/Admin.pm $
my $file_revision = '$Rev: 14 $';
our $VERSION = '0.1.' . $file_revision =~ s/\D//gr;

=pod

Access to any route defined here requires membership in the admin group.

=cut

### Must be declared here.  But defining it requires current user name and 
### pass, so must be defined in a route, not here.
my $cont;

prefix '/admin';
any qr{.*} => sub { # Auth {{{
    my $emp  = session('empire_name');
    my $pass = session('game_pw');

    ### Lexical global; do not re-my $cont here.
    $cont = Games::Lacuna::Webtools::get_container($emp, $pass) or return redirect '/login';

    my $users_schema = $cont->resolve( service => 'Database/users_schema' );
    my $user         = $users_schema->resultset('Login')->find({ username => session('login_name') });
    unless( $user->authorz('admin') ) {
        flash error => "You are not logged in.";    # no need for more specificity.
        return redirect '/login' . (request->path_info || q{});
    }
    pass;
};#}}}

get qr{ /users/list   (?:/(\d+))?   (?:/(\d+))? }x => sub {#{{{

    ### The regex allows this route to have two optional path params, to 
    ### match any of the following:
    ###
    ###     /admin/users/list        default page 1, default 10 rows
    ###     /admin/users/list/1      hit page 1, default 10⊚rows
    ###     /admin/users/list/2      hit page 2, default 10 rows
    ###     /admin/users/list/2/20   hit page 2, 20 rows 
    ###
    ### Just attempting to use normal /:page/:row blows up on URLs lacking 
    ### the slashes.  Even using /:page?/:row/? only makes the tokens 
    ### themselves, not the slashes, optional.
    ###
    ### It's obviously not possible to specify the second (rows per page) 
    ### token without specifying the first (current page).

    my $t_vars = Games::Lacuna::Webtools::init_tvars($cont);
    @$t_vars{'current_page', 'rows_per_page'} = splat;
    $t_vars->{'current_page'}  ||= 1;
    $t_vars->{'rows_per_page'} ||= 10;

    $t_vars->{'users_rs'} = $t_vars->{'logins_rs'}->search(
        {}, 
        {
            order_by => 'username', 
            page => $t_vars->{'current_page'}, 
            rows => $t_vars->{'rows_per_page'}
        } 
    );

    $t_vars->{'total_users'}   = $t_vars->{'users_rs'}->pager->total_entries;
    $t_vars->{'first_page'}    = $t_vars->{'users_rs'}->pager->first_page;
    $t_vars->{'previous_page'} = $t_vars->{'users_rs'}->pager->previous_page;
    $t_vars->{'next_page'}     = $t_vars->{'users_rs'}->pager->next_page;
    $t_vars->{'last_page'}     = $t_vars->{'users_rs'}->pager->last_page;

    template '/admin/users.tt', $t_vars, ;
};#}}}
get '/users/add' => sub {#{{{
    my $t_vars = Games::Lacuna::Webtools::init_tvars($cont);
    template '/admin/user_details.tt', $t_vars;
};#}}}
get '/users/details/update/*' => sub {#{{{
    ### Add route-wide init vars
    my $t_vars = Games::Lacuna::Webtools::init_tvars($cont);

    ### Add params, which include any form error messages if we're 
    ### getting here from a forward after an unsuccessful POST.
    $t_vars = { (%$t_vars, %{params()}) };

    my($username) = splat;
    my $logins_rs = $t_vars->{'logins_rs'};
    unless( $t_vars->{'edit_user'} = $logins_rs->find({ username => $username }) ) {
        flash error => "Username '$username' was not found.";
        forward '/admin/users/list';
    }

    ### Add each role the user is a member of to this user_roles 
    ### hashref.  All the variables for this are available to the 
    ### template, and I'd prefer doing this there, but things are 
    ### deeply-nested enough, and require enough method calls, that 
    ### attempting to do this within the bounds of TT is just way too 
    ### painful.
    foreach my $r( $t_vars->{'edit_user'}->roles ) {
        $t_vars->{'edit_user_roles'}{$r->name} = 1;
    }

    $t_vars->{'action'}      = 'update';
    $t_vars->{'button_text'} = 'Update User';

    template '/admin/user_details.tt', $t_vars;
};#}}}
get '/users/details/add' => sub {#{{{
    my $t_vars = Games::Lacuna::Webtools::init_tvars($cont);

    ### Add params, which include any form error messages if we're 
    ### getting here from a forward after an unsuccessful POST.
    $t_vars = { (%$t_vars, %{params()}) };

    $t_vars->{'action'} = 'add';
    $t_vars->{'button_text'} = 'Add User';
    template '/admin/user_details.tt', $t_vars;
};#}}}

post '/users/details/update/*' => sub { # Called for adding AND editing users {{{
    my $t_vars = Games::Lacuna::Webtools::init_tvars($cont);
    my($username) = splat;

    ### This route processes post from both the update and add forms.  The 
    ### add form gets pre-processed by the route below.

    ### Validate form or re-display it with error messages
    my $dfv    = config->{'dfv'};
    my $params = params;
    my $rslt   = $dfv->check($params, 'user_edit');
    unless( $rslt->success ) {
        $t_vars = $rslt->msgs;
        return forward "/admin/users/details/update/$username", $rslt->msgs, { method => 'GET' };
    }

    my $users_schema = $cont->resolve( service => 'Database/users_schema' );
    ### Grab user record from database.  In the case of a new user being 
    ### added, their record has already been created by the route below, 
    ### which forwarded back to here.
    my $user;
    unless( $user = $users_schema->resultset('Login')->find({ username => $username }) ) {
        flash error => "Username '$username' was not found.";
        forward '/admin/users/list';
    }

    ### Update user record per the form 
    {#{{{
        ### Only update the password if the admin user entered something 
        ### on the form.
        if( my $pw = $params->{'password'} ) {
            $user->password($pw);
        }

        $user->active( ($params->{'active'} ? 1 : 0) );
        $user->admin_notes( $params->{'admin_notes'} );

        my $form_roles = [];
        while( my $r = $t_vars->{'roles_rs'}->next ) {
            ### To avoid possible future collisions (more role names 
            ### may be added later, and can be anything), each role 
            ### input on the form is prefixed with "role_", so the 
            ### inputs are "role_admin", "role_member", etc.
            push @$form_roles, $r if( $params->{'role_' . $r->name} );
        }
        $user->set_roles($form_roles);

        $user->update;
    }#}}}

    flash message => "User '$username' has been updated.";
    return forward "/admin/users/details/update/$username", {}, { method => 'GET' };
};#}}}
post '/users/details/add' => sub {      # Only called when adding a new user {{{
    my $t_vars = Games::Lacuna::Webtools::init_tvars($cont);
    my $username = params->{'username'};
    my $password = params->{'password'};

    ### Validate form
    my $err = {};
    $err->{'err_username'} = 'Required!' unless $username;
    $err->{'err_password'} = 'Required!' unless $password;
    return forward "/admin/users/details/add", $err, { method => 'GET' } if %$err;

    ### Ensure username doesn't already exist
    if( $t_vars->{'logins_rs'}->find({ username => $username }) ) {
        return forward "/admin/users/details/add", {err_username => 'Already in use'}, { method => 'GET' };
    }

    ### This takes care of everything that needs to be taken care of when 
    ### creating a new user.
    my $users_schema = $cont->resolve( service => 'Database/users_schema' );
    my $user = $users_schema->create_new_user( $username, $password );

    ### ...and forward off to the update sub which is already managing 
    ### everything else.  This will maintain the current POST method.
    return forward "/admin/users/details/update/$username";
};#}}}

get '/roles/list' => sub {#{{{
    my $t_vars = Games::Lacuna::Webtools::init_tvars($cont);
    template '/admin/roles.tt', $t_vars;
};#}}}
get '/roles/details/:role' => sub {#{{{
    my $role   = param('role');
    my $t_vars = Games::Lacuna::Webtools::init_tvars($cont);
    $t_vars->{'role'}      = $t_vars->{'roles_rs'}->search({ name => $role })->next;
    $t_vars->{'logins_rs'} = $t_vars->{'role'}->logins;
    template '/admin/role_details.tt', $t_vars;
};#}}}

get '/' => sub {#{{{
    my $t_vars = Games::Lacuna::Webtools::init_tvars($cont);
    template '/admin/index.tt', $t_vars, ;
};#}}}


