
The modules in ./ are not actually accessible to the main app, and are not meant 
to be.  They're experiments with various Wx controls.  

To use any of them:
    $ cp FILE_TO_PLAY_WITH.pm ../Test.pm

    Then edit LacunaWaX::MainFrame::MenuBar.pm; set show_test to a default value 
    of 1.

    The next time LacunaWaX is run, the test will be available via the Tools 
    menu.

Make sure that one of these files always exists as ../Test.pm, since the app is 
using that module, and will explode if it suddenly turns up missing.



To create a new test dialog:
    - Copy ./EnumerateWindows.pm to a new file, and rename it as appropriate
        - eg MyNewTestName.pm
        - EnumerateWindows is using the new, "correct" style of extending 
          Wx::Dialog.
    - DO NOT CHANGE THE PACKAGE NAME INSIDE YOUR NEW FILE
        - It needs to remain "LacunaWaX::Dialog::Test".

    - Copy your new file to ../Test.pm, overwriting whatever's currently there.
        - fool with the code as needed

    - COPY ../Test.pm BACK TO ./MyNewTestName.pm
        - Don't forget to add that to svn
        


