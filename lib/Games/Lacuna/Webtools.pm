package Games::Lacuna::Webtools;

use v5.14;
use utf8;       # so literals and identifiers can be in UTF-8
use strict;     # quote strings, declare variables
use warnings;   # on by default
use warnings    qw(FATAL utf8);    # fatalize encoding glitches
use open        qw(:std :utf8);    # undeclared streams in UTF-8 - does not get along with use autodie.
use charnames   qw(:full :short);  # unneeded in v5.16
use Data::Dumper;

use Carp;
use DateTime;
use DateTime::TimeZone;
use DateTime::Format::Duration;
use Encode qw();
use GD::Graph;
use GD::Graph::bars3d;
use GD::Graph::pie;
use IO::All;
use Math::BigFloat qw();
use Template;
use Try::Tiny;
use URI::Escape qw();

use Dancer qw(:moose);
use Dancer::Error;
use Dancer::Plugin::Ajax;
use Dancer::Plugin::DataFormValidator;
use Dancer::Plugin::DBIC;
use Dancer::Plugin::FlashMessage;
use Dancer::Session::YAML;

use lib "$FindBin::Bin/../../../lib";
use Games::Lacuna::Container;
use Games::Lacuna::Client::Task::Empire;
use Games::Lacuna::Client::Task::Planet;
use Games::Lacuna::Client::Task::Station;
use Games::Lacuna::Client::Util qw();
use Games::Lacuna::Webtools::Admin;

use Games::Lacuna::Schema;
use Games::Lacuna::Webtools::Schema;

# $Id: Webtools.pm 14 2012-12-10 23:19:27Z jon $
# $URL: https://tmtowtdi.gotdns.com:15000/svn/LacunaWaX/trunk/lib/Games/Lacuna/Webtools.pm $
my $file_revision = '$Rev: 14 $';
our $VERSION = '0.3.' . $file_revision =~ s/\D//gr;

### POD {{{

=head1 VERSION HISTORY

This existed for a long time with the $VERSION set to 0.1.$rev, and no history 
notes.

=head2 0.3 (09/28/2012)

    - Removed anything containing a CHI object from Dancer vars.
    - BreadBoard containers are now lexical globals; bits needed from those 
      containers (schemas, CHI caches, etc) are being resolved as they're 
      needed.
    - Finally removed the buy_spies and waste_chain route definitions; neither 
      has been used in months.

=head2 0.2 (08/02/2012)

    - Started switch to using Games::Lacuna::Container
    - Moved initial grab of game client to the any qr{.*} sub, right after 
      login check.
    - Began changing instances of "$lt" ("_l_acuna _t_ask") to "$client" for 
      consistency and clarity

=head2 0.1

Original

=cut

### }#}}}

### As of Dancer 1.3099:
### CHI caches cannot be set as Dancer vars.  There are CHI caches inside the 
### BreadBoard containers, so we can't set those as Dancer vars either.
###
### So declare both BB containers up here.  Resolve what we need to (client, 
### cache, whatever) as we need it.
###
### The user_cont will get assigned after the user logs in, but must be 
### declared here.
my $cont      = get_container( q{}, q{} ) or return redirect '/login';
my $user_cont = q{};


### Public (non-authed) routes
prefix undef;
    any qr{.*} => sub {#{{{
        ### If the current user is authed and has a message in the message 
        ### queue, this will display it for them, just once.
        ###
        ### I'm beginning to not like this; having to grab the users_schema 
        ### for every logged-in hit to the app just to check for messages, 
        ### which I hardly ever use, is wasteful.
        ### 
        ### Removing it increased the speed on the home page by 100%, so I'm 
        ### leaving it pseudo-commented for now.
        if( 0 and session('login_name') ) {
            my $users_schema = $cont->resolve( service => 'Database/users_schema' );
            if( my $user = $users_schema->resultset('Login')->find({ username => session('login_name') }) ) {
                if( my $m = ($user->messages_unread)[0] ) {
                    flash message => "Message from <strong>" . $m->from->username . ":</strong><br>"
                                    . "<em>" . $m->message . "</em>";
                    $m->perused(1);
                    $m->update;
                }
            }
        }
        pass;
    };#}}}
    get '/' => sub {#{{{
        my $t_vars = init_tvars( $cont );
        $t_vars->{'disqus_identifier'} = 'lacuna_main_index',
        template 'index.tt', $t_vars, {};
    };#}}}
    any ['get', 'post'] => qr{/login(.*)} => sub {#{{{
        my $t_vars = init_tvars( $cont );
        my $users_schema = $cont->resolve( service => 'Database/users_schema' );

        if( request->is_post ) {
            my $dfv = config->{'dfv'};
            my $params = params;
            my $rslt = $dfv->check($params, 'login');
            if( $rslt->has_missing or $rslt->has_invalid ) {
                $t_vars = $rslt->msgs;
                return template 'index.tt', $t_vars;
            }
            my $v = $rslt->valid;

            my $login;
            unless( 
                $login = $users_schema->resultset('Login')->find({ username => $v->{'username'} }) 
                and $login->authenz( $v->{'password'} ) 
            ) {
                flash error => "Invalid login credentials.";
                return template 'index.tt';
            }

            ### I'm the only one looking at this date so keep it in my TZ.
            $login->last_login_date( DateTime->now(time_zone => 'America/New_York') );
            $login->update;
            session 'logged_in'   => true;
            session 'login_name'  => $login->username;
            if( $login->game_prefs ) {
                session 'empire_name' => ($login->game_prefs->empire_name || q{});
                session 'game_pw'     => ($login->game_prefs->sitter_password || $login->game_prefs->empire_password || q{});

                my $cache_job = $users_schema->resultset('QueuedJob')->create({ 
                    name   => 'fill_empire_cache',
                    empire => session('empire_name'),
                    args   => to_json({ empire_name => session('empire_name'), password => session('game_pw') }),
                });
            }
            flash note => 'You are logged in.';
            my $redir = request->path_info;
            $redir =~ s{^/login(.*)}{$1};
            return redirect $redir || '/';
        }
        template 'index.tt';
    };#}}}
    get '/logout' => sub {#{{{
        session->destroy;
        flash note => 'You are logged out.';
        redirect '/';
    };#}}}
    prefix '/ajax' => sub {#{{{
        prefix '/autocomplete' => sub {#{{{
            ajax '/planet_names' => sub {
                my $q            = params->{'term'};
                my $main_schema  = $cont->resolve( service => 'Database/main_schema' );
                my $rs           = $main_schema->resultset('Planet')->search({ name => {'like' => "$q%"} }, {page => 1, rows => 100});
                my @names        = $rs->get_column('name')->all;
                return to_json( \@names );
            };
        };#}}}
        ### Jquery tabs can take inline HTML or external static HTML pages as 
        ### their tab contents; they're therefore expecting HTML content-type, 
        ### not XML, which is what Dancer ajax routes respond with by default.
        ### I ended up going a different route and these are not being used 
        ### anymore, but I did play with them and they worked so I'm leaving 
        ### them here for example if dynamic tabs are needed in the future.
        ajax '/tab_one' => sub {
            header('Content-Type' => 'text/html');
            header('Cache-Control' =>  'no-store, no-cache, must-revalidate');
            template 'profile/tabs/one.tt', {}, { layout => undef };
        };
        ajax '/tab_two' => sub {
            header('Content-Type' => 'text/html');
            header('Cache-Control' =>  'no-store, no-cache, must-revalidate');
            template 'profile/tabs/two.tt', {}, { layout => undef };
        };
    };#}}}

