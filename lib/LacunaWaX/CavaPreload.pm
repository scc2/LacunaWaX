use v5.14;
use warnings;
use utf8;

=pod

It seems like Cava Packager is scanning the source code for obvious things 
like "use Foo;" to figure out which modules it needs to package up.

This means that it (Cava) misses modules that have been loaded dynamically; 
these modules need to be explicitly use'd so Cava knows enough to load them, 
which is why this module exists.

This module needs to be explicitly use'd somewhere along the chain of anything 
that gets packaged by Cava.  Right now, that means LacunaWaX.pm and 
LacunaWaX/Schedule.pm - all of the packaged programs are using one or the 
other of those two modules.

=cut

package LacunaWaX::CavaPreload {

    use B::Hooks::EndOfScope::XS;
    use LacunaWaX::Roles::ScheduledTask;
    use Variable::Magic;

    use DateTime::TimeZone::Local::Unix;
    use DateTime::TimeZone::Local::Win32;

    ### Ugh.
    ###
    ### The only way to allow Cava to be able to load the correct TZ is to 
    ### pre-load all of them.
    ### 
    ### To top it off, the hash in DateTime::TimeZone::Local::Win32 that's 
    ### meant to map Win32 TZs to Olson DB TZs has several mistakes in the 
    ### values:
    ###     Asia/Calcutta.pm simply does not exist
    ###     America/Indianapolis should be America/Indiana/Indianapolis
    ###
    ### etc - there were two or three others like this.  I've corrected the 
    ### use statements below so they won't blow up, but since the hash in the 
    ### DateTime module is wrong, if any users live in those broken timezones, 
    ### attempting to get their local TZ will fail.  So be sure to wrap any 
    ### attempts to determine the TZ in try/catch and default to UTC if all 
    ### else fails.
    use DateTime::TimeZone::Asia::Kabul;
    use DateTime::TimeZone::America::Anchorage;
    use DateTime::TimeZone::Asia::Riyadh;
    use DateTime::TimeZone::Asia::Muscat;
    use DateTime::TimeZone::Asia::Baghdad;
    use DateTime::TimeZone::America::Argentina::Buenos_Aires;
    use DateTime::TimeZone::Asia::Yerevan;
    use DateTime::TimeZone::America::Halifax;
    use DateTime::TimeZone::Australia::Darwin;
    use DateTime::TimeZone::Australia::Sydney;
    use DateTime::TimeZone::Asia::Baku;
    use DateTime::TimeZone::Atlantic::Azores;
    use DateTime::TimeZone::Asia::Bangkok;
    use DateTime::TimeZone::Asia::Dhaka;
    use DateTime::TimeZone::Asia::Shanghai;
    use DateTime::TimeZone::America::Regina;
    use DateTime::TimeZone::Atlantic::Cape_Verde;
    use DateTime::TimeZone::Asia::Yerevan;
    use DateTime::TimeZone::Australia::Adelaide;
    use DateTime::TimeZone::America::Chicago;
    use DateTime::TimeZone::America::Regina;
    use DateTime::TimeZone::Asia::Almaty;
    use DateTime::TimeZone::America::Cuiaba;
    use DateTime::TimeZone::Europe::Prague;
    use DateTime::TimeZone::Europe::Belgrade;
    use DateTime::TimeZone::Pacific::Guadalcanal;
    use DateTime::TimeZone::America::Chicago;
    use DateTime::TimeZone::America::Mexico_City;
    use DateTime::TimeZone::Asia::Shanghai;
    use DateTime::TimeZone::Africa::Nairobi;
    use DateTime::TimeZone::Australia::Brisbane;
    use DateTime::TimeZone::Europe::Minsk;
    use DateTime::TimeZone::America::Sao_Paulo;
    use DateTime::TimeZone::America::New_York;
    use DateTime::TimeZone::Africa::Cairo;
    use DateTime::TimeZone::Asia::Yekaterinburg;
    use DateTime::TimeZone::Pacific::Fiji;
    use DateTime::TimeZone::Europe::Helsinki;
    use DateTime::TimeZone::Asia::Tbilisi;
    use DateTime::TimeZone::Europe::Athens;
    use DateTime::TimeZone::Europe::London;
    use DateTime::TimeZone::America::Godthab;
    use DateTime::TimeZone::Europe::Athens;
    use DateTime::TimeZone::Pacific::Honolulu;
    use DateTime::TimeZone::Asia::Tehran;
    use DateTime::TimeZone::Asia::Jerusalem;
    use DateTime::TimeZone::Asia::Amman;
    use DateTime::TimeZone::Asia::Kamchatka;
    use DateTime::TimeZone::Asia::Seoul;
    use DateTime::TimeZone::Asia::Magadan;
    use DateTime::TimeZone::Indian::Mauritius;
    use DateTime::TimeZone::America::Mexico_City;
    use DateTime::TimeZone::America::Chihuahua;
    use DateTime::TimeZone::Atlantic::South_Georgia;
    use DateTime::TimeZone::Asia::Beirut;
    use DateTime::TimeZone::America::Montevideo;
    use DateTime::TimeZone::Africa::Casablanca;
    use DateTime::TimeZone::America::Denver;
    use DateTime::TimeZone::America::Chihuahua;
    use DateTime::TimeZone::Asia::Rangoon;
    use DateTime::TimeZone::Asia::Novosibirsk;
    use DateTime::TimeZone::Africa::Windhoek;
    use DateTime::TimeZone::Asia::Kathmandu;
    use DateTime::TimeZone::Pacific::Auckland;
    use DateTime::TimeZone::America::St_Johns;
    use DateTime::TimeZone::Asia::Irkutsk;
    use DateTime::TimeZone::Asia::Krasnoyarsk;
    use DateTime::TimeZone::America::Los_Angeles;
    use DateTime::TimeZone::America::Santiago;
    use DateTime::TimeZone::America::Los_Angeles;
    use DateTime::TimeZone::America::Tijuana;
    use DateTime::TimeZone::Asia::Karachi;
    use DateTime::TimeZone::America::Asuncion;
    use DateTime::TimeZone::Europe::Prague;
    use DateTime::TimeZone::Europe::Paris;
    use DateTime::TimeZone::Europe::Moscow;
    use DateTime::TimeZone::America::Cayenne;
    use DateTime::TimeZone::America::Bogota;
    use DateTime::TimeZone::America::Guyana;
    use DateTime::TimeZone::Pacific::Apia;
    use DateTime::TimeZone::Asia::Riyadh;
    use DateTime::TimeZone::Asia::Bangkok;
    use DateTime::TimeZone::Asia::Singapore;
    use DateTime::TimeZone::Africa::Harare;
    use DateTime::TimeZone::Asia::Colombo;
    use DateTime::TimeZone::Asia::Damascus;
    use DateTime::TimeZone::Australia::Sydney;
    use DateTime::TimeZone::Asia::Taipei;
    use DateTime::TimeZone::Australia::Hobart;
    use DateTime::TimeZone::Asia::Tokyo;
    use DateTime::TimeZone::Pacific::Tongatapu;
    use DateTime::TimeZone::Asia::Ulaanbaatar;
    use DateTime::TimeZone::America::Indiana::Indianapolis;
    use DateTime::TimeZone::America::Phoenix;
    use DateTime::TimeZone::UTC;
    use DateTime::TimeZone::America::Caracas;
    use DateTime::TimeZone::Asia::Vladivostok;
    use DateTime::TimeZone::Australia::Perth;
    use DateTime::TimeZone::Africa::Luanda;
    use DateTime::TimeZone::Europe::Berlin;
    use DateTime::TimeZone::Europe::Warsaw;
    use DateTime::TimeZone::Asia::Karachi;
    use DateTime::TimeZone::Pacific::Guam;
    use DateTime::TimeZone::America::Rio_Branco;
    use DateTime::TimeZone::Asia::Yakutsk;
}

1;
