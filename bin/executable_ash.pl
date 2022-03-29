#!/usr/bin/perl

#-----------------------------------------------------------------------------
# ash - AppleScript Shell
#   allows you to use AppleScript commands interactively like in the Unix shell 
#
# Copyright (C) 2006  Cameron Hayne - macdev@hayne.net
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#-----------------------------------------------------------------------------

use strict;
use warnings;
use Time::HiRes qw(time);

# Global variables:
#------------------

#$version = "0.4";    # Jan 26, 2002,  first released version
#$version = "0.42";   # Nov  9, 2005,  added considering & ignore commands,
                      #                added to the help notes
#$version = "0.43";   # Sept 22, 2006, added execution of ~/.ashrc
#$version = "0.44";   # Sept 25, 2006, added -source command,
                      #                now uses ReadLine module,
                      #                now possible to use shebang scripts
#$version = "0.46";   # Sept 26, 2006, added -echo command
#$version = "0.51";   # Sept 28, 2006, added the following special commands:
                      #                -end, -rerun, -show, -editor,
                      #                -clearSub, -clearScript, -clearAll,
                      #                -cd, -pwd, -ls, -!
                      #                added handling of 'with' & 'script',
                      #                added "bugs" section to help,
                      #                made subroutines & script objects persist
#$version = "0.52";   # Sept 30, 2006, better handling of abbreviations, 
                      #                better quote escaping for -editor command
                      #                renamed the "-end" command to "-clear",
                      #                now echos the pending commands
#$version = "0.53";   # Oct  2, 2006,  handling of 'using terms from',
                      #                now shows location of AppleScript errors
#$version = "0.54";   # Oct  3, 2006,  avoid invoking osacompile for comments,
                      #                fixed some bugs: zombies, subs, quotes
#$version = "0.55";   # Oct 27, 2006,  added -osaMethod command that provides
                      #                a choice of implementation methods
                      #                and made 'macosasimple' the default,
                      #                added -installMan command,
                      #                fixed some bugs: scripts, batch mode
#$version = "0.56";   # Oct 28, 2006,  added -timing command,
                      #                fixed the 'display dialog' problem
                      #                changed -installMan to -createMan
                      #                handling of multiline comments (* .. *)
                      #                fixed non-interactive scripts
#$version = "0.57";   # Oct 31, 2006,  cleaned up command handling,
                      #                fixed bugs with 'if .. else',
                      #                improved error handling,
                      #                added '-f' option to the "-cd" command
#$version = "0.58";   # Nov  3, 2006,  make sure that error msgs go to STDERR,
                      #                fix few more "no user interaction" cases,
                      #                made special commands case-insensitive,
                      #                added command-line options,
                      #                fixed bug with batch mode subroutines,
                      #                allow use of -abbrev to define specials,
                      #                batch mode sourcing via -batch
#$version = "0.59";   # Nov  6, 2006,  handle AppleScript line continuations,
                      #                clean up of command processing
my $version = "0.60"; # Nov  8, 2006,  first cut at property/variable handling,
                      #                bug fix re line continuations,
                      #                added -read command,
                      #                first cut at a tracing facility

# -----------------------------------------------------------------------------


my $ash = "ash"; # the name of this Perl script
my $ashLongName = "AppleScript Shell";
my $ashrc = ".$ash" . "rc"; # name of the 'rc' file read at startup

my $authorName = "Cameron Hayne";
my $authorEmail = "macdev\@hayne.net";
my $ashWebSite = "http://hayne.net/MacDev/Ash/";

# osamethod: method used to compile & run AppleScripts
#            set via the -osaMethod command
my $defaultOsaMethod = "macosasimple";
my $osaMethod = $defaultOsaMethod;
my %osaMethods = (
                  'osascript'    => "Uses the /usr/bin/osascript tool",
                  'macosasimple' => "Uses the Perl module \"Mac::OSA::Simple\"",
                  'macperl'      => "Uses the Perl module \"Mac::Perl\"",
                 );
my $availOsaMethodsNames = join(", ", sort keys %osaMethods);
my $availOsaMethodsDesc = join("\n",
                               map { sprintf(" %15s: %s",
                                              $_, $osaMethods{$_}) }
                               sort keys %osaMethods);

# interactive: true if no files passed as command-line args
my $interactive;

# useReadLine: whether to use the Term::ReadLine module
#              set via the -useReadLine command
my $useReadLine = 1;

# nogreeting: set via the -nogreeting option
my $nogreeting = 0;

# quiet: set via the -quiet option
my $quiet = 0;

# norc: determines if ~/.ashrc is read
#       set via the -norc option
my $norc = 0;

# oneoff: set via the -oneoff option
my $oneoff = 0;

# debugLevel: set via the the -debug option or the -debug command 
my $debugLevel = 0;

# traceLevel: set via the -trace option
#             or via --trace directives in the AppleScript
my $traceLevel = 0;

# timing: determines if timing info is printed
#         set via the -timing option or the -timing command
my $timing = 0;

# we go into modes for the AppleScript commands like 'tell', 'repeat', etc
my @modes = ();
my $indentPerMode = 4; # indent commands by 4 spaces

my $batchMode = 0;

# we store all the commands when in a mode 
my @currCommands = ();

# we also keep track of the names of top-level script objects, subroutines,
# properties, and variables that are being defined in the current AppleScript
my %currScriptObjs = ();
my %currSubs = ();
my %currProps = ();
my %currVars = ();

# keep track of the number of AppleScripts run (e.g. for "one off" mode)
my $numApplescriptsRun = 0;

# keep track of the number of errors encountered while processing latest command
my $numErrors = 0;

# user-supplied script objects, subroutines, properties, and variables are
# persistent between commands - they are written into the AppleScript
# before passing it off for execution
my %userScriptObjs = ();
my %userSubs = ();
my %userProps = ();
my %userVars = ();

# the special commands and the first words of AppleScript commands are
# registered at program startup and info stored in the following hashes:
my %specialCmds = ();
my %applescriptCmds = ();

# the special commands (prefaced with "-"):
my $specialPrefix  = "-";
my $helpCmd        = $specialPrefix . "help";
my $exitCmd        = $specialPrefix . "exit";
my $rerunCmd       = $specialPrefix . "rerun";
my $abbrevCmd      = $specialPrefix . "abbrev";
my $unabbrevCmd    = $specialPrefix . "unabbrev";
my $batchCmd       = $specialPrefix . "batch";
my $endBatchCmd    = $specialPrefix . "end";
my $sourceCmd      = $specialPrefix . "source";
my $echoCmd        = $specialPrefix . "echo";
my $readCmd        = $specialPrefix . "read";
my $showCmd        = $specialPrefix . "show";
my $clearCmd       = $specialPrefix . "clear";
my $clearSubCmd    = $specialPrefix . "clearSub";
my $clearScriptCmd = $specialPrefix . "clearScript";
my $clearVarCmd    = $specialPrefix . "clearVar";
my $clearAllCmd    = $specialPrefix . "clearAll";
my $editorCmd      = $specialPrefix . "editor";
my $cdCmd          = $specialPrefix . "cd";
my $pwdCmd         = $specialPrefix . "pwd";
my $lsCmd          = $specialPrefix . "ls";
my $unixCmd        = $specialPrefix . "!";
my $createManCmd   = $specialPrefix . "createMan";
# the following are not documented (intended mostly for developer use)
my $useReadLineCmd = $specialPrefix . "useReadLine";
my $debugCmd       = $specialPrefix . "debug";
my $timingCmd      = $specialPrefix . "timing";
my $osaMethodCmd   = $specialPrefix . "osaMethod";
# -----------------------------------------------------

# In order to implement the "-echo" command, we add a subroutine named
# "ashEchoSub" to the AppleScript that is supplied by the user.
my $echoSubName = "ashEchoSub";
my $echoSub = <<EOT;
on $echoSubName(value)
    try
        set strValue to quoted form of (value as string)
    on error
        set strValue to ""
    end try
    do shell script "echo " & strValue & " > /dev/tty"
end $echoSubName
EOT

# In order to implement the "-read" command, we add a subroutine named
# "ashReadSub" to the AppleScript that is supplied by the user.
my $readSubName = "ashReadSub";
my $readSub = <<EOT;
on $readSubName(options)
    do shell script "read " & options & "; echo \$REPLY"
end $readSubName
EOT

# In order to implement "trace mode", we add a subroutine named
# "ashTraceSub" to the AppleScript that is supplied by the user.
my $traceSubName = "ashTraceSub";
my $traceSub = <<EOT;
on $traceSubName(command, hasResult)
    if hasResult
        try
            set resultStr to "Result: " & quoted form of (result as string)
        on error
            -- get here if there is no result
            set hasResult to false
        end try
    end if
    
    set commandStr to quoted form of command
    set echo1 to "echo " & commandStr & " > /dev/tty"
    if hasResult
        set echo2 to "echo " & resultStr  & " > /dev/tty"
        do shell script echo1 & ";" & echo2
    else
        do shell script echo1
    end if
    
    -- pause until some key is pressed or a second has elapsed
    try
        do shell script "read -s -n1 -t1"
    on error
        -- get here if no key pressed before the timeout
    end try
end $traceSubName
EOT
                      
# The following is used by the "-editor" command
# You can change it to open your preferred AppleScript editor
my $editor = "Script Editor";
my $editorSubName = "ashEditorSub";
my $editorSub = <<EOT;
on $editorSubName(scriptText)
    tell application "$editor"
        activate
        make new document
        set the text of the front document to (scriptText)
    end tell
end $editorSubName
EOT

# name of the Terminal application where this script is running
# (there should be some way to get this from System Events's process list)
my $terminalAppName = "Terminal";

# info about the user who is running this script:
my $homeDir = $ENV{'HOME'};
my $username = $ENV{'LOGNAME'};

# the user can define abbreviations to save typing
my %abbreviations = ();
# You can add "permanent" abbreviations here or in ~/.ashrc
$abbreviations{'-ls'} = "-! ls";    # documented - do not change
$abbreviations{'-pwd'} = "-! pwd";  # documented - do not change
# uncomment the following as desired
#$abbreviations{'tapp'} = "tell application";
#$abbreviations{'tf'} = "tell application \"Finder\"";
#$abbreviations{'tse'} = "tell application \"System Events\"";
#$abbreviations{'dd'} = "tell application \"Terminal\" to display dialog";
#$abbreviations{'doCmdC'} = "tell application \"System Events\" to keystroke \"c\" using command down";
#$abbreviations{'sayHi'} = "say \"Hi $username\"";

# The line-continuation indicator in AppleScript is entered as Option-Return
# Empirically, I have determined that this is either 0xC2AC or 0xC2
# (I'm guessing it depends on the encoding or something)
my $lineContCharPat = "(\xC2\xAC|\xC2)";

# idPat: the regex for a valid identifier
my $idPat = '[A-Za-z]\w*';


# Help text and other documentation:
# ----------------------------------
my %helpTitle;
my %help;
my $suggestedManDir = "/usr/share/man/man1/";

$helpTitle{'topics'} = "Help Topics";
$help{'topics'} = <<EOT; 
intro         abbrev          source         echo           input
show          subroutines     variables      comments       batch
startup       options         standAlone     unix           commandLine
help          man             all            topics
license       version         bugs
EOT

$help{'help'} = <<EOT;
The "$helpCmd" command displays the text you are reading now.
If you supply one of the following topic names as an argument,
the "$helpCmd" command will show the help text for that topic,
otherwise it will show the "intro" section.
It is strongly recommended that you read all the help topics
to get an understanding of the capabilities of this shell.
You can see all of the help text via the command "$helpCmd all".
EOT

$help{'man'} = <<EOT;
The "$createManCmd" command will create a 'man' page file (named "$ash.1")
in the current directory. You will need to move this file to one of the
directories in your MANPATH - e.g. to "$suggestedManDir".
This provides an alternative access to this documentation via 'man $ash'.
EOT

$help{'description'} = <<EOT;
This "$ashLongName" program is intended for interactive use in a
manner similar to that of the standard Unix shells.
You can execute simple one-line AppleScript commands by just typing them
and hitting 'return'. The AppleScript command will be executed immediately.

But many AppleScript commands are multiple lines
(e.g. 'tell' or 'repeat' commands).
For these, the "$ashLongName" will go into a mode where
it stores your commands until you enter the corresponding 'end' command
at which point your multiple-line AppleScript command will be executed.
The prompt will show you what mode you are in.