### Basic authen required
    any qr{.*} => sub {#{{{
        if( not session('logged_in') ) {
            flash error => "You are not logged in.";
            return redirect '/login' . (request->path_info || q{});
        }

        ### DO NOT 'my' this.  It's been declared already as a lexical global.
        $user_cont = get_container(session('empire_name'), session('game_pw'), 
            {cache_namespace => session('empire_name') || q{}, cache_expires_in => '1 hour'}
        );

        pass;
    };#}}}
    get '/empty_cache' => sub {#{{{
        ### Empties the entire cache, provided you're me.
        unless( session('login_name') and session('login_name') eq 'tmtowtdi' ) {
            flash error => "You are not Tim.  Stop trying to empty the cache.  Want to do anything?  Stay at Zombo.";
            return redirect 'http://www.zombo.com/';
        }
        my $fm_cache = $cont->resolve( service => 'Cache/fast_mmap' );
        $fm_cache->clear;
        flash note => 'Cache completely emptied.';
        return redirect '/';
    };#}}}
    get '/page_clear_cache' => sub {#{{{
        ### Clears the user's entire object cache.
        my $namespace = session('login_name');
        my $fm_cache = $cont->resolve( service => 'Cache/fast_mmap' );
        $fm_cache->clear;
        return redirect request->referer;
    };#}}}
    prefix '/dyn_img' => sub {#{{{
        get '/' => sub {#{{{
            return send_error("Not Found", 404);
        };#}}}
        get '/rpc_usage' => sub {#{{{
            my $t_vars = init_tvars( $cont );
            my $client = $user_cont->resolve( service => 'Game_server/connection' );
            return unless $client;

            my $fm_cache = $cont->resolve( service => 'Cache/fast_mmap' );
            my $key    = join ':', (session('empire_name'), 'rpc_image');
            ### Generating a new image for every single page hit is stupid; 
            ### it's slow, and the generation itself uses an RPC.  Nobody 
            ### should need to have that image updated any more often than 
            ### every 10 minutes.
            my $pie_png = $fm_cache->compute($key, '10 minutes', sub {
                my $used = $client->rpc_count;
                my $rem  = 10_000 - $used;
                my @data = (
                    [ "$rem Left", "$used Used" ],
                    [ $rem, $used ]
                );
                my $pie = GD::Graph::pie->new(200,170);
                $pie->set(
                    title           => "Daily RPC Usage",
                    accentclr       => 'black',
                    dclrs           => [qw(gray lgray)],
                    '3d'            => 1,
                    suppress_angle  => 20,
                ) or die $pie->error;
                return $pie->plot(\@data)->png;
            });
            Dancer::SharedData->response->content_type('image/png');
            Dancer::SharedData->response->content( $pie_png );
        };#}}}
    };#}}}
    prefix '/planets' => sub {#{{{
        get '/' => sub {   # List {{{
            my $client = $user_cont->resolve( service => 'Game_server/connection' );
            my $bodies = get_body_names($client) or return redirect '/';

            my $t_vars = init_tvars( $cont );
            $t_vars->{'planets'} = $bodies;

            $t_vars->{'disqus_identifier'} = 'planets_list';
            {
                ### Sigh.
                ### Vasari has one planet named "_SSL 3.2.6".  TT treats hash 
                ### keys that start with an underscore as private.  The only 
                ### way to access such a hash key is by undef'ing 
                ### $Template::Stash::PRIVATE. 
                local $Template::Stash::PRIVATE = undef;
                return template 'planets/list.tt', $t_vars, {};
            }
        };#}}}
        get '/all/:pid' => sub { # Redirect to either /planets/show or /stations/show {{{
            my $pid    = param('pid');
            my $client = $user_cont->resolve( service => 'Game_server/connection' );
            my $planet = get_planet($client, $pid);

            ### Any body can be routed to here, and this will determine the 
            ### type of body and forward the request off to where it belongs.
            ###
            ### This allows a listing of bodies to display just the names, not 
            ### the types, of each body.  Displaying the types requires a call 
            ### to the expensive get_empire(), while displaying just the names 
            ### does not.
            my $dest = do {
                given( $planet->type ) {
                    when( 'habitable planet' )  { join '/', (q{}, 'planets',       'show', $pid) }
                    when( 'gas giant' )         { join '/', (q{}, 'planets',       'show', $pid) }
                    when( 'space station' )     { join '/', (q{}, 'space_station', 'show', $pid) }
                    default                     { '/' }
                }
            };
            return forward $dest;
        };#}}}
        get '/show/:pid' => sub {#{{{
            my $pid    = param('pid');
            my $client = $user_cont->resolve( service => 'Game_server/connection' );
            my $planet = get_planet($client, $pid);
            my $t_vars = init_tvars( $cont );
            $t_vars->{'planet'} = $planet;
            return template 'planets/index.tt', $t_vars, {};
        };#}}}
    ### In all of the routes below, the :pid really should come last.  These 
    ### were created before I know better; don't keep doing it wrong.
    ### Also, it would simplify things if I had separate get and post routes 
    ### for each of the following.  I'm doing that now for new routes.
        any ['get', 'post'] => '/:pid/glyphs' => sub {#{{{
            my $pid    = param('pid');
            my $client = $user_cont->resolve( service => 'Game_server/connection' );
            my $planet = get_planet($client, $pid);

            if( request->is_post ) {#{{{
                my $halls_built = $planet->build_halls();
                if( $halls_built ) {
                    clear_glyphs($client, $pid);
                    clear_plans($client, $pid);
                }
                flash note => "Built $halls_built Halls of Vrbansk.";
                return redirect config->{'request_base'} . "/planets/$pid/glyphs";  # PRG
            }#}}}

            my $t_vars = init_tvars( $cont );
            $t_vars->{'planet_id'}   = $pid;
            $t_vars->{'planet_name'} = $planet->name;

    ### get_glyph_summary, from the API, tells you how many of each glyph 
    ### you've got nonzero of.  I want to provide a list of all possible 
    ### glyphs types sorted alphabetically, including the glyph types I 
    ### currently have zero of.

            ### List all possible ores, turn into hash   ( orename => 0 )
            my @ore_list = $client->ute->ore_types;
            my %all_ores;
            @all_ores{ @ore_list } = (0)x@ore_list;

            ### Get glyphs we've got nonzero of; remove those oretypes from 
            ### the ore hash.
            my $glyphs_on_planet = get_glyphs( $client, $pid );
            foreach my $glyphs_hr(@$glyphs_on_planet) {
                delete $all_ores{ $glyphs_hr->{'name'}  };
            }

            ### What's left are ores for which we have zero glyphs.  Force 
            ### those '0' into the hash to be sent to the template.
            foreach my $remaining_ore( keys %all_ores ) {
                my $hr = {
                    name => $remaining_ore,
                    quantity => 0,
                    type => $remaining_ore,
                };
                push @$glyphs_on_planet, $hr;
            }
            $t_vars->{'glyphs'} = [ sort{ $a->{'name'} cmp $b->{'name'} }@$glyphs_on_planet ];

            return template 'planets/glyphs.tt', $t_vars, {};
        };#}}}
        any ['get', 'post'] => '/:pid/ships' => sub {#{{{
            my $t_vars = init_tvars( $cont );
            my $pid    = param('pid');
            my $client = $user_cont->resolve( service => 'Game_server/connection' );
            my $planet = get_planet($client, $pid);
            my $gmt    = DateTime->now();

            if( request->is_post ) {#{{{
                my $dfv    = config->{'dfv'};
                my $params = params;
                my $rslt   = $dfv->check($params, 'speed_calc');

                if( $rslt->success ) {  # Form OK#{{{
                    my $v = $rslt->valid;

                    ### The JS datepicker gives me 'YYYY-MM-DD hh:mm:ss'.  I 
                    ### need a 'T' in place of that space for iso8601.  
                    ### Needing to do this is weak, but my Perl is stronger 
                    ### than my jquery so I'll live with it for now.
                    my $arrtime = $v->{'arrival_time'} =~ s/\s/T/r;

                    my $desired_arr_dt = $client->ute->db_strptime->parse_datetime( $arrtime );
                    $desired_arr_dt->set_time_zone('GMT');

                    ### We don't actually want the travel time here, just the 
                    ### distance, so we can use it to derive the speed.  
                    ### cartesian_distance would seem to make more sense, but 
                    ### we'd have to get both the origin's and target's x,y 
                    ### coords before using cartesian_distance, and 
                    ### get_travel_time does that for us, and gives us the 
                    ### distance as well.
                    ### So the following works just fine, though the name of 
                    ### the called sub may be counter-intuitive.

                    my $dist = ( webcall($client, 'get_travel_time', [$v->{'from_name'}, $v->{'target_name'}, 4000]) )[2];

                    $gmt = DateTime->now();
                    my $arrival_seconds = Math::BigFloat->new($desired_arr_dt->epoch - $gmt->epoch);
                    $arrival_seconds->bdiv(60);
                    $arrival_seconds->bdiv(60);
                    $arrival_seconds->bdiv(100);
                    my $speed = int ($dist / $arrival_seconds);

                    ### Now that we have the speed, we want the travel time so 
                    ### we can get the actual arrival time.
                    my $fn = $v->{'from_name'};
                    my $tn = $v->{'target_name'};

                    my( $ndur, $ndiff, $ntrash ) = eval{ $client->get_travel_time( $fn, $tn, $speed ) };
                    my $actual_arr_dt = $gmt + $ndur;
                    ### No need to clear the cache after this POST; since I'm 
                    ### using the flash as my output, and the cache getter is 
                    ### already avoiding the cache if the flash is set.
                    flash speed_to_target => 
                        "A speed of <b>$speed</b> will get you from $params->{'from_name'} to "
                        . "$params->{'target_name'} at GMT " . $actual_arr_dt->ymd . q{ } . $actual_arr_dt->hms 
                        . ",  but only if you leave right now." ;
                    return redirect config->{'request_base'} . "/planets/$pid/ships";   # PRG
                }#}}}
                else { # Form NOK#{{{
                    $t_vars = $rslt->msgs;
                }#}}}
            }#}}}

            my $ships = get_ships( $client, $pid );
            $t_vars->{'planet'}           = $planet;
            $t_vars->{'docked_ships'}     = $ships->{'Docked'};
            $t_vars->{'travelling_ships'} = $ships->{'Travelling'};
            $t_vars->{'defending_ships'}  = $ships->{'Defend'};
            $t_vars->{'building_ships'}   = $ships->{'Building'};
            $t_vars->{'now_gmt'} = join ' ', ($gmt->ymd, $gmt->hms);
            template 'planets/ships.tt', $t_vars, {};
        };#}}}
        any ['get', 'post'] => '/:pid/spies' => sub {#{{{
            my $pid     = param('pid');
            my $t_vars = init_tvars( $cont );
            my $client = $user_cont->resolve( service => 'Game_server/connection' );
            my $planet  = get_planet($client, $pid);

            ### At this point, game_prefs, spy_prefs, etc are linked to the 
            ### Logins_id.  In a perfect world they'd probably be linked to 
            ### the empire_name rather than the Login.  This would ultimately 
            ### allow a single user (Login) to manage multiple empires.
            ###
            ### I don't really need that, but the fact that I'm conflating 
            ### Login (user) with empire could become confusing.
            my $users_schema = $cont->resolve( service => 'Database/users_schema' );
            my $user     = $users_schema->resultset('Login')->find({ username => session('login_name') });
            my $tasks_rs = $users_schema->resultset('Enum_SpyTasks')->search();

            ### These spy objects do _not_ include the pref_record (the 
            ### SpyPrefs DBIC record) key.  It's being removed on purpose; 
            ### don't try to access it.
            my $spies = get_spies( $client, $pid );

            if( request->is_post ) {#{{{
                my $dfv  = config->{'dfv'};
                my $p    = params;

                if( $p->{'btn_submit'} =~ m/batch/i ) { # Batch rename#{{{
                    my $rslt = $dfv->check($p, 'spy_rename_batch');

                    if( $rslt->success ) { # Form OK #{{{
                        my $cnt = 0;
                        my $v = $rslt->valid;
                        clear_spies($client, $pid);
                        while(my($id, $hr) = each %$spies) {
                            $cnt++;
                            my $new_name = $v->{'spy_name'} . q{ } . $v->{'planet_id_string'} . q{.} . $cnt;

                            my $bldgs = get_buildings($client, $pid, 'Intelligence Ministry');
                            my($int_id, $int_hr) = each $bldgs;
                            my $int_min = get_building_object($client, $pid, $int_hr);
                            ref $int_min eq 'Games::Lacuna::Client::Buildings::Intelligence' or return send_error('No Intelligence Ministry found.', 404);

                            try{ 
                                webcall($int_min, 'name_spy', [$id, $new_name]) 
                            }
                            catch {
                                flash error => "eval Batch rename failed.";
                            }
                            finally {
                                unless(@_) {
                                    $spies->{$id}{'name'} = $new_name;
                                }
                            };
                        }
                        return redirect config->{'request_base'} . "/planets/$pid/spies";   # PRG
                    }#}}}
                    else { # Form NOK #{{{
                        ### invalid form
                        flash error => "Batch rename failed.";
                        $t_vars = $rslt->msgs;
                    }#}}}
                }#}}}
                else { # One-off rename and task assignment #{{{

                    ### TBD
                    ### This main form is not touching $dfv->check at all.  As 
                    ### of now, the only inputs are select boxes so this isn't 
                    ### huge unless somebody's trying to fuck with me, but 
                    ### should still be fixed.
                    ### 
                    ### spy name inputs are "name_ID" and "orig_name_ID" where 
                    ### ID is the spy's game ID integer.

                    clear_spies($client, $pid);

                    while(my($n,$v) = each %$p) {
                        next unless(
                               $n =~ /name_(\d+)/
                            or $n =~ /task_(\d+)/
                        );
                        my $spy_id = $1;
                        my $spy    = $user->spy_prefs->find_or_create({ spy_id => $spy_id });

                        ### Individual Rename (commented out) {#{{{
#                        my $n = 'name_' . $spy_id;
#                        my $new_name = $p->{$n};
#                        if( $p->{"orig_name_$spy_id"} ne $new_name ) {
#                            eval{ $client->call($int_min, 'name_spy', [$spy_id, $new_name]) };
#                            if( $@ and $@ =~ /1005/ ) {
#                                flash error => "$new_name: Invalid name for a spy";
#                            }
#                            $spies->{$spy_id}{'name'} = $new_name;

                            ### Keeping track of the spy's name in my prefs 
                            ### table is unnecessary, but it's easier for me 
                            ### to be able to view the records and know which 
                            ### is which if there's a name tacked on.
                            ### Keep in mind that the names on the web app are 
                            ### being drawn from the IntMin request above; 
                            ### they're coming from the actual game, not my 
                            ### database.  So the names displayed on the web 
                            ### form will be correct; the ones in my table are 
                            ### the ones that are suspect.
#                            $spy->spy_name( $new_name );
#                            $spy->update;
#                        }
                        ### }#}}}

                        ### Task reassign
                        my $t = 'task_' . $spy_id;
                        my $new_task_id = $p->{$t};
                        ### The orig task may be NULL if the user never set 
                        ### it.  Treat this as 'none' (id 0).  Forcing this 
                        ### here this way is bad you dummy
                        $p->{"orig_task_$spy_id"} ||= 0;
                        if( $p->{"orig_task_$spy_id"} != $new_task_id ) {

                            if( my $new_task = $tasks_rs->find({ id => $new_task_id }) ) {
                                $spy->task( $new_task );
                                $spy->update;
                                ### This is a little ugly.  pref_record gets 
                                ### forced in Planet::get_spies; we need to 
                                ### update it now.
                                $spies->{$spy_id}{'pref_record'} = $spy;
                            }
                            else {
                                flash error => "Unable to reassign spy '$spy_id' to '$new_task_id'";
                            }
                        }
                    }
                    return redirect config->{'request_base'} . "/planets/$pid/spies";   # PRG
                }#}}}
            }#}}}

            $t_vars->{'planet'}            = $planet;
            $t_vars->{'spies'}             = $spies;
            $t_vars->{'tasks_rs'}          = $tasks_rs;
            $t_vars->{'disqus_identifier'} = 'planet_spies';
            return template 'planets/spies.tt', $t_vars;
        };#}}}
        any ['get', 'post'] => '/excavators' => sub {#{{{
            my $t_vars = init_tvars( $cont );
            my $client = $user_cont->resolve( service => 'Game_server/connection' );

            $t_vars->{'disqus_identifier'} = 'post_storm_excavators';

            ### I'm now bailing on attempting to produce the excavator images; 
            ### they blew up after the Sept 2012 storm and I don't feel like 
            ### fixing them.
            return template 'planets/excavators_bail.tt', $t_vars;

            ### ...And now that I've got an Excel sheet creator script, 
            ### there's no need to ever come back to these graph images.
        };#}}}
        ### Observatory page, probe maps
        get '/observatory/:pid'          => sub {#{{{
            my $pid    = param('pid');
            my $client = $user_cont->resolve( service => 'Game_server/connection' );
            my $planet = get_planet($client, $pid);
            my $t_vars = init_tvars( $cont );
            $t_vars->{'planet_id'}   = $pid;
            $t_vars->{'planet_name'} = $planet->name;
            return template 'planets/observatory.tt', $t_vars, {};
        };#}}}
        get '/observatory/map/:pid'      => sub { # Display the Observatory Map {{{
            my $params = params;
            my $pid    = $params->{'pid'};
            my $client = $user_cont->resolve( service => 'Game_server/connection' );
            my $planet = get_planet($client, $pid);

            ### Add ?force=1 to this route to force a re-scan of the 
            ### observatory.  Otherwise, cached data (which lives for a week) 
            ### will be used if it exists.

### The next route below is just returning the JSON data used by the map 
### produced by this route.  If you need to debug that json, uncomment this 
### next line and add appropriate debugging stuff to the next route.
#return forward "/planets/observatory/map_data/$pid";

            my $t_vars               = init_tvars( $cont );
            $t_vars->{'planet_id'}   = $pid;
            $t_vars->{'planet_name'} = $planet->name;
            $t_vars->{'force'}       = (defined $params->{'force'} and $params->{'force'}) ? 1 : 0;

            return template 'planets/observatory_map.tt', $t_vars, {layout => 'no_right_nav.tt'};
        };#}}}
        get '/observatory/map_data/:pid' => sub { # Return the Observatory Map Data as JSON {{{

            ### This is being called by some javascript inside the map 
            ### produced by the previous route.

            my $client     = $user_cont->resolve( service => 'Game_server/connection' );
            my $params     = params;
            my $pid        = $params->{'pid'};
            my $force      = (defined $params->{'force'} and $params->{'force'}) ? 1 : 0;
            my $probe_data = get_probe_map_data($client, $pid, $force);

            my $json = to_json $probe_data;
            return $json;
        };#}}}
        ### Archaeology page, excavators map
        get '/archaeology/:pid'          => sub {#{{{
            my $pid    = param('pid');
            my $client = $user_cont->resolve( service => 'Game_server/connection' );
            my $planet = get_planet($client, $pid);
            my $t_vars = init_tvars( $cont );
            $t_vars->{'planet_id'}   = $pid;
            $t_vars->{'planet_name'} = $planet->name;
            return template 'planets/archaeology.tt', $t_vars, {};
        };#}}}
        get '/archaeology/excavators/map/:pid'      => sub { # Display the Excavator Map {{{
            my $params = params;
            my $pid    = $params->{'pid'};
            my $client = $user_cont->resolve( service => 'Game_server/connection' );
            my $planet = get_planet($client, $pid);

            ### Add ?force=1 to this route to force a re-scan of the 
            ### observatory.  Otherwise, cached data (which lives for a week) 
            ### will be used if it exists.

### The .../map_data/... route below is just returning the JSON data used by 
### the map produced by this route.  If you need to debug that json, uncomment 
### this next line and add appropriate debugging stuff to the next route.
#return forward "/planets/observatory/map_data/$pid";

            my $t_vars                = init_tvars( $cont );
            $t_vars->{'planet_id'}   = $pid;
            $t_vars->{'planet_name'} = $planet->name;
            $t_vars->{'force'}       = (defined $params->{'force'} and $params->{'force'}) ? 1 : 0;

            return template 'planets/archaeology_map.tt', $t_vars, {layout => 'no_right_nav.tt'};
        };#}}}
        get '/archaeology/excavators/map_data/:pid' => sub { # Return the Excavator Map Data as JSON {{{

            ### This is being called by Javascript inside the map served by 
            ### the previous route.

            my $client     = $user_cont->resolve( service => 'Game_server/connection' );
            my $params     = params;
            my $pid        = $params->{'pid'};
            my $force      = (defined $params->{'force'} and $params->{'force'}) ? 1 : 0;
            my $excav_data = get_excavator_map_data($client, $pid, $force);

            my $json = to_json $excav_data;
            return $json;
        };#}}}

        get '/:pid/plans' => sub {#{{{
            my $pid    = param('pid');
            my $client = $user_cont->resolve( service => 'Game_server/connection' );
            my $planet = get_planet($client, $pid);
            my $plans  = get_plans($client, $pid) or return redirect '/';
            my $t_vars = init_tvars( $cont );
            $t_vars->{'planet'} = $planet;
            $t_vars->{'plans'}  = $plans;
            return template 'planets/plans.tt', $t_vars, {};
        };#}}}
    };#}}}
    prefix '/profile' => sub {#{{{
        any ['get', 'post'] => '/' => sub {#{{{
            my $users_schema = $cont->resolve( service => 'Database/users_schema' );
            my $user         = $users_schema->resultset('Login')->find({ username => session('login_name') });

            my $t_vars                      = init_tvars( $cont );
            $t_vars->{'user'}               = $user;
            $t_vars->{'selected_tab_index'} = '0';
            $t_vars->{'time_zone_list'}     = [ DateTime::TimeZone->all_names ];

            my( $client, $empire, $planets, $stations );
            if( request->is_post ) {#{{{
                my $dfv    = config->{'dfv'};
                my $params = params;
                my $rslt   = $dfv->check($params, 'profile_form');
                if( $rslt->success ) {  # FORM OK#{{{
                    my $emp     = $params->{'empire_name'};
                    my $emp_pwd = $params->{'sitter_password'};

                    if( $params->{'empire_name'} ne session('empire_name') or $emp_pwd and $emp_pwd ne session('game_pw') ) {
                        ### Get a fresh client; user updated name or pw.
                        ### Update the 'client' and 'empire' vars as well.
                        $cont    = get_container($emp, $emp_pwd, {}) or return redirect '/login';
                        $client  = $cont->resolve( service => 'Game_server/connection' );
                    }
                    else {
                        ### emp name and pwd unchanged, so cached client OK 
                        $client = $user_cont->resolve( service => 'Game_server/connection' );
                    }
                    if( $client ) {
                        ### We may not have a client.
                        ###
                        ### If we do, and the user's cache is expired, this 
                        ### block takes a long damn time because of 
                        ### get_planets.  
                        #$empire   = var 'empire';

                        ### On a new user's first hit where they're entering 
                        ### their empirename/pw for the first time, we cannot 
                        ### resolve the empire out of the BreadBoard.
                        $empire = Games::Lacuna::Client::Task::Empire->new({ client => $client });

                        ### So don't do this.
                        #$empire = $user_cont->resolve( service => 'Game_server/empire' );


                        $planets  = get_planets($empire);
                        $stations = get_stations($empire);
                        foreach my $n (sort keys %$planets) {
                            $t_vars->{'planets'}{$n} = $planets->{$n};
                        }
                        foreach my $n (sort keys %$stations) {
                            $t_vars->{'stations'}{$n} = $stations->{$n};
                        }
                    }

                    ### Main
                    $user->password( $params->{'pw_new'} ) if $params->{'pw_new'};
                    $users_schema->resultset('GamePrefs')->find_or_create({ login => $user });
                    $user->game_prefs->empire_name    ( $params->{'empire_name'}     || undef );
                    $user->game_prefs->empire_password( $params->{'empire_password'} || undef );
                    $user->game_prefs->sitter_password( $params->{'sitter_password'} || undef );
                    $user->update;
                    session 'empire_name' => ($params->{'empire_name'} || q{});
                    session 'game_pw'     => ($params->{'sitter_password'} || $params->{'empire_password'} || q{});

                    ### Game
                    $user->game_prefs->run_scheduler        ( $params->{"run_scheduler"} ? 1 : 0 );
                    $user->game_prefs->time_zone            ( $params->{"time_zone"}    || undef );
                    $user->game_prefs->clear_pass_parl_mail ( $params->{"clear_pass_parl_mail"}  || 0 );
                    $user->game_prefs->clear_all_parl_mail  ( $params->{"clear_all_parl_mail"}  || 0 );
                    $user->game_prefs->permit_obs_scan      ( $params->{"permit_obs_scan"}  || 0 );
                    $user->update;

                    ### Planets
                    if( defined $t_vars->{'planets'} ) {
                        foreach my $pname( ('all', keys %{$t_vars->{'planets'}}) ) {

                            ### We need to encode the $pname here only because 
                            ### it's actually used as part of the input name 
                            ### on the form.  Don't encode anything else; it's 
                            ### already encoded.
                            my $enc_pname = Encode::encode("utf8", $pname);

                            my $prec = $user->planet_prefs->find_or_create({ planet_name => $pname });

                            my $at = $params->{"$enc_pname:trash_run_at"}       || 0;
                            my $to = $params->{"$enc_pname:trash_run_to"}       || 0;
                            my $ts = ($params->{"$enc_pname:train_spies"})       ? 1 : 0;
                            my $gh = $params->{"$enc_pname:glyph_home"}         || q{};
                            my $gt = $params->{"$enc_pname:glyph_transport"}    || q{};

                            ### This can be either the name of the ore to 
                            ### search or a '1' or '0', in which case it'll 
                            ### still be treated as a boolean (and glyph_home 
                            ### will then be searched).
                            my $sa = ($params->{"$enc_pname:search_archmin"})   || q{};

                            $prec->trash_run_at    ( $at );
                            $prec->trash_run_to    ( $to );
                            $prec->train_spies     ( $ts );
                            $prec->glyph_home      ( $gh );
                            $prec->glyph_transport ( $gt );
                            $prec->search_archmin  ( $sa );
                            $prec->update;
                        }
                    }

                    ### Stations
                    if( defined $t_vars->{'stations'} ) {
                        foreach my $sname( keys %{$t_vars->{'stations'}} ) {
                            my $srec = $user->station_prefs->find_or_create({ 
                                station_id => $t_vars->{'stations'}{$sname}->id
                            });
                            $srec->agree_owner_vote ( $params->{"$sname:agree_owner_vote"} );
                            $srec->agree_leader_vote( $params->{"$sname:agree_leader_vote"} );
                            $srec->agree_all_vote   ( $params->{"$sname:agree_all_vote"} );
                            $srec->update;
                        }
                    }

                    return redirect config->{'request_base'} . "/profile/";   # PRG
                }#}}}
                else {  # FORM NOK#{{{
                    flash error => "Form Errors Encountered";

                    for my $f2(qw(glyph_home time_zone)) {
                        if( defined $rslt->msgs->{"err_" . $f2} ) {
                            ### Error on form on tab 2.  Select it.
                            $t_vars->{'selected_tab_index'} = '1';
                        }
                    }
                    foreach my $n (keys %{$rslt->msgs} ) {
                        my $msg = $rslt->msgs->{$n};
                        if( $n =~ m/^err_(\w+):(.*)/ ) {
                            ### Error on form on tab 3.  Select it.
                            $t_vars->{'selected_tab_index'} = '2';

                            flash error => "Planet error - check all planet tabs!";

                            ### planet-specific errors will look like
                            ### "err_bmots:_glyph_transport".  Separate them 
                            ### out so each planet gets its own hashref of 
                            ### errors.
                            $t_vars->{'planet_errors'}{$1}{'err_' . $2} = $msg;
                            # so $t_vars->{'planet_errors'}{'bmots'}{'err_glyph_transport'} = 'glyph_transport error msg';
                            # you can get at that in a template with [% planet_errors.$pname.err_glyph_transport %]
                        }
                        else {
                            $t_vars->{$n} = $msg;
                        }
                    }
                }#}}}
            }#}}}
            else {#{{{
                if( session('empire_name') ) {#{{{
                    ### User may not have entered their game empire info yet.  If 
                    ### they haven't, we won't have access to the $client object.

                    try {

                        if( 
                            session('empire_name') and session('game_pw') 
                        ) {
                            $client   = $user_cont->resolve( service => 'Game_server/connection' );
                            $empire   = $user_cont->resolve( service => 'Game_server/empire' );
                            $planets  = get_planets($empire);
                            $stations = get_stations($empire);
                            PLANET:
                            foreach my $n (sort keys %$planets) {
                                $t_vars->{'planets'}{$n} = $planets->{$n};
                            }
                            STATION:
                            foreach my $n (sort keys %$stations) {
                                $t_vars->{'stations'}{$n} = $stations->{$n};
                            }
                        }
                    }
                    catch {
                        ### nothing to catch; the user has never logged in 
                        ### before so calling get_client blew up.  This is 
                        ### expected in that case.  Continue.
                    };

                }#}}}
            }#}}}


    ### Remember that it is possible to get to this point without having  
    ### $client ($c, $lt, whatever) or $empire variables set - NEW USERS WILL 
    ### NOT HAVE THESE SET YET!
    ###
    ### So do not just blindly attempt to access them below.


            ### This has to be done down here so the prefs get assigned to 
            ### $t_vars after any changes were made in the form processing 
            ### above.
            $t_vars->{'planet_prefs'}{'all'} = $user->planet_prefs->find({ planet_name => 'all' });
            while( my($n,$obj) = each %{$t_vars->{'planets'}} ) {
                $t_vars->{'planet_prefs'}{$n} = $user->planet_prefs->find({ planet_name => $n });
            }

            while( my($n,$obj) = each %{$t_vars->{'stations'}} ) {
                $t_vars->{'station_prefs'}{$n} = $user->station_prefs->find({ 
                    Logins_id => $user->id,
                    station_id => $obj->id,
                });
            }

            if( $empire ) {
                my $users_schema = $cont->resolve( service => 'Database/users_schema' );
                $t_vars->{'scheduler_log_rs'} = $users_schema->resultset('ScheduleLog')->search_rs({
                    empire_name => $empire->name,
                });
                if( $t_vars->{'scheduler_log_rs'}->count ) {
                    $t_vars->{'scheduler_log'} = template 'profile/scheduler_log.tt', $t_vars, {layout => undef};
                }
            }

            ### We'd normally hang Util calls off $client->ute, but we're not 
            ### guaranteed to have a $client at this point, and ore_types is a 
            ### static method, so we're better off calling it directly.
            $t_vars->{'ore_types'} = [ Games::Lacuna::Client::Util::ore_types() ];

            $t_vars->{'main_form'}    = template 'profile/main.tt',    $t_vars, {layout => undef};
            $t_vars->{'game_form'}    = template 'profile/game.tt',    $t_vars, {layout => undef};
            $t_vars->{'planet_form'}  = template 'profile/planet.tt',  $t_vars, {layout => undef};
            $t_vars->{'station_form'} = template 'profile/station.tt', $t_vars, {layout => undef};
            template '/profile/index.tt', $t_vars, ;
        };#}}}
    };#}}}
    prefix '/space_station' => sub {#{{{
        get '/' => sub {#{{{
            return send_error("Not Found", 404);
        };#}}}
        get '/show/:pid' => sub {#{{{
            my $pid    = param('pid');
            my $t_vars = init_tvars( $cont );
            my $client = $user_cont->resolve( service => 'Game_server/connection' );
            my $ss     = get_planet($client, $pid);

            ### Newer stations won't have both Parliament and IBS buildings 
            ### yet, so they can't have seizure map data files yet either.
            ### So only toggle linking to the seizure map if such a data file 
            ### exists.
            my $map_data_path = config->{'app_root'} 
                                . '/htdocs/Lacuna-Webtools/public/starmap/data/' 
                                . 'ss_seizure_' . $pid . '.json';
            if( -e $map_data_path ) {
                $t_vars->{'show_map_link'} = true;
            }

            $t_vars->{'eq_ic'} = sub { lc $_[0] eq lc $_[1] };
            $t_vars->{'ss'}    = $ss;
            template 'space_station/index.tt', $t_vars, {};
        };#}}}
        get '/:pid/ships/incoming' => sub {#{{{
            my $t_vars = init_tvars( $cont );
            my $pid    = param('pid');
            my $client = $user_cont->resolve( service => 'Game_server/connection' );

            $t_vars->{'eq_ic'}        = sub { lc $_[0] eq lc $_[1] };
            $t_vars->{'ss_id'}        = $pid;
            $t_vars->{'ss_name'}      = $client->planets->{$pid};
            $t_vars->{'lnk_incoming'} = 1;
            $t_vars->{'incoming'}     = get_ss_incoming($client, $pid);
            template 'space_station/ships.tt', $t_vars, {};
        };#}}}
        get '/:pid/ships/orbiting' => sub {#{{{
            my $t_vars = init_tvars( $cont );
            my $pid    = param('pid');
            my $client = $user_cont->resolve( service => 'Game_server/connection' );
            $t_vars->{'eq_ic'}        = sub { lc $_[0] eq lc $_[1] };
            $t_vars->{'ss_id'}        = $pid;
            $t_vars->{'ss_name'}      = $client->planets->{$pid};
            $t_vars->{'lnk_orbiting'} = 1;
            $t_vars->{'num_orbiting'} = count_ss_orbiting($client, $pid);
            template 'space_station/ships.tt', $t_vars, {};
        };#}}}
    };#}}}
    prefix '/scripts' => sub {#{{{
        get '/' => sub {#{{{
            template 'scripts/index.tt';
        };#}}}
        get '/perl_module_install'  => sub { template 'scripts/perl_module_install.tt', {}; };
        get '/tmt_wx_gui' => sub {
            my $t_vars = init_tvars( $cont );
            $t_vars->{'disqus_identifier'} = 'lacunawax_bugs';
            template 'scripts/tmt_wx_gui.tt', $t_vars;
        };
        get qr{(/tmt_.*)}      => sub { my($n) = splat; template "scripts/$n.tt", {}; };
        ### That regex route does this:
        # get '/tmt_build_ships'      => sub { template 'scripts/tmt_build_ships.tt', {}; };
        # etc
    };#}}}
    prefix '/starmap' => sub {#{{{
        get '/' => sub {#{{{
            return send_error("Not Found", 404);
        };#}}}
        any ['get', 'post'] => '/body_ores' => sub {#{{{
            my $t_vars = init_tvars( $cont );

            if( request->is_post ) {#{{{
                my $dfv = config->{'dfv'};
                my $p   = params;

                my $rslt = $dfv->check($p, 'body_ores');
                if( $rslt->success ) { # Form OK #{{{
            
                    my $types = [];
                    given( $p->{'body_type'} ) {
                        when( 'asteroid' ) {
                            $types = ['asteroid']
                        }
                        when( 'habitable planet' ) {
                            $types = ['habitable planet']
                        }
                        when( 'both' ) {
                            $types = ['asteroid', 'habitable planet']
                        }
                    };

                    my $main_schema  = $cont->resolve( service => 'Database/main_schema' );
                    my $rs = $main_schema->resultset('Planet')->search(
                        {
                            type => { in => $types },
                            zone => $p->{'zone'},
                            $p->{'ore_type'} => { '>=' => $p->{'ore_minimum'} },
                        }, 
                        {
                            order_by => { -desc => $p->{'ore_type'} },
                            page => 1, rows => 100
                        }
                    );

                    foreach my $k( keys %{$p} ) {
                        $t_vars->{$k} = $p->{$k};
                    }
                    $t_vars->{'ore_report'} = $rs;
                }#}}}
                else { # Form NOK #{{{
                    ### invalid form
                    flash error => "Please fix the errors below.";
                    $t_vars = $rslt->msgs;
                }#}}}
            }#}}}

            $t_vars->{'zones'} = [
                "-1|-1", "-1|-2", "-1|-3", "-1|-4", "-1|-5", "-1|0", "-1|1", "-1|2", "-1|3", "-1|4", "-1|5", "-2|-1", 
                "-2|-2", "-2|-3", "-2|-4", "-2|-5", "-2|0", "-2|1", "-2|2", "-2|3", "-2|4", "-2|5", "-3|-1", "-3|-2", 
                "-3|-3", "-3|-4", "-3|-5", "-3|0", "-3|1", "-3|2", "-3|3", "-3|4", "-3|5", "-4|-1", "-4|-2", "-4|-3", 
                "-4|-4", "-4|-5", "-4|0", "-4|1", "-4|2", "-4|3", "-4|4", "-4|5", "-5|-1", "-5|-2", "-5|-3", "-5|-4", 
                "-5|-5", "-5|0", "-5|1", "-5|2", "-5|3", "-5|4", "-5|5", "0|-1", "0|-2", "0|-3", "0|-4", "0|-5", "0|0", 
                "0|1", "0|2", "0|3", "0|4", "0|5", "1|-1", "1|-2", "1|-3", "1|-4", "1|-5", "1|0", "1|1", "1|2", "1|3", 
                "1|4", "1|5", "2|-1", "2|-2", "2|-3", "2|-4", "2|-5", "2|0", "2|1", "2|2", "2|3", "2|4", "2|5", "3|-1", 
                "3|-2", "3|-3", "3|-4", "3|-5", "3|0", "3|1", "3|2", "3|3", "3|4", "3|5", "4|-1", "4|-2", "4|-3", "4|-4", 
                "4|-5", "4|0", "4|1", "4|2", "4|3", "4|4", "4|5", "5|-1", "5|-2", "5|-3", "5|-4", "5|-5", "5|0", "5|1", 
                "5|2", "5|3", "5|4", "5|5", 
            ];
            $t_vars->{'ores'} = [qw(
                anthracite bauxite beryl chalcopyrite chromite fluorite galena goethite gold gypsum halite kerogen
                magnetite methane monazite rutile sulfur trona uraninite zircon
            )];

            $t_vars->{'disqus_identifier'} = 'starmap_ore_report';
            template 'starmap/body_ores.tt', $t_vars, {};
        };#}}}
        get '/map' => sub {#{{{
            my $t_vars = init_tvars( $cont );
            template 'starmap/starmap.tt', $t_vars, { layout => 'no_right_nav.tt' };
        };#}}}
        get '/ss/:ss_name/:ss_id' => sub {#{{{
            my $t_vars = init_tvars( $cont );
            my $ss_name = param('ss_name');
            my $ss_id   = param('ss_id');

            ### Ensure just the first letter of the ss_name is UC, mainly so 
            ### 'combined', as forwarded from /ss/combined, gets UC.
            $t_vars->{'ss_name'} = $ss_name;
            substr( $t_vars->{'ss_name'}, 0, 0, uc(substr $t_vars->{'ss_name'}, 0, 1) );

            ### Allow JSON filename to be passed as a parameter.  Failing 
            ### that, derive it based on the SS ID.
            $t_vars->{'json_file'} = param('json_file')
                ? param('json_file')
                : 'ss_seizure_' . $ss_id . ".json";

            my $path = config->{'app_root'}."/htdocs/Lacuna-Webtools/public/starmap/data/$t_vars->{'json_file'}";
            unless( -e $path ) {
                flash error => "No map file has been generated for $ss_name yet.  Poke tmtowtdi in-game.";
                return redirect '/planets';
            }

            template 'starmap/ss_map.tt', $t_vars, { layout => 'no_right_nav.tt' };
        };#}}}
        get '/ss/combined' => sub {#{{{
            my $t_vars = init_tvars( $cont );
            ### The 123 below is nonsense just so the forward matches the 
            ### route above.
            return forward '/starmap/ss/combined/123', {json_file => 'ss_seizure_combined.json'}
        };#}}}
    };#}}}

