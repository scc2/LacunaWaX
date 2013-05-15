LacunaWaX
=========

A GUI for The Lacuna Expanse

Copyright 2012-2013 Jonathan D. Barton (tmtowtdi@gmail.com)

See NOTES for developer notes.

STATUS
------
Installing and running the executable on Windows is reasonably straightforward and stable.
Running from source takes a bit of tweaking.  See the wiki for what information there is.

CAUTION
-------

LacunaWaX stores game account passwords in plain text.  Guard your lacuna\_app.sqlite file \- handing it to someone else for any reason is the same as handing that person not only your own account password, but also all of your recorded sitter passwords.

It is safe to send your lacuna\_log.sqlite file to someone else for debugging help if needed, as it contains no passwords.

RUNNING FROM SOURCE
-------------------

Quite a few non-core Perl modules are required, and no make process exists yet, so pre-requisite modules will need to be installed manually.

### REQUIREMENTS

This list is not yet exhaustive.

* Perl >= v5.14
* Archive::Zip
* Bread::Board
* Browser::Open
* CHI
* DateTime
* File::Which
* LWP::UserAgent
* Moose
* MooseX::NonMoose
* Try::Tiny
* URI
* Wx

### Run
    $ perl bin/LacunaWaX.pl

Install any modules it complains about missing, and add them to the list above.

Once all pre-reqs have been installed, that command will start the GUI.