You can exit this shell at any time by entering the command "$exitCmd".
If you want to abort a pending multi-line command without exiting from the
shell, use the "$clearCmd" command.
EOT

$help{'commandSummary'} = <<EOT;
There are several special commands (starting with "$specialPrefix") that are
interpreted by this shell: 
$helpCmd\t\tshow help text
$exitCmd\t\texit from this shell
$abbrevCmd\t\tdefine an abbreviation (to save typing)
$unabbrevCmd\tremove an abbreviation
$echoCmd\t\techo the value of an AppleScript expression
$readCmd\t\tread from the keyboard into an AppleScript variable
$sourceCmd\t\texecute commands from a file
$batchCmd\t\tstart "batch mode"
$endBatchCmd\t\tend "batch mode"
$showCmd\t\tshow the current AppleScript
$editorCmd\t\tsend the current AppleScript to "$editor"
$rerunCmd\t\trerun the current AppleScript
$clearCmd\t\tclears the current AppleScript
$clearSubCmd\tremove a specified subroutine
$clearScriptCmd\tremove a specified script object
$clearVarCmd\tremove a specified variable or property
$clearAllCmd\tclears all commands (removes all subs, scriptObjs, props, vars)
$cdCmd\t\tchange working directory
$pwdCmd\t\tshow the current working directory
$lsCmd\t\tlist the files in a directory
$unixCmd\t\texecute an arbitrary Unix command
$createManCmd\tcreate a 'man' page file for '$ash'

The reason for the "$specialPrefix" at the start of each command name is to
ensure that these commands don't collide with some AppleScript syntax.
Even though some of the above command names include uppercase characters,
the command processing is case-insensitive, so for example you could use
"${ \( lc($clearAllCmd) )}" instead of "$clearAllCmd".
EOT

$helpTitle{'abbrev'} = "Abbreviations";
$help{'abbrev'} = <<EOT;
You can save typing by defining abbreviations via the "$abbrevCmd" command
For example:
    $abbrevCmd strack some track of playlist "Library"
defines 'strack' as an abbreviation for 'some track of playlist "Library"'
so you could then issue the AppleScript command
    tell application "iTunes" to play strack
in order to play a random song from your iTunes library.
You can remove abbreviations via the command "$unabbrevCmd".
For example:
    $unabbrevCmd strack
would remove the above abbreviation.
You can remind yourself of the definition of the abbreviation named "strack"
by entering the command "$abbrevCmd strack".
You can see the current list of abbreviations by entering the command
"$abbrevCmd" (with nothing following it).
EOT

$helpTitle{'source'} = "Sourcing files with AppleScript commands";
$help{'source'} = <<EOT;
You can use the "$sourceCmd" command to execute the commands that are in
a specified file in the same manner as if these commands had been typed
interactively at the command prompt. This is another way of saving typing. 
For example, if you have some commands in the file "~/MyStuff/do_something",
you could run those commands via:
    $sourceCmd ~/MyStuff/do_something
    
Note in particular that any subroutines defined in that file will persist and
be available for use in interactive commands. (See: $helpCmd subroutines)
If you are using the "$sourceCmd" command to bring in a whole script for
executing, you probably want to go into "batch mode" first. As an alternative
to going into batch mode, sourcing the script file, then exiting batch mode,
you can supply the script filename as an argument to the "$batchCmd" command
(e.g. '$batchCmd ~/MyStuff/do_something'). This will go into batch mode, source
the specified file, then exit from batch mode automatically.
EOT

$helpTitle{'batch'} = "Running AppleScript commands in \"batch mode\"";
$help{'batch'} = <<EOT;
In the usual mode of operation, each AppleScript command that you enter
is executed immediately. (Multi-line commands (e.g. 'tell' or 'repeat') will
execute when the corresponding 'end' is entered.)
But sometimes you want to enter a bunch of AppleScript commands and then
have them all executed at once. The "$batchCmd" command allows you to do this
- it starts "batch mode" operation. AppleScript commands issued in this mode
are only executed when you leave batch mode via the "$endBatchCmd" command.
Unlike the case in normal one-command-at-a-time operation, subroutines and
script objects defined in batch mode do not remain active after the end
of batch mode.

If you supply a filename argument to the "$batchCmd" command, '$ash' will go
into batch mode, source the specified file, then automatically exit from
batch mode.
EOT

$helpTitle{'echo'} = "Results of AppleScript commands";
$help{'echo'} = <<EOT;
The result of the AppleScript command that was last executed will appear 
in the Terminal window without you having to do anything special.
But if you want to output the value of an intermediate AppleScript expression,
you can use the "$echoCmd" command. For example:
    tell application "Finder"
        set theSelection to selection
        set n to number of items in theSelection
        $echoCmd "number of items selected: " & n
        repeat with i from 1 to n
            set theItem to item i of theSelection as alias
            $echoCmd "item " & i & " is " & theItem
        end repeat
    end tell
    
This is especially useful when debugging an AppleScript.
The "$echoCmd" command is implemented by means of an AppleScript subroutine
"$echoSubName" which is included in the AppleScript before it is executed.
EOT

$helpTitle{'input'} = "Getting input from the user";
$help{'input'} = <<EOT;
The usual way to get input from the user in an AppleScript is to put up
a dialog of some sort. Since the AppleScripts run by '$ash' are in a different
environment than usual, using something like "display dialog" would result in
an error message saying "no user interaction allowed". In order to sidestep this
problem, '$ash' redirects all such user interaction to the Terminal application
by prefacing such commands with 'tell application "Terminal" to'. If you are
running '$ash' in some other terminal-type application, you will need to change
the Perl variable '\$terminalAppName' to reflect the name of your app.

An alternative way to get input from the user when running scripts in '$ash' is
to use the "$readCmd" command. For example '$readCmd n' will read characters
from the keyboard and put them into an AppleScript variable named "n". If you
are using this method of getting input from the user, you probably want to use
the "$echoCmd" command to display a prompt to tell the user what is expected.
EOT

$helpTitle{'show'} = "Examining the current AppleScript";
$help{'show'} = <<EOT;
The "$showCmd" command will display the text of the current AppleScript
(i.e. the text of a partially completed multi-line command 
   or that of the most recently executed command,
   plus any previously defined subroutines or script objects)
This is useful when you want to copy & paste that script elsewhere,
or just to review the commands you have entered and the existing subroutines
and script objects.
The "$editorCmd" command will activate Apple's "Script Editor"
and create a new document with the text of the current AppleScript.
The "$clearCmd" command will clear the current AppleScript.
You can rerun the current AppleScript via the "$rerunCmd" command.
EOT

$helpTitle{'subroutines'} = "Subroutines and Script Objects";
$help{'subroutines'} = <<EOT;
When you define a subroutine (starting with "on" or "to")
or a script object (starting with "script"), these pieces of code remain active
and are available for use in all subsequent commands.
I.e. all subroutines and script objects defined in the current session
are present in the AppleScript that is executed.
The "$showCmd" command will show you what subroutines and script objects
have been defined so far.

Since subroutines and script objects don't affect anything unless they are
invoked, you can generally just forget about the extraneous ones. But if you
want to clean house just to make things neater, there are a few commands
provided for this purpose.
The "$clearSubCmd" command will remove the subroutine specified as an argument.
For example, if you had previously defined a subroutine named "foo", then
"$clearSubCmd foo" would remove it.
The "$clearScriptCmd" command will remove the script object specified
as an argument. For example, if you had previously defined a script object
named "fred", then "$clearScriptCmd fred" would remove it.
The "$clearAllCmd" command will remove all previously defined subroutines,
script objects, properties, and variables as well as clearing the
current AppleScript.
EOT

$helpTitle{'variables'} = "Variables & Properties";
$help{'variables'} = <<EOT;
There is only preliminary support for top-level variables or properties.
If you define a top-level variable or property, it and its value will remain
active and be available for use in all subsequent commands in the same way that
subroutines and script objects persist after definition.
The "$clearVarCmd" command will remove the variable or property specified
as an argument.
It is often useful to use "batch mode" (via the "$batchCmd" command)
or to use a 'try' block when you are setting some variables at top level
that you want to use in some later statement.
EOT