####### END OF ROUTE DECLARATIONS #######


### Subs that return chunks of HTML
sub show_captcha {#{{{
    my $t_vars = shift;

=pod


I'm sure this worked at some point, but it's been a long time and the code is 
beginning to rot.

If you find you have need of this, it'll need some love first.

=cut

die "You need to fix show_captcha.";



=pod




Does require login.

Displays captcha image and two inputs in a fieldset:
    - 'captcha_guid' (hidden input)
        - This is the ID of the captcha that must be sent to the server with the answer
    - 'captcha_resp' (text)
        - This is the user's response.

Neither form tags nor submit button are included; this assumes you want to insert the 
captcha into another form you're already working on.

Accepts a hashref of the vars to be passed to the template.  This allows you to pass
    fieldset_id
    legend_id
    guid_id
    img_id
    resp_id

...the values of these keys will be the string used as the appropriate HTML tags' id value.

=cut

    my $lt = get_client(session('empire_name'), session('game_pw')) or return redirect '/login';
    my $captcha_obj           = webcall( $lt, 'captcha' );
    my $captcha               = webcall( $captcha_obj, 'fetch' );
    $t_vars->{'captcha_url'}  = $captcha->{'url'};
    $t_vars->{'captcha_guid'} = $captcha->{'guid'};
    return template 'captcha.tt', $t_vars, { layout => undef };
};#}}}

### Utes
sub clear_glyphs {#{{{
    my $client = shift;
    my $pid    = shift;

=pod

Given an empire object and a planet ID, clears any glyphs from the cache.

=cut

    my $ns     = session('login_name');
    my $key    = join ':', ($ns, $client->name, 'planet', $pid, 'glyphs');
    my $fm_cache = $cont->resolve( service => 'Cache/fast_mmap' );
    $fm_cache->remove($key);
    return 1;
}#}}}
sub clear_plans {#{{{
    my $client = shift;
    my $pid    = shift;

=pod

Given an empire object and a planet ID, clears any plans from the cache.

=cut

    my $ns     = session('login_name');
    my $key    = join ':', ($ns, $client->name, 'planet', $pid, 'plans');
    my $fm_cache = $cont->resolve( service => 'Cache/fast_mmap' );
    $fm_cache->remove($key);
    return 1;
}#}}}
sub clear_spies {#{{{
    my $client = shift;
    my $pid    = shift;

=pod

Given an empire object and a planet ID, clears any spies from the cache.

=cut

    my $ns     = session('login_name');
    my $key    = join ':', ($ns, $client->name, 'planet', $pid, 'spies');
    my $fm_cache = $cont->resolve( service => 'Cache/fast_mmap' );
    $fm_cache->remove($key);
    return 1;
}#}}}
sub count_ss_orbiting {#{{{
    my $lt = shift;
    my $pid = shift;
    
    my $fm_cache = $cont->resolve( service => 'Cache/fast_mmap' );
    my $key    = join ':', ('space_station_orbiting', $pid, 'count');

    my $ps_ref = get_buildings($lt, $pid, 'Police Station');
    my($id, $ps_hr) = each %$ps_ref;
    return 0 unless defined $id and $id =~ /^\d+$/; # no ID means no Police Station at this SS yet.

    my $ps = get_building_object($lt, $pid, $ps_hr);

    my $count = $fm_cache->compute($key, {}, sub {
        my $page_number = 1;
        my $rv = webcall($ps, 'view_ships_orbiting', [ $page_number ]);
        my $cnt = $rv->{'number_of_ships'};
        $fm_cache->set($key, $cnt, '1 hour');
        $cnt;
    });
    return $count;

=pod

The orbiting ships page is currently displaying just a count.  I've been toying with the
idea of linking page counts (integers) on that page.  Each link would request an individual 
page of orbiting ships.  

We know the number of pages: 

    my $pages = $count (from above) / 25;
    if( $count % 25 ) {
        $pages++;
    }

If I end up doing that, I should cache that first page of ships (which I just now retrieved
in order to get the number_of_ships).  The page cache key would be:

    my $page_cache_key = join ':', ( 'space_station_orbiting', $ss->{'id'}, 'pages', $current_page );

=cut

}#}}}
sub get_buildings {#{{{
    my $client = shift;
    my $pid    = shift;
    my $type   = shift;

=pod

Given a client, pid, and optional building type, returns a hashref of matching 
buildings.

This uses GLC's built-in get_buildings rather than my Planet.pm's get_buildings, 
and I think is going to be preferred.

However, that means that the buildings are _not_ objects, just hashrefs.

See get_building_object to turn a single building hashref into a building object.

 {
  id1 => { building_hashref },
  id2 => { building_hashref },
  etc
 }

The building_hashrefs are in the form:

 {
  "name" : "Apple Orchard",
  "x" : 1,
  "y" : -1,
  "url" : "/apple",
  "level" : 3,
  "image" : "apples3",
  "efficiency" : 95,
  "pending_build" : {                            # only included when building is building/upgrading
   "seconds_remaining" : 430,
   "start" : "01 31 2010 13:09:05 +0600",
   "end" : "01 31 2010 18:09:05 +0600"
  },
  "work" : {                                     # only included when building is working (Parks, Waste Recycling, etc)
   "seconds_remaining" : 49,
   "start" : "01 31 2010 13:09:05 +0600",
   "end" : "01 31 2010 18:09:05 +0600"
  }
 }

The optional building type string should match either the building name or the 
url.  If matching the url, you should NOT include the leading slash.  Both 
matches are case in-sensitive.

Without the optional building type, all buildings on the planet are returned.

=cut

    my $fm_cache = $cont->resolve( service => 'Cache/fast_mmap' );
    my $ns     = session('login_name');
    my $key    = join ':', ($ns, $client->name, 'planet', $pid, 'body_buildings');

    my $all_bldgs = $fm_cache->compute($key, '1 day', sub {
        my $planet = get_planet($client, $pid);
        my $rv = webcall($planet->body, 'get_buildings');
        return $rv->{'buildings'};
    });

    return $all_bldgs unless $type;

    my $type_bldgs = {};
    foreach my $id( keys %$all_bldgs ) {
        my $this_bldg = $all_bldgs->{$id};
        if( 
            $this_bldg->{'name'} =~ /$type/i    # "Apple Orchard"
            or
            $this_bldg->{'url'} =~ m{/$type}i   # "/apple"
        ) {
            $this_bldg->{'id'} = $id;   # add id to the hashref; save us a step elsewhere.
            $type_bldgs->{$id} = $this_bldg;
        }
    }
    return $type_bldgs;
}#}}}
sub get_building_object {#{{{
    my $client  = shift;
    my $pid     = shift;
    my $bldg_hr = shift;

=pod

Meant to be called on one of the hashrefs returned by get_buildings to 
return an actual building object when that's needed.

The $bldg_hr passed in must have an 'id' key.  If you called get_buildings() 
without passing it a building type, the hashrefs returned will NOT include the 
buildings' IDs, but the hashrefs are themselves in a hashref which is keyed on 
the ID.  So you've got the thing in hand, you'll just have to put it into the 
building hashref before passing it.  

But only if you need that; I don't forsee needing to generate building objects 
after a generic "getall" type call to get_buildings.

=cut

    unless( defined $bldg_hr->{'id'} ) {
        die "No ID defined for this building.  If you're seeing this error and you're not tmtowtdi,
do me a favor and copy the Stack section below into a quick email to me (tmtowtdi\@gmail.com), 
if you'd be so kind.\n";
    }

    my $id   = $bldg_hr->{'id'}; 
    my $type = substr $bldg_hr->{'url'}, 1;   # remove the leading slash from the url
    
    my $obj = webcall( $client, 'building', [id => $id, type => $type] );
    return $obj;
}#}}}
sub get_client {#{{{
    my($empire,$pwd) = @_;

=pod


DEPRECATED

The only calls to this are in routes that are themselves deprecated.



Given an empire name and password (either full empire password or sitter 
password), orcishly returns a client object.

Returns the GLCA object on successful login.

If login fails, the next step depends on why it failed.

- For a simple Over 60 RPCs in a Minute error, this just sets the flash and 
  redirects the user to '/'.

- For any other error, this sets the flash, clears the client cache as well as 
  the empire_name and game_pw from the session, then returns 0.

In all cases where the flash gets set, a more helpful and full error message 
does get output on the page in HTML comments.  Search the source for the string 
"ERROR".

=cut

    unless( $empire and $pwd ) {
        flash error => "Your game login information is not correct; please fix this in the profile page.";
        forward '/';
    }

    get_client_raw( $empire, $pwd, 'us1', {caller_type => 'web'} );
}#}}}
sub get_client_raw {#{{{
    my($empire,$pwd) = @_;

=pod


DEPRECATED


Given an empire name and password (either full empire password or sitter 
password), returns a fresh client object.  No caching is performed.
However, if the login fails, this will _clear_ the cache.

This is needed particularly when the user is busy changing his sitter 
password; in that case we need to make sure we're getting a fresh (non-cached)
client using the new password instead of getting the old cached client, which 
won't actually function anymore.

=cut


    my $c  = try {
        my $conn = le_connect( $empire, $pwd, 'us1', {caller_type => 'web', no_cache => 1} );
        return $conn;
    }
    catch {#{{{
        if( $_ =~ m/1010/ ) {
            flash error => "Slow down!  60 RPCs allowed per minute; you're over.
<!--
ERROR
empire: $empire
pwd: $pwd
error: $_
-->
            
            ";
            forward '/';
        }
        elsif( $_ =~ m/FOO/ ) {
            die "==$_==";
        }
        elsif( $_ =~ m/1004/ ) {
            flash error => "Your sitter password is not correct; either this is your first time using this tool or
            you changed the sitter in-game so the one recorded here is no longer valid.  You can edit your sitter on 
            the profile page.  Most of this tool will be unusable until you enter a valid password.
<!--
ERROR
empire: $empire
pwd: $pwd
error: $_
-->
            ";

            session 'empire_name' => q{};
            session 'game_pw'     => q{};
            return 0;
        }
        else {
            flash error => "3 Unknown error encountered attempting to log in to the game.
<!--
ERROR
empire: $empire
pwd: $pwd
error: $_
-->
            ";
            session 'empire_name' => q{};
            session 'game_pw'     => q{};
            return 0;
        }
    };#}}}

    return $c;
}#}}}
sub get_container {#{{{
    my( $emp, $pwd, $args ) = @_;

=pod

Given a game empire name and its password (either sitter or full), returns a 
Games::Lacuna::Container for that empire.

 my $container = get_container( 'EmpName', 'EmpPass' );

If you need to send additional args to the Container's constructor, pass them 
as a hashref in the third arg.

 my $container = get_container( 'EmpName', 'EmpPass', {cache_namespace => 'foo'} );

=cut

    $args ||= {};
    Games::Lacuna::Container->new({
        name        => 'MyContainer',
        empire      => $emp || q{},
        password    => $pwd || q{},
        caller_type => 'web',
        no_cache    => 1,
        %$args
    });
}#}}}
sub get_empire {#{{{
    my $client = shift;

=pod

DEPRECATED.

This is not being called by anything anymore; use the empire from the container 
instead.

Given a client object, orcishly returns the associated empire object. 

Try real hard not to call this.  An empire must iterate and instantiate objects for 
all planets in that empire.  The objects get cached, but the initial creation is 
still expensive.

=cut

    my $empire = 
        try {
            Games::Lacuna::Client::Task::Empire->new({ client => $client });
        }
        catch {#{{{
            if( $_ =~ m/1010/ ) {
                flash error => "Slow down!  60 RPCs allowed per minute; you have gone over.";
            }
            elsif( $_ =~ m/1004/ ) {
                flash error => "Your game password is not correct; either this is your first time using this 
                tool or you changed the password in-game so the one recorded here is no longer valid.  
                You can edit your password on the profile page.  Most of this tool will be unusable until 
                you enter a valid password.
<!--
ERROR
error: $_
-->
                ";
                session 'empire_name' => q{};
                session 'game_pw'     => q{};
                forward '/';
            }
            else {
                flash error => qq{
                    4 Unknown error encountered from game server.  If this is the first time you're seeing 
                    this, wait a sec and try again.
                    <!-- ERROR
                    $_
                    -->
                };
            }
            forward '/';
        };#}}}

    return $empire;
}#}}}
sub get_excav_data {#{{{
    my $client = shift;

=pod

Returns a hashref representing excavated ore empire-wide.

Requires a client object as its only argument.

The hashref returned is in the form:

 {
    planet_name_1 => {
        ecavs => {
            name_of_excavated_body => {
                data => [ anthra_count, baux_count, ..., zircon_cnt ],
                x    => y coord of body,
                y    => y coord of body,
            },
            ...
        },
        totals => [ anthra_count, baux_count, ..., zircon_cnt ],  # for planet as a whole
        date => time(), # unix timestamp when this data was gathered and cached.
    },

    ...
 }

The integer values in the arrayrefs are in the same order as the list of ores 
returned by $client->util->ore_types().

=cut

    my @all_empire_planets = keys %{ $client->planets_names };
    my @ore_types          = $client->ute->ore_types;

    my $all_data = {};
    PLANET:
    foreach my $pname( @all_empire_planets ) {
        my $pid = $client->planets_names->{$pname};
        my %body_totals = ();

        my($bid, $am_hr) = each get_buildings($client, $pid, 'Archaeology');
        $am_hr and ref $am_hr eq 'HASH' or next PLANET;
        my $am = get_building_object($client, $pid, $am_hr);
        ref $am eq 'Games::Lacuna::Client::Buildings::Archaeology' or next PLANET;

        my $view = $am->view_excavators();

        EXCAV:
        foreach my $e( @{$view->{'excavators'}} ) {#{{{
            #my $main_schema = var 'main_schema';
            my $main_schema  = $cont->resolve( service => 'Database/main_schema' );
            my $body = $main_schema->resultset('Planet')->find({ x => $e->{body}{x}, y => $e->{body}{y} });
            if( $body ) {
                my @excav_ore_amts = ();
                foreach my $o(@ore_types) {
                    push @excav_ore_amts, $body->$o || 0;
                    $body_totals{ $o } += $body->$o;
                }
                $all_data->{$pname}{excavs}{ $e->{body}{name} }{data} = \@excav_ore_amts;
                $all_data->{$pname}{excavs}{ $e->{body}{name} }{id}   = $e->{body}{id};
                $all_data->{$pname}{excavs}{ $e->{body}{name} }{x}    = $e->{body}{x};
                $all_data->{$pname}{excavs}{ $e->{body}{name} }{y}    = $e->{body}{y};
            }
            else {
                debug "I have not probed the star for $e->{body}{name}.";
                next EXCAV;
            }
        } #}}}

        $all_data->{$pname}{totals} = [ @body_totals{@ore_types} ];
        $all_data->{$pname}{date}   = time();
    }
        
    return $all_data;
}#}}}
sub get_glyphs {#{{{
    my $client = shift;
    my $pid    = shift;

=pod

Given a client object and a planet ID, orcishly returns the glyphs on-planet. 
The glyphs returned are ordered alphabetically by glyph name.

=cut

    my $fm_cache = $cont->resolve( service => 'Cache/fast_mmap' );
    my $glyph_key = join ':', ($client->name, 'planet', $pid, 'glyphs');

    my $glyphs = [];

    $glyphs = try {
        $fm_cache->get($glyph_key);
    }
    catch {
        return $glyphs;
    };

    if( $glyphs = $fm_cache->get($glyph_key) ) {
        return $glyphs;
    }

    my $ams = get_buildings($client, $pid, 'Archaeology Ministry');
    my($id, $am_hr) = each %$ams;
    return unless $id =~ /^\d+$/;
    my $am = get_building_object($client, $pid, $am_hr);

    $glyphs = webcall($am, 'get_glyph_summary')->{'glyphs'};
    $fm_cache->set($glyph_key, $glyphs, '1 hour');

    return $glyphs;
}#}}}