$helpTitle{'comments'} = "Comments";
$help{'comments'} = <<EOT;
Any line starting with a hash (#) character is treated as a comment and thus
is completely ignored by '$ash'.
This parallels the commenting convention of the usual Unix shells
like 'bash' and 'tcsh'.
Of course the standard AppleScript commenting characters are also supported.
EOT

$help{'optionsStart'} = <<EOT;
The following options can be specified on the command-line that is used
to invoke '$ash':
EOT

$help{'nogreetingOption'} = <<EOT;
Disables the greeting message that is given when you start '$ash'
EOT

$help{'quietOption'} = <<EOT;
Stops '$ash' from outputing status messages in response to commands. This option
also disables the greeting message at startup.
EOT

$help{'norcOption'} = <<EOT;
Prevents the ~/$ashrc file from being read at startup.
(This is only useful when running interactively since stand-alone scripts do not
read the ~/$ashrc file at startup.)
EOT

$help{'oneoffOption'} = <<EOT;
Puts '$ash' into "one off" mode where '$ash' will automatically exit after
executing one AppleScript command. The ~/$ashrc file will still be read at
startup and AppleScript commands in that file don't count. It is often useful
to combine this option with "-quiet" (and possibly with "-norc") to get a
quick, clean way to run a single AppleScript command.
This option is ignored when running '$ash' non-interactively.
EOT

$help{'traceOption'} = <<EOT;
Enables "trace mode" for the execution of AppleScripts. In this mode, the
execution pauses after each AppleScript statement and the result from the
previous statement is displayed. Each statement will pause for one second before
continuing with the rest of the AppleScript. Pressing any key will stop it from
pausing and so if you want it to run freely, just hold a key down.
Trace mode is mostly useful when running scripts non-interactively.
EOT

$help{'debugOption'} = <<EOT;
Sets the debugLevel to the specified integer. Higher values result in more
debugging messages. Values higher than 1 will not likely be useful to anyone
other than the developer. (Default is 0)
EOT

$help{'timingOption'} = <<EOT;
Sets the timingLevel to the specified integer (should be either 0 or 1).
If the timingLevel is greater than zero, '$ash' outputs info about the time
taken to compile and execute the AppleScript. (Default is 0)
EOT

$help{'osaMethodOption'} = <<EOT;
Specifies which method should be used to compile and execute the AppleScript.
Possible values are: $availOsaMethodsNames
$availOsaMethodsDesc
EOT

$help{'optionsEnd'} = <<EOT;
Any of the above command-line options can be abbreviated as long as there is
no ambiguity. For example, "-osa" can be used in place of "-osaMethod" since
that is the only option that starts with "-osa".

If any filenames are specified on the command-line, '$ash' will execute the
commands in those files non-interactively. I.e. supplying a file on the
command-line is an alternative to inserting a "shebang" line and making the
script file executable as described in the "stand-alone scripts" section.
EOT

$helpTitle{'options'} = "Command-line options";
$help{'options'} =
"$help{'optionsStart'}\n" .
"-nogreeting\n" .
"$help{'nogreetingOption'}\n" .
"-quiet\n" .
"$help{'quietOption'}\n" .
"-norc\n" .
"$help{'norcOption'}\n" .
"-oneoff\n" .
"$help{'oneoffOption'}\n" .
"-trace\n" .
"$help{'traceOption'}\n" .
"-debug <level>\n" .
"$help{'debugOption'}\n" .
"-timing <level>\n" .
"$help{'timingOption'}\n" .
"-osaMethod <method>\n" .
"$help{'osaMethodOption'}\n" .
"$help{'optionsEnd'}";


$helpTitle{'startup'} = "Startup";
$help{'startup'} = <<EOT;
When '$ash' starts up, it executes the commands in the file ~/$ashrc
in the same manner as if these commands had been typed interactively at the
command prompt. (In other words, it automatically "sources" the ~/$ashrc file.)
For example, if you had the following command in the $ashrc file:
    say "Welcome to \\"$ash\\" ($ashLongName)"
    
then you would get a spoken welcome when you started '$ash'.
You can use the $ashrc file to store commonly used abbreviations or to set up
AppleScript subroutines, etc.
You can use the "-norc" command-line option to prevent the "$ashrc" file from
being read at startup.
EOT

$helpTitle{'unix'} = "Unix Commands";
$help{'unix'} = <<EOT;
You can change the working directory via the "$cdCmd" command which works
just like the 'cd' command in 'tcsh' and 'bash'. The "$cdCmd" command has a
special option "-f" that changes directory to the folder of the frontmost
Finder window: "$cdCmd -f".
You can find out what the current directory is via the "$pwdCmd" command.
You can list the files in the current directory (or other dierctories)
via the "$lsCmd" command - it takes all the usual command-line options for 'ls'.
And if there are any other Unix commands that you want to run, you can do so
via the "$unixCmd" escape - any command that you give after that will be passed
to a standard Unix shell for execution. For example, the command '$unixCmd ls'
does the same thing as the "$lsCmd" command. (In fact the "$lsCmd" command
is implemented as an abbreviation for "$unixCmd ls" and the "$pwdCmd" command
is implemented as an abbreviation for "$unixCmd pwd".)
EOT

$helpTitle{'standAlone'} = "Using '$ash' in stand-alone script files";
$help{'standAlone'} = <<EOT;
It is also possible to use '$ash' in a non-interactive way, by specifying it
as the "shebang" interpreter in a script file. Using this mechanism, you can
create stand-alone script files that can be run like usual Unix scripts.
To do this, you save your AppleScript commands (and special '$ash' commands)
in a file and make the first line of that file be the following:
    #!/usr/bin/env $ash

(This assumes that '$ash' is in your shell execution PATH - otherwise you should
specify the full path to '$ash' in that "shebang" line.)
Then make the script file executable (using 'chmod +x') and you will be able to
run that script like any other Unix command.
Technical note: the reason why you need to use '/usr/bin/env' in the "shebang"
line is that '$ash' is itself a script.

When running non-interactively, '$ash' is effectively in "batch mode".
All of the AppleScript commands are sent off for execution at one time.

Note that the ~/$ashrc file is *not* read when running non-interactively 
(i.e. when running a stand-alone script) and thus the "-norc" command-line
option is redundant in this case. If you want to execute the commands from your 
~/$ashrc file when running a stand-alone script, you can use the "$sourceCmd"
command to do so.

An alternative way to run script files non-interactively is to specify the
filenames on the '$ash' command-line. For example: '$ash file1 file2' would
non-interactively execute the commands in the files "file1" and "file2".
EOT

$helpTitle{'commandLine'} = "Note on command-line editing";
$help{'commandLine'} = <<EOT;
This script uses the Perl module "Term::ReadLine" which supplies facilities for
interactive command-lines. The default Perl installation on OS X (as of Tiger)
only includes a "stub" version of the facilities used by this module.
If you install the module "Term::ReadLine::Perl" (e.g. via CPAN) then you will
get command-line editing and command history (via the arrow keys).
EOT

$helpTitle{'license'} = "Copyright & License";
$help{'license'} = <<EOT;
Copyright 2006 by $authorName

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
EOT

$help{'version'} = <<EOT;
This is version $version of '$ash' ($ashLongName).
It was written by $authorName ($authorEmail).
You can get the latest version from the web site:
$ashWebSite
EOT

$helpTitle{'bugs'} = "Known bugs";
$help{'bugs'} = <<EOT;
* handling of top-level variables and properties is inadequate
EOT

# now get rid of the trailing newlines that are unavoidable in "here documents"
chomp(%help);


my $podText = <<EOT;
=head1 NAME

B<$ash> - an "$ashLongName" for interactive execution of AppleScript commands

=head1 SYNOPSIS

B<$ash> [<options>] [I<filename(s)>]

=head1 DESCRIPTION

$help{'description'}

=head2 $helpTitle{'echo'}

$help{'echo'}

=head2 $helpTitle{'subroutines'}

$help{'subroutines'}

=head2 $helpTitle{'variables'}

$help{'variables'}

=head2 $helpTitle{'batch'}

$help{'batch'}

=head2 $helpTitle{'comments'}

$help{'comments'}

=head2 $helpTitle{'startup'}

$help{'startup'}

=head2 $helpTitle{'input'}

$help{'input'}

=head2 $helpTitle{'commandLine'}

$help{'commandLine'}

=head1 OPTIONS

$help{'optionsStart'}

=over

=item B<-nogreeting>

$help{'nogreetingOption'}

=item B<-quiet>

$help{'quietOption'}

=item B<-norc>

$help{'norcOption'}

=item B<-oneoff>

$help{'oneoffOption'}

=item B<-trace>

$help{'traceOption'}

=item B<-debug> I<level>

$help{'debugOption'}

=item B<-timing> I<level>

$help{'timingOption'}

=item B<-osaMethod> I<method>

$help{'osaMethodOption'}

=back

$help{'optionsEnd'}

=head1 COMMANDS

There are several special commands (starting with "B<$specialPrefix>") that are
interpreted by this shell. These commands can be entered at the B<ash> prompt
when running interactively, or inserted in a file that is run non-interactively.
(The reason for the "$specialPrefix" at the start of each command name is to
ensure that these commands don't collide with some AppleScript syntax.)
Even though some of the command names include uppercase characters,
the command processing is case-insensitive, so for example you could use
"${ \( lc($clearAllCmd) )}" instead of "$clearAllCmd".

=over

=item B<$helpCmd> I<[topic]>

If you supply one of the available topic names as an argument,
the "$helpCmd" command will show the help text for that topic,
otherwise it will show the "intro" section.
To see the list of available topics, use "$helpCmd topics".

=item B<$exitCmd>

Exits the B<$ash> shell

=item B<$abbrevCmd> I<[name [commandString]]>

Defines an abbreviation for a command string.
For example:

    $abbrevCmd strack some track of playlist "Library"

defines 'strack' as an abbreviation for 'some track of playlist "Library"'
so you could then issue the AppleScript command

    tell application "iTunes" to play strack

in order to play a random song from your iTunes library.

You can remind yourself of the definition of the abbreviation named "strack"
by entering the command "$abbrevCmd strack".
You can see the current list of abbreviations by entering the command
B<$abbrevCmd> (with nothing following it).

=item B<$unabbrevCmd> I<name>

Removes a previously defined abbreviation.

=item B<$echoCmd> I<expression>

Echos the value of the specified AppleScript I<expression>.

=item B<$readCmd> [I<options>] [I<varName>]

Reads from the keyboard in the same manner as the 'read' command in Bash.
If I<varName> is supplied, the characters read are stored in an AppleScript
variable of that name. The I<options> are the same format as those for the
Bash 'read' command. E.g. "-n1" will read one single character (without the need
to press Return), "-s" will disable echoing of characters, "-t5" will make it
timeout after 5 seconds. Note that unless you use the "-t" option, it will wait
indefinitely for the user to enter something.

=item B<$sourceCmd> I<filename>

$help{'source'}

=item B<$batchCmd> [I<filename>]

Starts "batch mode".
If you supply a filename as an argument to the "$batchCmd" command
(e.g. '$batchCmd ~/MyStuff/do_something'), '$ash' will go into batch mode,
source the specified file, then exit from batch mode automatically.

=item B<$endBatchCmd>

Ends "batch mode" and executes the pending AppleScript commands.

=item B<$showCmd>

Displays the text of the current AppleScript
(i.e. the text of a partially completed multi-line command 
or that of the most recently executed command,
plus any previously defined subroutines or script objects)
This is useful when you want to copy & paste that AppleScript elsewhere,
or just to review the commands you have entered and the existing subroutines
and script objects.

=item B<$editorCmd>

Activates Apple's "Script Editor" and creates a new document
with the text of the current script.

=item B<$rerunCmd>

Reruns the current AppleScript.

=item B<$clearCmd>

Clears the current AppleScript.

=item B<$clearSubCmd> I<subName>

Clears the specified AppleScript subroutine.
For example, if you had previously defined a subroutine named "foo", then
"$clearSubCmd foo" would remove it.

=item B<$clearScriptCmd> I<scriptName>

Clears the specified script object.
For example, if you had previously defined a script object
named "fred", then "$clearScriptCmd fred" would remove it.

=item B<$clearVarCmd> I<varName>

Clears the specified variable or property.
For example, if you had previously defined a variable or property
named "x", then "$clearVarCmd x" would remove it.

=item B<$clearAllCmd>

Clears all previously defined subroutines, script objects, variables, and
properties as well as clearing the current AppleScript.

=item B<$cdCmd> I<[dirName]>

Changes the current working directory to the directory specified.
If no directory is specified, changes to the user's home directory.
If the "-f" option is used ("$cdCmd -f"), it changes directory to the folder
of the frontmost Finder window.

=item B<$pwdCmd>

Displays the current working directory.
(This command is actually just an abbreviation for "$unixCmd pwd".)

=item B<$lsCmd> I<[options] [filenames]>

Lists the files of the current directory.
(This command is actually just an abbreviation for "$unixCmd ls" and so it
takes all the usual command-line options for 'ls'.)

=item B<$unixCmd> I<command>

Passes the specified I<command> to a standard Unix shell for execution.
For example, the command '$unixCmd ls'
does the same thing as the "$lsCmd" command.
(The "$lsCmd" command is provided just as a convenience.)

=item B<$createManCmd>

Creates a 'man' page file named "$ash.1" in the current directory.
You will need to move this file to one of the directories in your MANPATH
(e.g. move it to $suggestedManDir)

=back

=head1 STAND-ALONE SCRIPT FILES

$help{'standAlone'}

=head1 BUGS

$help{'bugs'}

=head1 AUTHOR

B<$ash> was written by $authorName ($authorEmail).
The initial version was in January 2002.

=head1 COPYRIGHT & LICENSE

$help{'license'}

=head1 VERSION

This man page was generated via the "$createManCmd" command using
version $version of B<$ash>. You can check what version you are using
by issuing the "$helpCmd version" command.
You can get the latest version of B<$ash> from the web site:
$ashWebSite

=cut

EOT


# BUGS & TODO's
#--------------
# * need to do more testing to make sure that subroutines & script objects
#   are correctly handled.
#
# * need to think about how better to handle global variables and properties
#
# * investigate if we can store the compiled version of a stand-alone script
#   (i.e. one using a shebang line) and store it in the resource fork
#   and then execute the compiled version if the script hasn't been modified
#   (could note the time and/or md5 checksum in the reource fork perhaps?)
#
# ----------------------------------------------------------------------------


# FUNCTIONS
#--------------------------------

# Forward declarations:
sub checkIfSpecial($);
sub processCommand($$);
sub sourceFile($$);
sub showHelp($);
sub asCmdHasResult($);


# Utility routines:
# -----------------

# All text destined for the screen should go through one of the next 4 functions
sub outputWithoutNewline($)
{
    my ($msg) = @_;
    
    print "$msg";
}

sub output($)
{
    my ($msg) = @_;
    
    print "$msg\n";
}

sub errorOutput($)
{
    my ($msg) = @_;
    
    print STDERR "$msg\n";
}

sub debugOutput($)
{
    my ($msg) = @_;
    
    print "$msg\n";
}

sub outputBlankLine()
{
    output("");
}

sub internalError($)
{
    my ($msg) = @_;

    errorOutput("INTERNAL ERROR: $msg");
    exit(-1);
}

sub beep()
{
    print "\a";
}

sub userError($)
{
    my ($msg) = @_;
    
    # we use STDERR here so that if 'ash' is being used in a stand-alone script
    # and the output is being captured to a file, the errors still appear.
    
    errorOutput("*** Error: $msg");
    beep();
    ++$numErrors;
}

sub userWarning($)
{
    my ($msg) = @_;
    
    errorOutput("*** Warning: $msg");
}

sub debugMsg($$)
{
    my ($level, $msg) = @_;

    if ($debugLevel >= $level)
    {
        debugOutput("$msg");
    }
}

# for debugging
sub debugArray($@)
{
    my ($msg, @data) = @_;

    debugOutput("$msg");
    my $numData = scalar(@data);
    for (my $i = 0; $i < $numData; $i++)
    {
        debugOutput("Entry #$i: $data[$i]");
    }
}

# for debugging
sub asciiToHex($)
{
    my ($str) = @_;

    my @chars = split(//, $str);
    my @hexNums = map(sprintf("%02x", ord($_)), @chars);
    return join(" ", @hexNums);
}

sub showTimingInfo($$$)
{
    my ($msg, $start, $end) = @_;
    
    my $elapsed = $end - $start;
    my $timingInfo = sprintf("$msg: %.3f s", $elapsed);
    output($timingInfo);
}

sub trimWhitespace
{
    my @strings = @_;

    for (@strings)
    {
        s/^\s+//; # remove leading whitespace
        s/\s+$//; # remove trailing whitespace
    }
    return wantarray ? @strings : $strings[0];
}

# function to expand tilde's in filenames (from The Perl Cookbook)
sub expandTilde($)
{
    my ($filepath) = @_;

    $filepath =~ s{^~([^/]*)}
                  { $1
                     ? (getpwnam($1))[7]
                     : ( $ENV{HOME} || $ENV{LOGDIR} || (getpwuid($>))[7] )
                  }ex;
    return $filepath;
}

sub cleanFilepath($)
{
    my ($filepath) = @_;

    $filepath = trimWhitespace($filepath);
    $filepath =~ s/\\ / /g; # get rid of escaping for spaces
    $filepath = expandTilde($filepath);
    return $filepath;
}

sub isTextFile($)
{
    my ($filepath) = @_;
    
    my $outputFromFileCmd = `/usr/bin/file -b $filepath`;
    if ($outputFromFileCmd =~ /text/)
    {
        return 1;
    }
    else
    {
        return 0;
    }
}

sub currentFinderDir()
{
    my $ascript = <<"    EOT";
    tell application "Finder"
        try
            set currFolder to (folder of the front window as alias)
            POSIX path of currFolder
        on error
            "unknown"
        end try
    end tell
    EOT
    
    my ($result, $errMsg) = executeApplescript($ascript);
    if ($errMsg)
    {
        debugMsg(1, "currentFinderDir: result: $result errMsg: $errMsg");
        $result = "unknown";
    }
    else
    {
        # AppleScript string results seem to be double-quoted
        $result =~ s/^"//;
        $result =~ s/"$//;
    }
    
    return $result;
}

sub speakText($)
{
    my ($text) = @_;
    
    my $ascript = <<"    EOT";
    say "$text"
    EOT
    
    my ($result, $errMsg) = executeApplescript($ascript);
    if ($errMsg)
    {
        debugMsg(1, "speakText: errMsg: $errMsg");
        return 0;
    }
    else
    {
        return 1;
    }
}

sub playQuickTimeFile($)
{
    my ($filename) = @_;
    
    my $ascript = <<"    EOT";
    tell application "QuickTime Player"
        open POSIX file "$filename"
        play movie 1
    end tell
    EOT
    
    my ($result, $errMsg) = executeApplescript($ascript);
    if ($errMsg)
    {
        debugMsg(1, "playQuickTimeFile: errMsg: $errMsg");
        return 0;
    }
    else
    {
        return 1;
    }
}

sub unexpected()
{
    my $pythonFrmWrk = "/System/Library/Frameworks/Python.framework";
    my $pythonLibDir = "$pythonFrmWrk/Versions/Current/lib";
    my $netsiFile = `find $pythonLibDir -regex '.*/test/audiotest.au'`;
    chomp($netsiFile);
    playQuickTimeFile($netsiFile) if $netsiFile;
}

sub escapeDoubleQuotes($)
{
    my ($str) = @_;
    
    # we need to escape both backslashes and double-quotes
    # e.g.: " -> \"   \ -> \\   \" -> \\\"
    $str =~ s/([\\"])/\\$1/g;
    return $str;
}

sub escapeQuotesEtc($)
{
    my ($str) = @_;
    
    # we need to escape backslashes, single-quotes, and double-quotes
    # e.g.: " -> \"   ' -> \'  \ -> \\   \" -> \\\"
    $str =~ s/([\\'"])/\\$1/g;
    return $str;
}

sub linesWithCharRange($$$)
{
    my ($text, $start, $end) = @_;

    my @lines = split(/^/, $text); # keeps the \n characters in @lines
    my @desiredLines = ();
    my $offset = -1;
    my $index = 0;
    foreach my $line (@lines)
    {
        my $len = length($line);
        if ($start < ($index + $len))
        {
            if ($start >= $index)
            {
                $offset = $start - $index;
            }

            if ($end >= $index)
            {
                push(@desiredLines, $line);
            }
        }
        $index += $len;
    }

    return ($offset, @desiredLines);
}

# determines if the current user is an admin user
sub isAdmin()
{
    my $groups = `/usr/bin/id -Gn`;
    if ($groups =~ /\badmin\b/)
    {
        return 1;
    }
    else
    {
        return 0;
    }
}

sub writeStringToTempFile($)
{
    my ($str) = @_;
    
    use autouse 'File::Temp' => qw(tempfile);
    
    my ($fh, $filename) = tempfile();     
    print $fh $str;
    $fh->close();
    
    return $filename;
}

# creates a 'man' page file in the current directory
sub generateManPageFileFromPodText($$$)
{
    my ($progName, $version, $podText) = @_;
    
    require Pod::Man;

    my $section = "1";
    my $manFilename = "$progName.$section";
    open(MAN, ">$manFilename")
        or warn "Can't create file \"$manFilename\": $!\n" and return undef;
        
    my $podFile = writeStringToTempFile($podText);
    open (POD, "<$podFile")
        or warn "Can't open podFile \"$podFile\": $!\n" and return undef;
    
    my $parser = Pod::Man->new(
                               center  => "",
                               name    => uc($progName),
                               release => $progName . " v" . $version,
                               section => $section,
                              );
    $parser->parse_from_filehandle(*POD, *MAN);
    
    close(POD);
    close(MAN);
    unlink($podFile);
    
    return $manFilename;
}


# Help and Man page:
# ------------------
sub showHelpSectionTitle($)
{
    my ($section) = @_;
    
    my $title = $helpTitle{$section};
    if ($title)
    {
        $title .= ":";
        output($title);
        output("-" x length($title));
    }
}

sub showHelp($)
{
    my ($section) = @_;

    if ($section eq "intro")
    {
        my $count = 0;
        foreach my $sec ('description','commandSummary','help','topics')
        {
            outputBlankLine() if $count++ > 0;
            showHelp($sec);
        }
    }
    elsif ($section eq "all")
    {
        my $count = 0;
        foreach my $sec ('intro','abbrev','source','echo',
                          'show','subroutines','variables',
                          'comments','batch','startup','options',
                          'unix','man','standAlone','input',
                          'commandLine','bugs','license','version')
        {
            outputBlankLine() if $count++ > 0;
            showHelp($sec);
        }

    }
    elsif (defined($help{$section}))
    {
        showHelpSectionTitle($section);
        output($help{$section});
    }
    else
    {
        showHelpSectionTitle('topics');
        output($help{'topics'});
    }
}

sub createManPage()
{    
    my $manFilename = generateManPageFileFromPodText($ash, $version, $podText);
    if ($manFilename)
    {
        unless ($quiet)
        {
            output("Created the file \"$manFilename\""
                   . " in the current directory");
            output("You need to move it to one of the directories"
                   . " in your MANPATH");
            output("(e.g. move it to $suggestedManDir)");
        }
    }
    else
    {
        errorOutput("$createManCmd command failed");
    }
}


# Abbreviation handling:
# ----------------------
sub showAbbreviations()
{
    foreach my $abbrev (sort keys %abbreviations)
    {
        output("$abbrev\t$abbreviations{$abbrev}");
    }
}

sub substituteAbbreviations($)
{
    my ($text) = @_;

    use autouse 'Text::ParseWords' => qw(parse_line);

    # 'parse_line' doesn't seem to like mismatched quotes 
    # (this would seem like a bug in Text::ParseWords)
    #  so we work-around this by changing each quote to two
    $text =~ s/'/''/g;
    $text =~ s/"/""/g;

    my @words = parse_line('\s+', 1, $text); 
    foreach my $word (@words)
    {
        foreach my $abbrev (keys %abbreviations)
        {
            if ($word eq $abbrev)
            {
                $word = $abbreviations{$abbrev};
            }
        }
    }

    $text = join(" ", @words);

    # change the quotes back again (see above)
    $text =~ s/''/'/g;
    $text =~ s/""/"/g;

    return $text;
}

sub handleAbbreviations($)
{
    my ($command) = @_;

    if (my ($name, $args) = checkIfSpecial($command))
    {
        # It's a special command:
        # we substitute for abbreviations in $name

        $name = substituteAbbreviations($name);
        $command = "$name $args";
        
        if (($name, $args) = checkIfSpecial($command))
        {
            # we only substitute for abbreviations in $args if
            # it is an '-echo' command or an "-abbrev" commands
            # and only in the right-hand side of the latter
            # (i.e. in the places where AppleScript could be)
            
            if ($name eq $echoCmd)
            {
                $args = substituteAbbreviations($args);
                $command = "$echoCmd $args";
            }
            elsif ($name eq $abbrevCmd)
            {
                if ($args =~ /^(\S+)\s+(.*)$/)
                {
                    my $lhs = $1;
                    my $rhs = $2;
                    $rhs = substituteAbbreviations($rhs);
                    $command = "$abbrevCmd $lhs $rhs";
                }
            }
        }
    }
    else
    {
        $command = substituteAbbreviations($command);
    }

    return $command;
}


# Executing AppleScripts:
# -----------------------
sub showApplescriptError($$)
{
    my ($applescript, $errMsg) = @_;

    # we use STDERR here so that if 'ash' is being used in a stand-alone script
    # and the output is being captured to a file, the errors still appear.
    
    errorOutput("------- AppleScript Error -------");

    # Sample error messages from 'osacript':
    # 0:1: syntax error: A unknown token can't go here. (-2740)
    # 4:7: execution error: The variable foo is not defined. (-2753)
    if ($errMsg =~ /^\s*(\d+):(\d+):\s*(.*)$/)
    {
        my $start = $1;
        my $end = $2;
        my $msg = $3;
        debugMsg(3, "showApplescriptError: start: $start  end: $end");

        my $numChars = $end - $start;

        # Special case handling for problems at the end of lines where
        # 'osascript' seems to set the start offset to the newline
        # and the end offset to the char at the beginning of the next line.
        # So we set the end offset to be equal to the start offset in this case
        if ($numChars == 1 and substr($applescript, $start, 1) eq "\n")
        {
            debugMsg(3, "showApplescriptError: setting end to equal start");
            $end = $start;
        }

        my ($offset, @lines) = linesWithCharRange($applescript, $start, $end);
        debugMsg(3, "showApplescriptError: offset: $offset");
        my $offending = join('', @lines);
        chomp($offending);
        errorOutput("$offending");
        errorOutput((" "x$offset) . ("^"x$numChars));
        errorOutput("$msg");
    }
    else #unrecognized format, so just output it verbatim
    {
        errorOutput("$errMsg");
    }
}

sub executeViaOsascriptUtility($)
{
    my ($applescript) = @_;
    
    use autouse 'IPC::Open3' => qw(open3);
    my $cmd = "/usr/bin/osascript";
    
    my $time1 = time() if $timing;
    my $pid = open3(*OSA_IN, *OSA_OUT, *OSA_ERR, $cmd);
    debugMsg(2, "executeViaOsascriptUtility: osascript pid = $pid");
    $SIG{CHLD} = 'IGNORE'; # to avoid zombies

    print OSA_IN "$applescript";
    close(OSA_IN);

    my @results;
    my @errMsgs;
    chomp(@results = <OSA_OUT>);
    chomp(@errMsgs = <OSA_ERR>);
    close(OSA_OUT);
    close(OSA_ERR);
    my $time2 = time() if $timing;
    showTimingInfo("CompileAndExecute", $time1, $time2) if $timing;

    my $result = join("\n", @results);
    my $errMsg = join("\n", @errMsgs);
    debugMsg(3, "executeViaOsascriptUtility: result: $result errMsg: $errMsg");
    return ($result, $errMsg);
}

# convertOSAMsgCurlyQuotes: a hack used in 'getOSAErrorMessage'
sub convertOSAMsgCurlyQuotes($)
{
    my ($str) = @_;
    
    # the following substitutions are completely empirical
    # derived from a comparison of what is output via OSAScriptError
    # and what is output via '/usr/bin/osascript'
    $str =~ s/\xd2/\xe2\x80\x9c/g;
    $str =~ s/\xd3/\xe2\x80\x9d/g;
    return $str;
}

# getOSAErrorMessage: this function is useful when using Mac::OSA::Simple
#                 It composes an error message of the form output by 'osascript'
sub getOSAErrorMessage()
{
    use autouse 'Mac::AppleEvents' => qw(
                                         typeAERecord
                                         typeShortInteger
                                         typeChar
                                         AECoerceDesc
                                         AEGetKeyDesc
                                         AEDisposeDesc
                                         );
    use autouse 'Mac::OSA'         => qw(
                                         kOSAErrorNumber
                                         kOSAErrorMessage
                                         kOSAErrorRange
                                         keyOSASourceStart
                                         keyOSASourceEnd
                                         typeOSAErrorRange
                                         OSAScriptError
                                         );

    my $comp;
    {
        no warnings;
        $comp = $Mac::OSA::Simple::ScriptComponents{'ascr'};
    }

    # get the error number
    my $errNumDesc = OSAScriptError($comp, kOSAErrorNumber, typeShortInteger);
    my $errNum = $errNumDesc->get();
    #debugOutput("errNum = $errNum");
    
    # get the error message
    my $errMsgDesc = OSAScriptError($comp, kOSAErrorMessage, typeChar);
    my $errMsg = $errMsgDesc->get();
    #debugOutput("errMsg = $errMsg");
    $errMsg = convertOSAMsgCurlyQuotes($errMsg);
    
    # get the character range where the error occurs
    my $errRangeDesc = OSAScriptError($comp, kOSAErrorRange, typeOSAErrorRange);
    my $errRangeRec = AECoerceDesc($errRangeDesc, typeAERecord);
    my $start = AEGetKeyDesc($errRangeRec, keyOSASourceStart)->get();
    #debugOutput("start = $start");
    my $end = AEGetKeyDesc($errRangeRec, keyOSASourceEnd)->get();
    #debugOutput("end = $end");
    
    # there should be a better way of getting the following
    my $errorType = "error";
    if ($errNum == -2740 or $errNum == -2741)
    {
        $errorType = "syntax error";
    }
    elsif ($errNum == -2753 or $errNum == -1708)
    {
        $errorType = "execution error";
    }
    
    # I'm not sure if the following 'dispose' calls are really necessary
    AEDisposeDesc($errNumDesc);
    AEDisposeDesc($errMsgDesc);
    AEDisposeDesc($errRangeDesc);
    AEDisposeDesc($errRangeRec);
    
    # the following format tries to match what is used by /usr/bin/osascript
    my $fullErrMsg = "$start:$end: $errorType: $errMsg ($errNum)";
    return $fullErrMsg;
}

sub executeViaOSASimpleModule($)
{
    my ($applescript) = @_;

    use autouse 'Mac::OSA::Simple' => qw(compile_applescript($));
    
    my $result = "";
    my $errMsg = "";

    my $time1 = time() if $timing;
    my $osaObj = compile_applescript($applescript); 
    my $time2 = time() if $timing;
    showTimingInfo("Compile", $time1, $time2) if $timing;
    if ($osaObj)
    {
        debugMsg(2, "executeViaOSASimpleModule: compile succeeded");
        $result = $osaObj->execute();
        $result = "" unless defined($result);
        if ($!)
        {
            $errMsg = getOSAErrorMessage();
        }
        $osaObj->dispose();
        
        my $time3 = time() if $timing;
        showTimingInfo("Execute", $time2, $time3) if $timing;
    }
    else # compile error
    {
        $errMsg = getOSAErrorMessage();
    }
    
    debugMsg(3, "executeViaOSASimpleModule: result: $result errMsg: $errMsg");
    return ($result, $errMsg);
}

sub executeViaMacPerlModule($)
{
    my ($applescript) = @_;
    
    use autouse 'MacPerl' => qw(DoAppleScript);
    
    my $time1 = time() if $timing;
    my $result = DoAppleScript($applescript);
    
    my $errMsg = "";
    if (!defined($result))
    {
        $errMsg = $@; # this error msg doesn't include the character ranges
        $result = "";
    }
    
    my $time2 = time() if $timing;
    showTimingInfo("CompileAndExecute", $time1, $time2) if $timing;
    
    debugMsg(3, "executeViaMacPerlModule: result: $result errMsg: $errMsg");
    return ($result, $errMsg);
}

# returns 1 iff the AppleScript is not all blank lines and/or comments
sub hasEffect($)
{
    my ($applescript) = @_;
    
    my $commentLevel = 0;
    my $lineNum = 0;
    foreach my $line (split(/\n/, $applescript))
    {
        ++$lineNum;
        
        if ($line =~ /^--/)
        {
            # one line comment
        }
        elsif ($line =~ /^\(\*/)  # starts with open-comment indicator
        {
            if ($line =~ /\*\)$/)
            {
                # comment finished on same line
            }
            else
            {
                ++$commentLevel;
            }
        }
        elsif ($line =~ /\*\)$/)  # ends with close-comment indicator
        {
            if ($commentLevel > 0)
            {
                --$commentLevel;
            }
            else
            {
                debugMsg(2, "hasEffect: misplaced close-comment on line #"
                            . " $lineNum of following AppleScript:\n"
                            . $applescript);
                # This should never happen since we are checking for correct
                # commenting behaviour in the 'applescriptCommand' function.
                # So it probably indicates an internal error, but since the
                # current function is just used for optimization,
                # we'll let it go and return 1 to indicate this AppleScript
                # needs to be executed.
                return 1;
            }
        }
        elsif ($commentLevel > 0)
        {
            # we're inside a multi-line comment
        }
        elsif ($line =~ /^\s*$/)
        {
            # a blank line
        }
        else
        {
            # we've got something that isn't a comment and isn't an blank line
            return 1;
        }
    }
    
    # we got all the way to the end, so the AppleScript is effectively empty
    return 0;
}

sub executeApplescript($)
{
    my ($applescript) = @_;

    debugMsg(1, "executeApplescript: applescript is:\n|$applescript|");
    my $result = "";
    my $errMsg = "";
    
    # we avoid wasting time on empty AppleScripts
    unless (hasEffect($applescript))
    {
        debugMsg(1, "executeApplescript: effectively empty,"
                    . " so returning early");
        return ($result, $errMsg);
    }

    if ($osaMethod eq "osascript")
    {
        ($result, $errMsg) = executeViaOsascriptUtility($applescript);
    }
    elsif ($osaMethod eq "macosasimple")
    {
        ($result, $errMsg) = executeViaOSASimpleModule($applescript);
    }
    elsif ($osaMethod eq "macperl")
    {
        ($result, $errMsg) = executeViaMacPerlModule($applescript);
    }
    else
    {
        internalError("Invalid osaMethod: $osaMethod");
    }

    return ($result, $errMsg);
}

# runApplescript:
# In a scalar context: returns 1 if successful, 0 if an error occurred
# In an array context: returns ($result, $errMsg)
# This function is called from the following places:
#      - 'runApplescriptAndStore' (in 'processCommand')
#      - 'endBatchMode' (to run the accumulated script)
#      - 'rerunCmd' (to rerun the current script)
sub runApplescript($)
{
    my ($applescript) = @_;

    my ($result, $errMsg) = executeApplescript($applescript);

    my $status = 1;  # assume success
    if ($errMsg)
    {
        showApplescriptError($applescript, $errMsg);
        ++$numErrors;
        $status = 0; # failure
    }

    if (defined($result) && $result ne "")
    {
        output($result);
    }

    ++$numApplescriptsRun;
    
    return wantarray ? ($result, $errMsg): $status;
}

# Implementation of the trace facility:
# -------------------------------------
sub applescriptForTracing($)
{
    my ($command) = @_;
    
    my $applescript = "";
    my $isTraceDirective = 0;
    
    # Note that we allow other stuff after the number on the --trace line
    # so that users can add recognizable comments there
    
    if ($command =~ /^\s*--trace\s+(\d+)\s*/)  # a trace directive
    {
        $traceLevel = $1;
        $isTraceDirective = 1;
    }

    if ($traceLevel > 0 || $isTraceDirective)
    {
        my $isEndCmd = $command =~ /^\s*end\b/;
        unless ($isEndCmd)
        {
            my $hasResult = asCmdHasResult(trimWhitespace($command));
            
            $applescript = "my $traceSubName(\""
                           . escapeDoubleQuotes($command)
                           . "\", "
                           . ($hasResult ? "true" : "false")
                           . ")";
        }
    }
    
    return $applescript;
}

# Composing an AppleScript from the stored commands:
# --------------------------------------------------
sub composeCommands($$)
{
    my ($commandsRef, $forExec) = @_;
    
    my $applescript = "";
    foreach my $command (@{$commandsRef})
    {
        $applescript .= "$command\n";
        
        if ($forExec)
        {
            my $tracingCmd = applescriptForTracing($command);
            $applescript .= "$tracingCmd\n" unless $tracingCmd eq "";
        }
    }
    
    # get rid of any extra newlines at the end
    $applescript =~ s/\n+$//;
    debugMsg(4, "composeCommands: applescript is |$applescript|");
    
    return $applescript;
}

sub composeUserSub($$)
{
    my ($subName, $forExec) = @_;
    
    my $applescript = composeCommands($userSubs{$subName}, $forExec);
    return $applescript;
}

sub composeUserScript($$)
{
    my ($scriptName, $forExec) = @_;

    my $applescript = composeCommands($userScriptObjs{$scriptName}, $forExec);
    return $applescript;
}

sub composeCurrCommands($)
{
    my ($forExec) = @_;
    
    my $applescript = composeCommands(\@currCommands, $forExec);    
    return $applescript;
}

sub composeApplescript($)
{
    my ($forExec) = @_;
    
    # $forExec is 0 when called from the -show or -editor command
    # i.e. when we want to show all of the userSubs & userScriptObjs
    # even if they aren't used in the current script.
    # Otherwise (when we are about to execute the current script), it is 1

    debugMsg(3, "composeApplescript: number of currCommands = "
                . numCurrCommands());
    my $currApplescript = composeCurrCommands($forExec);

    my $applescript = "";
    if ($forExec == 0 || hasEffect($currApplescript))
    {
        debugMsg(3, "currScriptObjs: " . join(",", sort keys %currScriptObjs));
        debugMsg(3, "currSubs: " . join(",", sort keys %currSubs));
        debugMsg(3, "currProps: " . join(",", sort keys %currProps));
        debugMsg(3, "currVars: " . join(",", sort keys %currVars));
        
        my $countScriptObjs = 0;
        my $numUserScripts = scalar(keys %userScriptObjs);
        debugMsg(3, "composeApplescript: numUserScripts = $numUserScripts");
        foreach my $scriptName (sort keys %userScriptObjs)
        {
            next if $currScriptObjs{$scriptName};
            $applescript .= composeUserScript($scriptName, $forExec);
            $applescript .= "\n\n"; # want a blank line between each scriptObj
            ++$countScriptObjs;
        }

        my $countSubs = 0;
        my $numUserSubs = scalar(keys %userSubs);
        debugMsg(3, "composeApplescript: numUserSubs = $numUserSubs");
        foreach my $subName (sort keys %userSubs)
        {
            next if $currSubs{$subName};
            $applescript .= composeUserSub($subName, $forExec);
            $applescript .= "\n\n"; # want a blank line between each sub
            ++$countSubs;
        }
        
        my $countProps = 0;
        my $numUserProps = scalar(keys %userProps);
        debugMsg(3, "composeApplescript: numUserProps = $numUserProps");
        foreach my $propName (sort keys %userProps)
        {
            next if $currProps{$propName};
            $applescript .= "property $propName : $userProps{$propName}\n";
            ++$countProps;
        }
        $applescript .= "\n" if $countProps > 0; # blank line at end of props

        my $countVars = 0;
        my $numUserVars = scalar(keys %userVars);
        debugMsg(3, "composeApplescript: numUserVars = $numUserVars");
        foreach my $varName (sort keys %userVars)
        {
            next if $currVars{$varName};
            $applescript .= "set $varName to $userVars{$varName}\n";
            ++$countVars;
        }
        $applescript .= "\n" if $countVars > 0; # blank line at end of vars
        
        if ($countScriptObjs + $countSubs + $countProps + $countVars > 0)
        {
            # by adding in this empty 'tell' statement, we avoid having the
            # values from the previous variable assignments showing up
            # - e.g. when a script with just a subroutine is executed
            $applescript .= "tell me  -- above code was previously defined --\n";
            $applescript .= "end tell ---------------------------------------\n";
            $applescript .= "\n"; # blank line
        }
    }

    $applescript .= $currApplescript;

    debugMsg(3, "composeApplescript: applescript is:\n|$applescript|");

    # add in $echoSub if -echo was used
    if ($applescript =~ /\b$echoSubName\b/)
    {
        $applescript = "$echoSub\n" . $applescript;
    }
    
    # add in $readSub if -echo was used
    if ($applescript =~ /\b$readSubName\b/)
    {
        $applescript = "$readSub\n" . $applescript;
    }
    
    # add in $traceSub if -echo was used
    if ($applescript =~ /\b$traceSubName\b/)
    {
        $applescript = "$traceSub\n" . $applescript;
    }

    # get rid of any extra newlines at the end
    $applescript =~ s/\n+$//;

    return $applescript;
}

sub showCurrCommands()
{
    output(composeCurrCommands(0)) if numCurrCommands() > 0;
}


# Command and Mode handling:
# --------------------------
sub getPrompt()
{
    my $prompt = $ash;
    $prompt .= "batch" if $batchMode;
    my $modeStr = join("|", @modes);
    $prompt .= " $modeStr" if $modeStr;
    $prompt .= "> ";
    
    return $prompt;
}

sub pushMode($)
{
    my ($mode) = @_;
    
    push(@modes, $mode);
    debugMsg(2, "pushMode: $mode  modes: " . join(" ", @modes));
}

sub popMode()
{
    my $mode = pop(@modes);
    debugMsg(2, "popMode: $mode  modes: " . join(" ", @modes));
    return $mode;
}

# replace the current mode with the specified one
sub replaceMode($)
{
    my ($mode) = @_;
    
    debugMsg(2, "replaceMode: $mode");
    if (@modes)
    {
        $modes[-1] = $mode;
    }
    else
    {
        internalError("replaceMode: Not in a mode! (target mode: $mode)");
    }
}

sub currMode()
{
    if (@modes)
    {
        return $modes[-1];
    }
    else
    {
        return undef;
    }
}

sub atToplevel()
{
    if (@modes)
    {
        return 0;
    }
    else
    {
        return 1;
    }
}

sub inMode($)
{
    my ($mode) = @_;
    
    if (@modes && ($modes[-1] eq $mode))
    {
        return 1;
    }
    else
    {
        return 0;
    }
}

sub inSomeScriptMode()
{    
    if (@modes && ($modes[-1] =~ /^script/))
    {
        return 1;
    }
    else
    {
        return 0;
    }
}

sub inSomeSubMode()
{    
    if (@modes && ($modes[-1] =~ /^sub/))
    {
        return 1;
    }
    else
    {
        return 0;
    }
}

# checks if currently inside a 'tell' statement by looking at the @modes
# Note that it doesn't have to be the current mode,
# so this is different from 'inMode("tell")'
sub insideTell()
{
    foreach my $mode (@modes)
    {
        if ($mode eq "tell")
        {
            return 1;
        }
    }
    
    return 0;
}

# for use in debugging
sub modesAndPrevCmd()
{
    my $prevCmd = @currCommands ? $currCommands[-1] : "";
    my $modeInfo = join("|", @modes);
    return "modes: $modeInfo\nprevCmd: $prevCmd";
}

sub addCurrCommand($$)
{
    my ($command, $indent) = @_;

    # discard empty commands at the beginning of a script
    unless (@currCommands)
    {
        if ($command =~ /^\s*$/)
        {
            debugMsg(3, "addCurrCommand: returning early since empty");
            return;
        }
    }
    
    debugMsg(3, "addCurrCommand: $command");
    push(@currCommands, " "x$indent . $command);
}

sub clearCurrCommands()
{
    debugMsg(2, "clearCurrCommands");
    
    @modes = ();
    @currCommands = ();
    %currScriptObjs = ();
    %currSubs = ();
    %currProps = ();
    %currVars = ();
}

sub numCurrCommands()
{
    return scalar(@currCommands);
}

sub clearAll()
{
    debugMsg(2, "clearAll");
    
    %userScriptObjs = ();
    %userSubs = ();
    %userProps = ();
    %userVars = ();
    clearCurrCommands();
}

sub startBatchMode()
{    
    debugMsg(1, "startBatchMode");
    
    clearCurrCommands();
    $batchMode = 1;
}

sub endBatchMode()
{    
    debugMsg(1, "endBatchMode");
    
    my $applescript = composeApplescript(1);
    runApplescript($applescript);
    $batchMode = 0;
}


# AppleScript command handling:
# -----------------------------
sub expectedEnd($)
{
    my ($mode) = @_;

    my $expected;
    if ($mode =~ /sub\s+($idPat)/o)
    {
        my $subName = $1;
        $expected = $subName;
    }
    elsif ($mode =~ /script\s+($idPat)/o)
    {
        my $scriptName = $1;
        $expected = "script";
    }
    elsif ($mode eq "else" or $mode eq "else if")
    {
        $expected = "if";
    }
    elsif ($mode eq "error")
    {
        $expected = "try";
    }
    else
    {
        $expected = $mode;
    }

    return $expected;
}

# we change the AppleScript as needed for execution from the Terminal
sub adjustForTerminal($)
{
    my ($command) = @_;
    
    unless (insideTell())
    {
        if ($command =~ /\bdisplay\s+(dialog|alert)\b/i
            or $command =~ /\bchoose\s+(file|folder|application|from)\b/i)
        {
            # in order to avoid "No user interaction allowed" messages
            # we change "display dialog|alert" & "choose file|folder"commands
            # that are not inside a 'tell' statement so that they address
            # the Terminal application where this script is running
            
            $command = "tell application \"$terminalAppName\" to $command";
        }
    }
    
    return $command;
}

sub asCmdTell($)
{
    my ($command) = @_;
    my $deltaIndent = 0;

    if ($command =~ /^tell\s+(.*)$/i)
    {
        # check if the 'tell' command has a 'to'
        if ($1 !~ /\bto\b/)
        {
            # it doesn't, so we need to go into 'tell' mode
            pushMode("tell");
        }
    }
    
    return ($command, $deltaIndent);
}

sub asCmdIf($)
{
    my ($command) = @_;
    my $deltaIndent = 0;

    # check if the 'if' command has a 'then' followed by a statement
    # (if it doesn't then we need to go into 'if' mode)
    if ($command =~ /\bthen\b\s*(\S+)/i)
    {
        if ($1 =~ /^\s*--/ or $1 =~ /^\s*\(\*/)
        {
            # just a comment after the 'then'
            pushMode('if');
        }
    }
    else
    {
        # no 'then'
        pushMode("if");
    }
    
    return ($command, $deltaIndent);
}

sub asCmdElse($)
{
    my ($command) = @_;
    my $deltaIndent = 0;

    my $newMode = "else";
    if ($command =~ /^else\s+if/i)
    {
        $newMode .= " if";
    }
    
    # check if we are in "if" or 'else if' mode 
    if (inMode("if") || inMode('else if'))
    {
        # change to "else" or "else if" mode
        replaceMode($newMode);
        $deltaIndent = -$indentPerMode;
    }
    else
    {
        userError("Not in 'if' mode!");
        debugMsg(1, "asCmdElse: command: $command");
        debugMsg(1, modesAndPrevCmd());
        $command = undef;
    }
    
    return ($command, $deltaIndent);
}

sub asCmdTry($)
{
    my ($command) = @_;
    my $deltaIndent = 0;

    pushMode("try");
    
    return ($command, $deltaIndent);
}

sub asCmdRepeat($)
{
    my ($command) = @_;
    my $deltaIndent = 0;

    pushMode("repeat");
    
    return ($command, $deltaIndent);
}

sub asCmdOnOrTo($)
{
    my ($command) = @_;
    my $deltaIndent = 0;

    if ($command =~ /^on\s+error\b/i)
    {
        # check if we are in "try" mode 
        if (inMode("try"))
        {
            # change to "error" mode
            replaceMode("error");
            $deltaIndent = -$indentPerMode;
        }
        else
        {
            userError("\"on error\" is not valid outside of a \"try\" command");
            $command = undef;
        }
    }
    elsif ($command =~ /^(on|to)\s+($idPat)/io)
    {
        my $onOrTo = $1;
        my $subName = $2;

        # we need to go into 'sub' mode
        if (atToplevel())
        {
            $currSubs{lc($subName)} = 1;
            pushMode("sub $subName");
        }
        elsif (inSomeScriptMode())
        {
            pushMode("sub $subName");
        }
        else
        {
            userError("subroutines (\"on\" or \"to\") are only valid at toplevel"
                     . " or inside a \"script\" command");
            $command = undef;
        }
    }
    
    return ($command, $deltaIndent);
}

sub asCmdScript($)
{
    my ($command) = @_;
    my $deltaIndent = 0;

    if ($command =~ /^script\s+($idPat)/io)
    {
        my $scriptName = $1;

        # we need to go into 'script' mode
        if (atToplevel())
        {
            $currScriptObjs{$scriptName} = 1;
            pushMode("script $scriptName");
        }
        elsif (inSomeSubMode() || inSomeScriptMode())
        {
            pushMode("script $scriptName");
        }
        else
        {
            userError("\"script\" commands are only valid at toplevel"
                     . " or inside a subroutine or another \"script\" command");
            $command = undef;
        }
    }
    
    return ($command, $deltaIndent);
}

sub asCmdConsidering($)
{
    my ($command) = @_;
    my $deltaIndent = 0;

    pushMode("considering");
    
    return ($command, $deltaIndent);
}

sub asCmdIgnoring($)
{
    my ($command) = @_;
    my $deltaIndent = 0;

    pushMode("ignoring");
    
    return ($command, $deltaIndent);
}

sub asCmdWith($)
{
    my ($command) = @_;
    my $deltaIndent = 0;

    if ($command =~ /^with\s+(timeout|transaction)\b/i)
    {
        # we need to go into a 'with' mode
        pushMode("with $1");
    }
    
    return ($command, $deltaIndent);
}

sub asCmdUsing($)
{
    my ($command) = @_;
    my $deltaIndent = 0;

    if ($command =~ /^using terms from\b/i)
    {
        # we need to go into a 'using terms from' mode
        pushMode("using terms from");
    }
    
    return ($command, $deltaIndent);
}

sub asCmdEnd($)
{
    my ($command) = @_;
    my $deltaIndent = 0;

    if ($command =~ /^end\b(.*)$/i)
    {
        my $endArg = $1 ? trimWhitespace($1) : "";
        my $currMode = currMode();
        if ($currMode)
        {
            my $expected = expectedEnd($currMode);
            if ($endArg eq "" or $endArg eq $expected)
            {
                popMode();
                $deltaIndent = -$indentPerMode;
                $command = "end $expected";
            }
            else
            {
                userError("Expecting \"end $expected\""
                         . " but got \"end $endArg\"");
                debugMsg(1, modesAndPrevCmd());
                $command = undef;
            }
        }
        else
        {
            userError("Not in a mode!");
            debugMsg(1, "command: $command");
            debugMsg(1, modesAndPrevCmd());
            $command = undef;
        }
    }
    
    return ($command, $deltaIndent);
}

sub asCmdSpanish($)
{
    my ($command) = @_;
    my $deltaIndent = 0;
    
    if ($command =~ /\binquisition\s*$/i)
    {
        unexpected();
        $command = undef;
    }
    
    return ($command, $deltaIndent);
}

sub asCmdSet($)
{
    my ($command) = @_;
    my $deltaIndent = 0;
    
    if ($command =~ /^set\s+($idPat)\s+to\b/io
        or $command =~ /^copy\s+.*(?:to|into)($idPat)\s*$/io)
    {
        my $varName = $1;
        if (atToplevel())
        {
            $currVars{lc($varName)} = 1;
        }
    }
    
    return ($command, $deltaIndent);
}

sub asCmdProperty($)
{
    my ($command) = @_;
    my $deltaIndent = 0;
    
    if ($command =~ /^(?:prop|property)\s+($idPat)\s*:\s*(.*)$/io)
    {
        my $propName = $1;
        my $propValue = $2;
        if (atToplevel())
        {
            $currProps{lc($propName)} = $propValue;
        }
    }
    
    return ($command, $deltaIndent);
}

sub asCmdHasResult($)
{
    my ($command) = @_;
    
    my $hasResult = 1;  # assume this for unrecognized commands
    
    if ($command =~ /^--/
        or $command =~ /^\(\*/)
    {
        # a comment
        $hasResult = 0;
    }
    elsif ($command =~ /^\s*([A-Za-z]+)/)
    {
        my $name = $1;
        if (my $applescriptCmd = $applescriptCmds{$name})
        {
            $hasResult = $applescriptCmd->{hasResult};
        }
    }
    
    return $hasResult;
}

sub registerApplescriptCmd($$$)
{
    my ($name, $sub, $hasResult) = @_;
    
    $applescriptCmds{lc($name)} = {
                                      'sub'       => $sub,
                                      'hasResult' => $hasResult,
                                  };
}

sub registerApplescriptCmds()
{
    registerApplescriptCmd("tell",        \&asCmdTell,          0);
    registerApplescriptCmd("if",          \&asCmdIf,            0);
    registerApplescriptCmd("else",        \&asCmdElse,          0);
    registerApplescriptCmd("try",         \&asCmdTry,           0);
    registerApplescriptCmd("repeat",      \&asCmdRepeat,        0);
    registerApplescriptCmd("on",          \&asCmdOnOrTo,        0);
    registerApplescriptCmd("to",          \&asCmdOnOrTo,        0);
    registerApplescriptCmd("script",      \&asCmdScript,        0);
    registerApplescriptCmd("considering", \&asCmdConsidering,   0);
    registerApplescriptCmd("ignoring",    \&asCmdIgnoring,      0);
    registerApplescriptCmd("with",        \&asCmdWith,          0);
    registerApplescriptCmd("using",       \&asCmdUsing,         0);
    registerApplescriptCmd("end",         \&asCmdEnd,           0);
    registerApplescriptCmd("spanish",     \&asCmdSpanish,       0);
    registerApplescriptCmd("set",         \&asCmdSet,           1);
    registerApplescriptCmd("copy",        \&asCmdSet,           1);
    registerApplescriptCmd("property",    \&asCmdProperty,      1);
    registerApplescriptCmd("prop",        \&asCmdProperty,      1);
}

sub applescriptCommand($)
{
    my ($command) = @_;

    debugMsg(3, "applescriptCommand: $command");
    
    # if we're at top-level and not in batch mode,
    # that means we are starting a new command-sequence
    # so we will clear the current commands
    if (atToplevel() && $batchMode == 0)
    {
        clearCurrCommands();
    }
    
    my $indent = scalar(@modes) * $indentPerMode;

    # note that leading and trailing whitespace has been stripped already
    # so we don't allow for whitespace in the regex patterns below

    $command = adjustForTerminal($command);
    
    if ($command =~ /^--/)
    {
        # one line comment - nothing to do
    }
    elsif ($command =~ /^\(\*/)  # starts with open-comment indicator
    {
        if ($command =~ /\*\)$/)
        {
            # comment finished on same line - nothing to do
        }
        else
        {
            pushMode("comment");
        }
    }
    elsif ($command =~ /\*\)$/)  # ends with close-comment indicator
    {
        if (inMode("comment"))
        {
            popMode();
        }
        else
        {
            userError("Not in a comment!");
            debugMsg(1, modesAndPrevCmd());
            return;
        }
    }
    elsif (inMode("comment"))
    {
        # we're inside a multi-line comment, so nothing to do
    }
    elsif ($command =~ /^([A-Za-z]+)/)
    {
        # note that we only capture the first word of the command in $1
        my $applescriptCmd = $applescriptCmds{lc($1)};
        if ($applescriptCmd)
        {
            my $sub = $applescriptCmd->{sub};
            my $deltaIndent;
            ($command, $deltaIndent) = &$sub($command);
            $indent += $deltaIndent;
        }
    }
    
    addCurrCommand($command, $indent) if defined($command);
}

sub runApplescriptAndStore()
{
    return unless numCurrCommands() > 0;
    
    my ($result, $errMsg) = runApplescript(composeApplescript(1));
    
    unless ($errMsg)
    {
        # the AppleScript ran successfully
        # so now we store subroutines, script objects, properties, and variables
        # - there should be at most one since each AppleScript command is sent
        #   off for execution as soon as it is completed
        my $numCurrScriptObjs = scalar(keys %currScriptObjs);
        my $numCurrSubs = scalar(keys %currSubs);
        my $numCurrProps = scalar(keys %currProps);
        my $numCurrVars = scalar(keys %currVars);
        if ($numCurrScriptObjs + $numCurrSubs
            + $numCurrProps + $numCurrVars > 1)
        {
            internalError("More than one sub/scriptObj/prop/variable!"
                          . "\nScriptObjs: "
                          . join(",", sort keys %currScriptObjs)
                          . "\nSubs: "
                          . join(",", sort keys %currSubs)
                          . "\nProps: "
                          . join(",", sort keys %currProps)
                          . "\nVars: "
                          . join(",", sort keys %currVars));
        }

        if ($numCurrScriptObjs > 0)
        {
            my $scriptName = (keys %currScriptObjs)[0];
            debugMsg(2, "storing userScript $scriptName");
            $userScriptObjs{lc($scriptName)} = [@currCommands];
            clearCurrCommands();
        }
        
        if ($numCurrSubs > 0)
        {
            my $subName = (keys %currSubs)[0];
            debugMsg(2, "storing userSub $subName");
            $userSubs{lc($subName)} = [@currCommands];
            clearCurrCommands();
        }
        
        if ($numCurrProps > 0)
        {
            my $propName = (keys %currProps)[0];
            debugMsg(2, "storing userProp $propName");
            $userProps{lc($propName)} = $currProps{lc($propName)};
            clearCurrCommands();
        }
        
        if ($numCurrVars > 0)
        {
            my $varName = (keys %currVars)[0];
            debugMsg(2, "storing userVar $varName");
            $userVars{lc($varName)} = $result;
            clearCurrCommands();
        }
    }
}


# Subroutines for special commands:
# ---------------------------------
# These '*Cmd' functions are of two types:
# - ones that take a single arg (which is already trimmed of whitespace)
# - ones that take no args

sub helpCmd($)
{
    my ($args) = @_;
    
    my $topic = $args ? $args : "intro";
    showHelp($topic);
    
    return undef;
}

sub exitCmd()
{    
    exit(0);
    return undef; # not reached
}

sub abbrevCmd($)
{
    my ($args) = @_;
    
    if ($args)
    {
        if ($args =~ /^\S+$/)  # querying an existing abbreviation
        {
            my $name = $args;
            if (defined($abbreviations{$name}))
            {
                output("$name is an abbreviation for: $abbreviations{$name}");
            }
            else
            {
                output("There is no abbreviation named \"$name\"");
            }
        }
        elsif ($args =~ /^(\S+)\s+(.*)$/)  # defining a new abbreviation
        {
            my $name = $1;
            my $value = $2;
            
            my $disallowed = 0;
            if ($specialCmds{$name})
            {
                if ($name eq $abbrevCmd or $name eq $unabbrevCmd)
                {
                    userError("Not allowed to override \"$abbrevCmd\""
                              . " or \"$unabbrevCmd\"");
                    $disallowed = 1;
                }
                else
                {
                    userWarning("Overriding special command \"$name\""
                                . " (use \"$unabbrevCmd $name\""
                                . " if you want to undo this)");
                }
            }
            
            $abbreviations{$name} = $value unless $disallowed;
        }
        else
        {
            userError("Invalid $abbrevCmd command");
        }
    }
    else
    {
        showAbbreviations();
    }
    
    return undef;
}

sub unabbrevCmd($)
{
    my ($args) = @_;
    
    if ($args && $args =~ /^\S+$/)
    {
        my $name = $args;
        if (defined($abbreviations{$name}))
        {
            delete $abbreviations{$name};
        }
        else
        {
            userError("There is no abbreviation named \"$name\"");
        }
    }
    else
    {
        userError("Invalid $unabbrevCmd command");
    }
    
    return undef;
}

sub batchCmd($)
{
    my ($args) = @_;
    
    if (atToplevel())
    {
        if ($args ne "")
        {
            my $filepath = cleanFilepath($args);
            sourceFile($filepath, 1);
        }
        else
        {
            startBatchMode();
        }
    }
    else
    {
        userError("$batchCmd is only valid at toplevel");
    }
    
    return undef;
}

sub endBatchCmd($)
{
    my ($args) = @_;
    
    if ($batchMode)
    {
        if ($args && $args !~ /^\s*batch\b/)
        {
            userError("\"$args\" is not appropriate here");
        }
        else
        {
            endBatchMode();
        }
    }
    else
    {
        userError("Not in batch mode!");
    }
    
    return undef;
}

sub sourceCmd($)
{
    my ($args) = @_;

    if ($args ne "")
    {
        my $filepath = cleanFilepath($args);
        
        # if we're in "one off" mode, we want to source the file in batch mode
        sourceFile($filepath, $oneoff);
    }
    else
    {
        userError("Invalid $sourceCmd command");
    }
    
    return undef;
}

sub echoCmd($)
{
    my ($args) = @_;
    
    if ($args ne "")
    {
        return "my $echoSubName($args)";
    }
    else
    {
        userError("Nothing to echo!");
        return undef;
    }
}

sub readCmd($)
{
    my ($args) = @_;
    
    if ($args =~ /^(.*\s+|)($idPat)$/o)
    {
        my $options = defined($1) ? trimWhitespace($1) : "";
        my $varName = $2;
        return "set $varName to my $readSubName(\"$options\")";
    }
    else
    {
        my $options = $args;
        return "my $readSubName(\"$options\")";
    }
}

sub showCmd()
{
    my $applescript = composeApplescript(0);
    output($applescript) if $applescript ne "";
    
    return undef;
}

sub editorCmd()
{
    my $currScript = escapeDoubleQuotes(composeApplescript(0));
    my $editorScript = "$editorSub\n"
                     . "my $editorSubName(\"$currScript\")";
    my ($result, $errMsg) = executeApplescript($editorScript);
    if ($errMsg)
    {
        errorOutput("$editorCmd failed");
        debugMsg(1, "errMsg: $errMsg");
    }
    
    return undef;
}

sub rerunCmd()
{
    if (atToplevel())
    {
        my $currScript = composeApplescript(1);
        if ($currScript =~ /^\s*$/)
        {
            userError("Nothing to rerun");
        }
        else
        {
            runApplescript($currScript);
        }
    }
    else
    {
        userError("You can't use the \"$rerunCmd\" command when in a mode");
    }
    
    return undef;
}

sub clearCmd()
{
    clearCurrCommands();
    
    return undef;
}

sub clearSubCmd($)
{
    my ($args) = @_;

    if ($args && $args =~ /^$idPat$/o)
    {
        my $subName = $args;
        if (defined($userSubs{$subName}))
        {
            delete($userSubs{$subName});
        }
        else
        {
            userError("There is no subroutine named \"$subName\"");
        }
    }
    else
    {
        userError("Invalid $clearSubCmd command");
    }
    
    return undef;
}

sub clearScriptCmd($)
{
    my ($args) = @_;

    if ($args && $args =~ /^$idPat$/o)
    {
        my $scriptName = $args;
        if (defined($userScriptObjs{$scriptName}))
        {
            delete($userScriptObjs{$scriptName});
        }
        else
        {
            userError("There is no script object named \"$scriptName\"");
        }
    }
    else
    {
        userError("Invalid $clearScriptCmd command");
    }
    
    return undef;
}

sub clearVarCmd($)
{
    my ($args) = @_;

    if ($args && $args =~ /^$idPat$/o)
    {
        my $varName = $args;
        my $lcVarName = lc($varName);
        if (defined($userVars{$lcVarName}) or defined($userProps{$lcVarName}))
        {
            delete($userProps{$lcVarName});
            delete($userVars{$lcVarName});
        }
        else
        {
            userError("There is no variable or property named \"$varName\"");
        }
    }
    else
    {
        userError("Invalid $clearVarCmd command");
    }
    
    return undef;
}

sub clearAllCmd()
{
    clearAll();
    
    return undef;
}

sub cdCmd($)
{
    my ($args) = @_;

    if ($args ne "")
    {
        if ($args =~ /^-f\s*$/) # -f option: to cd to current Finder folder
        {
            my $currFinderDir = currentFinderDir();
            if ($currFinderDir eq "unknown")
            {
                errorOutput("Failed to determine current Finder folder");
            }
            else
            {
                chdir($currFinderDir)
                      or warn "Failed to cd to \"$currFinderDir\": $!\n";
            }
        }
        else
        {
            my $dirpath = cleanFilepath($args);
            chdir($dirpath) or warn "Failed to cd to \"$dirpath\": $!\n";
        }
    }
    else # no args, so cd to home dir
    {
        chdir() or warn "$!\n";
    }
    
    system('pwd') unless $quiet;
    return undef;
}

sub unixCmd($)
{
    my ($args) = @_;
    
    if ($args ne "")
    {
        system($args);
    }
    else
    {
        userError("Empty command!");
    }
    
    return undef;
}

sub createManPageCmd()
{
    createManPage();
    
    return undef;
}

sub useReadLineCmd($)
{
    my ($args) = @_;
    
    if ($args ne "")
    {
        if ($args =~ /^(0|1)$/)
        {
            $useReadLine = $1;
        }
        else
        {
            userError("The $useReadLineCmd command argument must be 0 or 1");
        }
        
        output($useReadLine ? "ReadLine is enabled" : "ReadLine is disabled")
                 unless $quiet;
    }
    else
    {
        output($useReadLine ? "ReadLine is enabled" : "ReadLine is disabled");
    }
    
    return undef;
}

sub debugCmd($)
{
    my ($args) = @_;
    
    # using any debug command resets $quiet
    if ($quiet)
    {
        $quiet = 0;
        output("Coming out of quiet mode since a debug command was used");
    }
    
    if ($args ne "")
    {
        if ($args =~ /^[+-]?\d+$/)
        {
            $debugLevel = $args;
        }
        else
        {
            userError("The $debugCmd command takes an integer");
        }

        output("Current debug level: $debugLevel");
    }
    else
    {
        output("Current debug level: $debugLevel");
    }
    
    return undef;
}

sub timingCmd($)
{
    my ($args) = @_;
    
    if ($args ne "")
    {
        if ($args =~ /^(0|1)$/)
        {
            $timing = $1;
        }
        else
        {
            userError("The $timingCmd command argument must be 0 or 1");
        }
        
        output($timing ? "Timing is enabled" : "Timing is disabled")
                 unless $quiet;
    }
    else
    {
        output($timing ? "Timing is enabled" : "Timing is disabled");
    }
    
    return undef;
}

sub setOsaMethod($)
{
    my ($method) = @_;
    
    my $errMsg = "";
    
    if ($osaMethods{$method})
    {
        $osaMethod = $method;
    }
    else
    {
        $errMsg = "Unrecognized method ($method)\n"
                . "(Available methods: $availOsaMethodsNames)";
    }
    
    return $errMsg;
}

sub osaMethodCmd($)
{
    my ($args) = @_;

    if ($args ne "")
    {
        my $method = $args;
        my $errMsg = setOsaMethod($method);
        userError($errMsg) if $errMsg;
        output("Current osaMethod: $osaMethod") unless $quiet;
    }
    else
    {
        output("Current osaMethod: $osaMethod");
    }
    
    return undef;
}


# Handling of special commands:
# -----------------------------

sub registerSpecialCmd($$$)
{
    my ($name, $hasArgs, $sub) = @_;
    
    # we register the commands via the lowercase version of their names
    # so as to enable case-insensitivity in command processing
    
    $specialCmds{lc($name)} = {
                                  'name'        => $name,
                                  'hasArgs'     => $hasArgs,
                                  'sub'         => $sub,
                              };
}

sub registerSpecialCmds()
{
    #                   name       takesArgs  subroutine
    registerSpecialCmd($helpCmd,        1,   \&helpCmd);
    registerSpecialCmd($exitCmd,        0,   \&exitCmd);
    
    registerSpecialCmd($abbrevCmd,      1,   \&abbrevCmd);
    registerSpecialCmd($unabbrevCmd,    1,   \&unabbrevCmd);
    
    registerSpecialCmd($batchCmd,       1,   \&batchCmd);
    registerSpecialCmd($endBatchCmd,    1,   \&endBatchCmd);
    
    registerSpecialCmd($sourceCmd,      1,   \&sourceCmd);
    registerSpecialCmd($echoCmd,        1,   \&echoCmd);
    registerSpecialCmd($readCmd,        1,   \&readCmd);
    
    registerSpecialCmd($showCmd,        0,   \&showCmd);
    registerSpecialCmd($editorCmd,      0,   \&editorCmd);
    registerSpecialCmd($rerunCmd,       0,   \&rerunCmd);
    
    registerSpecialCmd($clearCmd,       0,   \&clearCmd);
    registerSpecialCmd($clearSubCmd,    1,   \&clearSubCmd);
    registerSpecialCmd($clearScriptCmd, 1,   \&clearScriptCmd);
    registerSpecialCmd($clearVarCmd,    1,   \&clearVarCmd);
    registerSpecialCmd($clearAllCmd,    0,   \&clearAllCmd);
    
    registerSpecialCmd($cdCmd,          1,   \&cdCmd);
    registerSpecialCmd($unixCmd,        1,   \&unixCmd);
    registerSpecialCmd($createManCmd,   0,   \&createManPageCmd);
    
    registerSpecialCmd($useReadLineCmd, 1,   \&useReadLineCmd);
    registerSpecialCmd($debugCmd,       1,   \&debugCmd);
    registerSpecialCmd($osaMethodCmd,   1,   \&osaMethodCmd);
    registerSpecialCmd($timingCmd,      1,   \&timingCmd);
    
    debugMsg(2, "specialCmds: " . join(",", sort keys %specialCmds));
}

# checkIfSpecial: checks if the specified command starts with $specialPrefix
# and if so, returns the name of the command and the rest of the line
# as ($name, $args) both of which have been trimmed of whitespace.
# Note that this function doesn't check if the command is registered
# - this allows us to use this function when handling abbreviations, etc
sub checkIfSpecial($)
{
    my ($command) = @_;
    
    my $name;
    my $args;
    
    if ($command =~ /^($specialPrefix[\w!]+)\s*(.*)$/o)
    {
        my $name = $1;
        my $args = defined($2) ? trimWhitespace($2) : "";
        
        return ($name, $args);
    }
    else
    {
        # return values that will eval to false if used in an 'if' statement
        return wantarray ? () : 0;
    }
}

# returns the value returned from the special command's handler
# (this value is either 'undef' or an AppleScript command to be executed)
sub specialCommand($$)
{
    my ($name, $args) = @_;
        
    # we look up the commands via the lowercase version of their names
    # since that is how they were registered
    
    my $asCmd = undef;
    my $specialCmd = $specialCmds{lc($name)};
    if ($specialCmd)
    {
        my $sub = $specialCmd->{sub};
        if ($specialCmd->{hasArgs})
        {
            # note that $args has already been trimmed of whitespace
            $asCmd = &$sub($args);
        }
        else
        {
            if ($args ne "")
            {
                userError("The $name command does not take any arguments");
            }
            else
            {
                $asCmd = &$sub();
            }
        }
    }
    else
    {
        userError("Unrecognized special command \"$name\" ignored");
    }
    
    return $asCmd;
}


# Command processing:
# -------------------
sub processCommand($$)
{
    my ($command, $showPending) = @_;
    
    # showPending is 0 if non-interactive, 1 if interactive unless doing -source

    chomp($command);
    debugMsg(2, "processCommand-1: $command");

    # reset the error count before each command is processed
    $numErrors = 0;
    
    return if $command =~ /^\s*$/;  # ignore blank lines
    return if $command =~ /^\s*#/;  # ignore lines starting with '#' (comments)

    $command = trimWhitespace($command);
    $command = handleAbbreviations($command);
    debugMsg(3, "processCommand-2: $command");

    my $asCmd;
    if (my ($name, $args) = checkIfSpecial($command))
    {
        $asCmd = specialCommand($name, $args);
    }
    else
    {
        $asCmd = $command;
    }

    if (defined($asCmd))
    {
        applescriptCommand($asCmd);
        showCurrCommands() if $showPending;
        
        if (atToplevel() && $batchMode == 0)
        {
            runApplescriptAndStore();
        }
    }
}

sub sourceFile($$)
{
    my ($filepath, $batch) = @_;

    unless (-f $filepath)
    {
        userError("The file \"$filepath\" does not exist");
        return;
    }

    unless (isTextFile($filepath))
    {
        userError("The file \"$filepath\" is not a text file");
        return;
    }
    
    output("Sourcing \"$filepath\"") unless $quiet;
    open(FILE, "<$filepath")
                or warn "Can't open \"$filepath\": $!\n" and return;
                
    if ($batch)
    {
        startBatchMode();
    }
    
    while(<FILE>)
    {
        processCommand($_, 0);
        
        if ($numErrors > 0)
        {
            errorOutput("Stopped sourcing \"$filepath\" due to error(s)");
            errorOutput("Problem was on line $.");
            last;
        }
    }
    close(FILE);
    
    if ($batch && ($numErrors == 0))
    {
        endBatchMode();
    }
}

sub sourceAshrc()
{    
    my $ashrcFile = "$homeDir/$ashrc";
    if (-f $ashrcFile)
    {
        sourceFile($ashrcFile, 0);
    }
}

sub greeting()
{
    output("Welcome to $ash ($ashLongName) version $version\n"
           . "Type: $helpCmd for help, type $exitCmd to exit") unless $quiet;
}

# prompt: outputs the 'ash' prompt
# (this function is not used if using Term::ReadLine)
sub prompt()
{
    outputBlankLine();
    outputWithoutNewline(getPrompt());
}

sub interactiveLoop()
{    
    greeting() unless $nogreeting;
    sourceAshrc() unless $norc;
    $numApplescriptsRun = 0;
    
    my $term; # used with Term::ReadLine
    if ($useReadLine)
    {
        require Term::ReadLine;
        $term = new Term::ReadLine "$ashLongName";
    }
    else
    {
        prompt();
    }
    
    my $continuedLine = "";
    while (defined($_ = $useReadLine ? $term->readline(getPrompt()) : <>))
    {
        while (s/$lineContCharPat\s*$//o)
        {
            chomp;
            outputWithoutNewline(">") unless $useReadLine;
            $_ .= ($useReadLine ? $term->readline(">") : <>);
        }
        
        processCommand($_, 1);
        exit(0) if ($oneoff && $numApplescriptsRun > 0);
        
        prompt() unless $useReadLine;
    }
}

sub nonInteractiveLoop()
{
    startBatchMode();
    while (<>)
    {
        while (s/$lineContCharPat\s*$//o)
        {
            chomp;
            $_ .= <>;
        }
        
        processCommand($_, 0);
        
        if ($numErrors > 0)
        {
            last;
        }
    }
    continue
    {
        # reset line numbering on each input file
        close ARGV if eof; # Not eof()! (eof with parentheses is different)
    }
    
    if ($numErrors == 0)
    {
        endBatchMode();
    }
    else
    {
        errorOutput("$ash script aborted due to error(s)");
        errorOutput("Problem was on line $.");
        exit(1);
    }
}

sub usageError()
{
    my $modeOptions = "[-norc] [-nogreeting] [-quiet] [-oneoff] [-trace]";
    my $debugOptions = "[-debug level] [-timing level] [-osaMethod method]";
    my $options = "$modeOptions\n$debugOptions";
    errorOutput("Usage: $ash $options [file(s)]");
    exit(1);
}

sub handleCommandLineOptions()
{
    use Getopt::Long;

    GetOptions(
                  'nogreeting'   => \$nogreeting,
                  'quiet'        => \$quiet,
                  'norc'         => \$norc,
                  'oneoff'       => \$oneoff,
                  'trace'        => \$traceLevel,
                  'debug=i'      => \$debugLevel,
                  'timing=i'     => sub
                                    {
                                        $timing = $_[1];
                                        unless ($timing == 0 || $timing == 1)
                                        {
                                            $timing = 0;
                                            die "timing level must be 0 or 1\n";
                                        }
                                    },
                  'osaMethod=s'  => sub
                                    {
                                        my $method = $_[1];
                                        my $errMsg = setOsaMethod($method);
                                        die "$errMsg\n" if $errMsg;
                                    },
              ) or usageError();

    if ($debugLevel > 0)
    {
        # using debugging countermands quiet
        $quiet = 0;
    }
    
    if (scalar(@ARGV) == 0 && -t STDIN && -t STDOUT)
    {
        debugMsg(1, "$ash is running interactively");
        $interactive = 1;
    }
    else
    {
        debugMsg(1, "$ash is running non-interactively");
        $interactive = 0;
    }
}

MAIN:
{
    registerSpecialCmds();
    registerApplescriptCmds();
    
    handleCommandLineOptions();
        
    if ($interactive)
    {
        interactiveLoop();
    }
    else
    {
        nonInteractiveLoop();
    }
}