### 08/08/2012
### Let some time go by, then delete the *_old subs below and move the rest to 
### where they belong alphabetically.
sub get_body {#{{{
    my $client      = shift;
    my $bid         = shift;
    my $typehint    = shift || 'planet';

=pod

Given an empire object and a body ID, orcishly returns the body object, which 
may be either a Planet or a Space Station.

=cut

    my $fm_cache = $cont->resolve( service => 'Cache/fast_mmap' );
    my $key         = join ':', ('body_serials', $bid);
    my $serialized  = q{};

    ### Both Station.pm and Planet.pm have a deserialize method, and both will 
    ### return the correct object type (so Planet.pm's deserialize _will_ 
    ### return a Station object if it's appropriate, and vice-versa).
    ### 
    ### Calling the 'appropriate' deserialize() below, depending on the value 
    ### of $typehint, is therefore only really gaining code clarity, not 
    ### accuracy.
    if( $serialized = $fm_cache->get($key) ) {
        return Games::Lacuna::Client::Task::Station->deserialize($serialized, $client) if $typehint eq 'station';
        return Games::Lacuna::Client::Task::Planet->deserialize($serialized, $client);
    }

    my $body = try {
        my $body = Games::Lacuna::Client::Task::Planet->new({
            client => $client,
            id     => $bid
        });

        if( webcall($body, 'type') eq 'space station' ) {
            bless $body, 'Games::Lacuna::Client::Task::Station';
        }
        return $body;
    }
    catch {#{{{
        if( $_ =~ m/1010/ ) {
            flash error => "Slow down!  60 RPCs allowed per minute; you have gone over.";
        }
        else {
            flash error => qq{
                5 Unknown error encountered from game server.  If this is the first time you're seeing 
                this, wait a sec and try again.
                <!-- ERROR
                $_
                -->
            };
        }
        forward '/';
    };#}}}

    $serialized = webcall($body, 'serialize');
    $fm_cache->set($key, $serialized, '6 hours');

    return $body;
}#}}}
sub get_planet {#{{{
    return get_body(shift(), shift(), 'planet');
}#}}}
sub get_planets {#{{{
    my $emp_obj = shift;

=pod

Given an empire object, orcishly returns the hashref of only planet objects, 
not station objects, keyed off the planet names, belonging to that empire.

Although station objects are not included in the returned hashref, they will be 
(because they must be) pulled from the server and cached.

=cut

    my $client = $emp_obj->client;

    my $planets_hr = {};
    my $bodies = $emp_obj->bodies;
    foreach my $body_name( keys %$bodies ) {
        my $bid = $bodies->{$body_name};
        my $body = get_planet($client, $bid);
        $planets_hr->{$body_name} = $body unless $body->type eq 'space station';
    }
    return $planets_hr;

}#}}}
sub get_station {#{{{
    return get_body(shift(), shift(), 'station');
}#}}}
sub get_stations {#{{{
    my $emp_obj = shift;

=pod

Given an empire object, orcishly returns the hashref of only station objects, 
not planet objects, keyed off the station names, belonging to that empire.

Although planet objects are not included in the returned hashref, they will be 
(because they must be) pulled from the server and cached.

=cut

    my $client = $emp_obj->client;
    my $stations_hr = {};

    my $bodies = $emp_obj->bodies;
    foreach my $body_name( keys %$bodies ) {
        my $sid = $bodies->{$body_name};
        my $body = get_station($client, $sid);
        $stations_hr->{$body_name} = $body if $body->type eq 'space station';
    }
    return $stations_hr;
}#}}}

sub get_plans {#{{{
    my $client = shift;
    my $pid    = shift;

=pod

Given a client object and a planet ID, orcishly returns the plans on-planet. 

Plans are returned as an AoH.  Each h represents a single plan type, and 
includes the keys
    level
    extra_build_level
    quantity
    name

=cut

    my $fm_cache = $cont->resolve( service => 'Cache/fast_mmap' );
    my $plans_key   = join ':', ('planet', $pid, 'plans');
    my $pcc_key     = join ':', ('planet', $pid, 'Planetary Command Center');

    my $plans;
    if( $plans = $fm_cache->get($plans_key) ) {
        return $plans;
    }

    my $pccs = get_buildings($client, $pid, 'Planetary Command Center');
    my($id, $pcc_hr) = each %$pccs;
    return unless $id =~ /^\d+$/;
    my $type_arg = substr $pcc_hr->{'url'}, 1;   # remove the leading slash from the url
    my $pcc = webcall($client, 'building', [id => $id, type => $type_arg]);

    $plans = webcall($pcc, 'view_plans')->{'plans'};
    $fm_cache->set($plans_key, $plans, '1 hour');

    return $plans;
}#}}}
sub get_excavator_data {#{{{
    my $client = shift;
    my $pid    = shift;

=pod

Given a client object and a planet ID, returns the excavator data from the 
Arch Min as an AoH:

 $rv = [
    {
        id => 1234,     # of the excavator
        body => {
            name => 'Some Planet 5',
            x => 10,
            y => 20,
            image => "a1-5",
        }
        artifact => 5,
        glyph => 30,
        plan => 7,
        resource => 53,
    },
    {
        ...more of the same...
    }
 ];

If there's no arch min or we're otherwise unable to get a reasonable return from
view_excavators, this returns an empty arrayref.

THIS ATTEMPTS NO CACHING.  The data returned will always be fresh.

=cut

    my $excavs = [];

    my $am = get_buildings($client, $pid, 'Archaeology');
    my($id, $am_hr) = each %$am;
    return $excavs unless $id =~ /^\d+$/;
    my $type_arg = substr $am_hr->{'url'}, 1;   # remove the leading slash from the url
    my $am_obj = webcall($client, 'building', [id => $id, type => $type_arg]);

    my $excavs_rv = webcall($am_obj, 'view_excavators' );
    if( defined $excavs_rv->{'excavators'} ) {
        $excavs = $excavs_rv->{'excavators'};
    }

    return $excavs;
}#}}}
sub get_excavator_map_data {#{{{
    my $client = shift;
    my $pid    = shift;
    my $force  = shift || 0;

=pod

Given a client object and a planet ID, orcishly returns the excavator data from 
the arch min as a hashref.

If there's no arch min, returns an empty hashref.

If the third arg, $force, is passed as a true value, the arch min is 
forcefully re-scanned, ignoring any data that might already be in the cache.

=cut

    my $fm_cache = $cont->resolve( service => 'Cache/fast_mmap' );
    my $excav_data_key = join ':', (session('login_name'), $client->name, 'planet', $pid, 'excav_data');

    my $excav_data = {};
    unless( $force ) {
        if( $excav_data = $fm_cache->get($excav_data_key) ) {
            return $excav_data;
        }
    }

    my $excavs = get_excavator_data($client, $pid);
    unless ( @$excavs ) {
        ### Probably no arch min.
        return $excav_data;
    }

    my $planet = get_planet($client, $pid);
    my $planet_info = [];

    my $info  = [];
    my $data  = [];
    foreach my $e(@$excavs) {
        push @$data, [$e->{'body'}{x}, $e->{'body'}{y}];
        push @$info, "$e->{'body'}{'name'} ($e->{'body'}{x}, $e->{'body'}{y}) - Artifact: $e->{'artifact'}, Glyph: $e->{'glyph'}, Plan: $e->{'plan'}, Resource: $e->{'resource'} ";

        if( $e->{'body'}{'id'} == $planet->id ) {
            push @$planet_info, "$e->{'body'}{'name'} ($e->{'body'}{x}, $e->{'body'}{y}) - Artifact: $e->{'artifact'}, Glyph: $e->{'glyph'}, Plan: $e->{'plan'}, Resource: $e->{'resource'} ";
        }
    }

    $excav_data = {
        ### Negative entries are displayed automatically.
        ###
        ### When a given body appears in both entries, as the planet will, the 
        ### icon color will be that of the higher-numbered entry.
        ###
        ### With the planet entry at -1 and the Excavators entry at -2, the 
        ### planet entry's color will therefore display over top of the 
        ### Excavators entry's color (for the planet icon only).  Resulting in 
        ### the planet's icon showing up differently than the Excavators entry 
        ### does.  Which is what we want.
        ###
        ### If those numbers were reversed, the planet would display with the 
        ### Excavators icon on top, resulting in its displaying in exactly the 
        ### same color as the rest of the (remote) excavators, which is not 
        ### what we want.
        -1 => {
            label => $planet->name,
            info => $planet_info,
            data => [ [$planet->x, $planet->y] ],
        },
        -2 => {
            label => 'Excavators',
            info  => $info,
            data  => $data,
        }
    };

    $fm_cache->set($excav_data_key, $excav_data, '1 week');
    return $excav_data;
}#}}}
sub get_probe_data {#{{{
    my $client = shift;
    my $pid    = shift;

=pod

Given a client object and a planet ID, returns the probe data from the 
observatory as an AoH:

 $rv = [
    {
        id => 1234,
        name => 'Sol',
        color => 'yellow',
        x => 10,
        y => 20,
        z => -3,    # This is documented, but I have no idea what it's for on a 2-d map.
        bodies => [
            Documented as "see get_status in Bodies".  I assome another AoH of 
            orbiting bodies.
        ]
    },
    {
        ...more of the same...
    }
 ];

If there's no observatory, returns an empty arrayref.

THIS ATTEMPTS NO CACHING.  The probe data returned will always be fresh.

=cut

    my $stars = [];

    my $obs = get_buildings($client, $pid, 'Observatory');
    my($id, $obs_hr) = each %$obs;
    return $stars unless $id =~ /^\d+$/;
    my $type_arg = substr $obs_hr->{'url'}, 1;   # remove the leading slash from the url
    my $obs_obj = webcall($client, 'building', [id => $id, type => $type_arg]);

    my $page = 0;

    PAGE:
    while(1) {
        $page++;
        
        my $stars_call = webcall($obs_obj, 'get_probed_stars', [$page]);
        last PAGE unless $stars_call and ref $stars_call eq 'HASH';
        my $num_this_page = scalar @{$stars_call->{'stars'}};
        last PAGE unless $num_this_page;
        if( defined $stars_call->{'stars'} ) {
            push @$stars, @{$stars_call->{'stars'}};
        }
        last PAGE if( $num_this_page < 25 );
    }

    return $stars;
}#}}}
sub get_probe_map_data {#{{{
    my $client = shift;
    my $pid    = shift;
    my $force  = shift || 0;

=pod

Given a client object and a planet ID, orcishly returns the probe data from 
the observatory as a hashref.

If there's no observatory, returns an empty hashref.

If the third arg, $force, is passed as a true value, the observatory is 
forcefully re-scanned, ignoring any data that might already be in the cache.

=cut

    my $fm_cache = $cont->resolve( service => 'Cache/fast_mmap' );
    my $probe_data_key = join ':', (session('login_name'), $client->name, 'planet', $pid, 'probe_data');

    my $probe_data = {};
    unless( $force ) {
        if( $probe_data = $fm_cache->get($probe_data_key) ) {
            return $probe_data;
        }
    }

    my $stars = get_probe_data($client, $pid);
    unless ( @$stars ) { ### Probably no observatory.
        return $probe_data;
    }

    my $label = $client->name;
    my $info  = [];
    my $data  = [];
    foreach my $s(@$stars) {
        push @$info, "$s->{'name'} ($s->{x}, $s->{y})";
        push @$data, [$s->{x}, $s->{y}];
    }

    $probe_data = {
        ### The "-1" simply needs to be negative so this single entry will 
        ### display automatically on the map.
        -1 => {
            label => $label,
            info  => $info,
            data  => $data,
        }
    };

    $fm_cache->set($probe_data_key, $probe_data, '1 week');
    return $probe_data;
}#}}}
sub get_ships {#{{{
    my $client = shift;
    my $pid    = shift;

=pod

Given a client object and a planet ID, orcishly returns the ships from the 
planet object.  Ships are returned sorted and ordered by task, see 
sort_and_order_ships() for example rv structure.

=cut

    my $fm_cache = $cont->resolve( service => 'Cache/fast_mmap' );
    my $ns     = session('login_name');
    my $key    = join ':', ($ns, $client->name, 'planet', $pid, 'ships');

    my $planet = get_planet($client, $pid);

    my $ships = $fm_cache->compute($key, '1 hour', sub {
        my $ships = $planet->get_ships();
        return sort_and_order_ships( $ships );
    });
    return $ships;
}#}}}
sub get_body_names {#{{{
    my $c = shift;

=pod

Given a client object, orcishly returns a hashref of bodies belonging to the 
empire identified by $client->name.  Keys are body names, values are body IDs.

The returned hashref will include both planet and space station names.

=cut

    my $fm_cache = $cont->resolve( service => 'Cache/fast_mmap' );
    my $key    = join ':', (session('login_name'), $c->name, 'bodies', 'hashrefs');

    my $bodies_hr = $fm_cache->compute($key, '1 day', sub {
        $c->planets_names;
    });
    return $bodies_hr;
}#}}}
sub get_spies {#{{{
    my $client = shift;
    my $pid    = shift;
    my $fresh  = shift;

=pod

Given a client object and a planet ID, orcishly returns the planet's spies.

If you plan to use any DBIC functions associated with a spy, like looking up 
his SpyPrefs record (views/planets/spies.tt _is_ doing this), send a true value 
as the third arg to ensure you're not requesting cached spies.  Cached database 
handles are A Bad Thing.

=cut

    my $fm_cache = $cont->resolve( service => 'Cache/fast_mmap' );
    my $ns     = session('login_name');
    my $key    = join ':', ($ns, $client->name, 'planet', $pid, 'spies');

    my $spies = $fm_cache->compute($key, '6 hours', sub {
        my $planet = get_planet($client, $pid);
        my $spies = $planet->get_spies();
        foreach my $id( keys %$spies ) {
            my $hr = $spies->{$id};
            ### This is the DBIC SpyPrefs record.  It's an active DBI 
            ### connection and cannot be cached.  We don't need it here, so 
            ### dispose of it and cache the bitch.
            $hr->{'planned_task'} = {
                id   => $hr->{pref_record}->task->id,
                name => $hr->{pref_record}->task->name
            };
            delete $hr->{'pref_record'};
        }
        $spies;
    });
    return $spies;
}#}}}
sub get_ss_incoming {#{{{
    my $c   = shift;
    my $pid = shift;
    
    my $fm_cache = $cont->resolve( service => 'Cache/fast_mmap' );
    my $key      = join ':', ('space_station_incoming', $pid);

    my $inc = $fm_cache->compute($key, {}, sub {
        my $inc_page = 0;
        my $ss = get_planet($c, $pid);
        my $inc = [];

        my $ps = get_buildings($c, $pid, 'Police Station');
        my($id, $ps_hr) = each %$ps;

        if( ref $ps_hr eq 'HASH' ) {
            my $ps = get_building_object($c, $pid, $ps_hr);
            INC:
            while(1) {
                $inc_page++;
                my $rv = webcall($ps, 'view_foreign_ships', [$inc_page]);
                last INC unless scalar @{ $rv->{'ships'} };
                push @$inc, @{ $rv->{'ships'} };
            }
        }
        return $inc;
    });

    return $inc;
}#}}}
sub init_tvars {#{{{
    my $cont  = shift || get_container( q{}, q{} );
    my $tvars = shift || {};

    (ref $tvars eq 'HASH') or die "Unexpected value for tvars.";

=pod

Sets some common variables I want available to all templates.  Returns a 
hashref containing those variables; this hashref is suitable for passing to 
template() as its second argument.
 
 my $t_vars = init_tvars();

If you've already begun initializing your $t_vars (perhaps by calling another
init-type sub that returns a hashref), you can pass that hashref here:

 my $t_vars = ...other code setting up template vars...
 $t_vars = init_tvars( $t_vars );

However, care must be taken with that, as init_tvars() is not doing any defined 
checks before setting its values; if your already-existing hashref contains keys 
set by init_tvars, they will be overwritten.

The always-set variables are:

=over 4

=item logged_in

Set to '1' if the user has logged in.

=item roles_rs

A DBIC resultset of user roles.

=item logins_rs

A DBIC resultset of user logins.

=item user

The DBIC Login record for the current user

=back

=cut

    my $users_schema = $cont->resolve( service => 'Database/users_schema' );
    if( my $n = session('login_name') and session('logged_in') ) {
        $tvars->{'logged_in'} = 1;
        $tvars->{'user'} = $users_schema->resultset('Login')->find({ username => $n });
    }
    $tvars->{'roles_rs'}  = $users_schema->resultset('Role'); 
    $tvars->{'logins_rs'} = $users_schema->resultset('Login'); 

    return $tvars;
}#}}}

sub sort_and_order_ships {#{{{
    my $ships = shift;

=pod

 my $ships   = $lt->get_ships($space_port_object);
 my $ordered = sort_and_order_ships($unordered);

$ordered is now...

 $ordered = {
  Docked => {
   type:speed:size => {
    count => ,
    name => ,
    speed => ,
    size => ,
    ... rest of ship hashref...
   }
  },
  Building => {
   type:speed:size => {
    ... rest of ship hashref...
   }
  },
  Defend => {
   type:speed:size => {
    ... rest of ship hashref...
   }
  },
  Travelling => {
   type:speed:size => {
    ... rest of ship hashref...
   }
  },
 }

Identical ships (same type, speed, cargo size) get grouped together, 
incrementing 'count'.

The hashref for any given grouping of type . speed . size represents the last 
ship of its type . speed . size encountered.  This means that the 'id' key will 
be the ship ID of that last ship.

So if your grouping has more than one ship, the ID value won't be too useful.  

=cut

    my $ordered_ships = {};
    while(my($id, $hr) = each %$ships) {
        my $key = join ':', @{$hr}{qw(type_human speed hold_size)};
        $hr->{'count'} = $ordered_ships->{$hr->{'task'}}{$key}{'count'} // 0;
        $ordered_ships->{$hr->{'task'}}{$key} = $hr;
        $ordered_ships->{$hr->{'task'}}{$key}{'count'}++;
    }
    return $ordered_ships;
}#}}}
sub webcall {#{{{
    my( $obj, $meth, $args ) = @_;
    (ref $args eq 'ARRAY') or $args = [];

=pod

Similar to $client->call, but understands how to deal with exceptions in a web context.  
Rather than sleeping for a minute and then re-attempting the call, this simply sets the 
flash and returns undef.

The calling route can decide if it wants to proceed producing its own page or redirect 
somewhere safe.

This is currently looking for the Slow Down! RPC limit error, and will set the flash 
appropriately if that happens.  On any other error, the flash is set to a generic 
error response.  

When the generic error hits, you can view source and search for "ERRORHERE" - the actual 
error will be listed under that string, in HTML comments.

=cut

    my(@rv) = try {
        $obj->$meth(@$args);
    }
    catch {
        if( $_->code == 1010 ) {
            flash error => "Slow down!  60 RPCs allowed per minute; you're over.";
        }
        elsif( $_->code == -32603 ) {
            flash error => "Internal Game Server Error.  I don't know why this happens.  Wait a minute and try your request again.";
        }
        else {
            flash error => qq{
                1 Unknown error encountered from game server.  If this is the first time you're seeing 
                this, wait a sec and try again.
                <!-- ERRORHERE
                $_
                -->

            };
        }
        #my $us = var 'users_schema';
        my $us = $cont->resolve( service => 'Database/users_schema' );
        $us->resultset('Message')->create({
            from_id => 1,
            to_id   => 1,
            message => ("Webcall error: --" . $_->code . "-- --" . $_->text. "--"),
        });
        forward '/';
    };
    return(wantarray) ? @rv : $rv[0]; 
}#}}}

1;
 
__END__
 vim: fdm=marker
