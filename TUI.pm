package Term::TUI;
# Copyright (c) 1999-2007 Sullivan Beck. All rights reserved.
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.

########################################################################
# TODO
########################################################################

# improve completion:
#    /math
#    ad<TAB>
# completes correctly to add but
#    /math/ad<TAB>
# doesn't autocomplete.

# add abbreviation

# case insensitivity

# add .. and . to valid mode strings

# "Hr. Jochen Stenzel" <Jochen.Stenzel.gp@icn.siemens.de>
#    alias command
#    history file (stored last commands)

# config file (store commands to execute)

########################################################################
# HISTORY
########################################################################

# Written by:
#    Sullivan Beck (sbeck@cpan.org)
# Any suggestions, bug reports, or donations :-) should be sent to me.

# Version 1.00  1999-11-03
#    Initial creation
#
# Version 1.10  1999-12-03
#    Added simple test file to make automatic CPAN scripts work nicer.
#
# Version 1.20  2005-06-29
#    Added command completion.  Patch provided by mmcclure@pneservices.com
#      Requires Term::ReadLine::Gnu
#    Changed split to Text::ParseWords::shellwords.  mmcclure@pneservices.com

use vars qw($VERSION);
$VERSION="1.20";

########################################################################

require 5.000;
require Exporter;

use Term::ReadLine;
use Text::ParseWords;
#use Text::Abbrev;

@ISA = qw(Exporter);
@EXPORT = qw(TUI_Run);
@EXPORT_OK = qw(TUI_Script TUI_Out TUI_Version);
%EXPORT_TAGS = (all => [ @EXPORT, @EXPORT_OK ]);

use strict "vars";

sub TUI_Version {
  return $VERSION;
}

BEGIN {
  my($term,$out);

  #
  # Takes a program name (to be used in the prompt) and an interface
  # description, and runs with it.
  #

  #
  # Interactive version.
  #
  sub TUI_Run {
    my($program,$hashref)=@_;
    my(@mode,$line,$err);
    my($prompt)="$program> ";
    $term=new Term::ReadLine $program;
    $term->ornaments(0);

    # Command line completion
    $term->Attribs->{'do_expand'}=1;
    $term->Attribs->{'completion_entry_function'} =
        $term->Attribs->{'list_completion_function'};

    $out=$term->OUT || STDOUT;

    my($ret)=0;

    # Command line completion
    # The strings for completion
    my(@completions) = GetStrings(\@mode,$hashref);
    $term->Attribs->{'completion_word'} = \@completions;

    while (defined ($line=$term->readline($prompt)) ) {
      $err=Line(\@mode,$hashref,$line);

      # Command line completion
      @completions = GetStrings(\@mode,$hashref);
      $term->Attribs->{'completion_word'} = \@completions;

      if ($err =~ /^exit\[(\d+)\]$/) {
        $ret=$1;
        last;
      }
      print $out $err  if ($err && $err !~ /^\d+$/);

      if (@mode) {
        $prompt=$program . ":" . join("/",@mode) . "> ";
      } else {
        $prompt="$program> ";
      }
    }
    return $ret;
  }

  #
  # Non-interactive version.
  #
  sub TUI_Script {
    my($hashref,$script,$sep)=@_;
    $out=STDOUT;

    $sep=";"  if (! $sep);
    my(@cmd)=split(/$sep/,$script);

    my($err,$cmd,@mode);
    my($ret)=0;
    foreach $cmd (@cmd) {
      $err=Line(\@mode,$hashref,$cmd);
      if ($err =~ /^exit\[(\d+)\]$/) {
        $ret=$1;
        last;
      }
      print $out $err  if ($err);
    }
    return $ret;
  }

  #
  # Prints a message.
  #
  sub TUI_Out {
    my($mess)=@_;
    print $out $mess;
  }
}


########################################################################
# NOT FOR EXPORT
########################################################################

{
  # Stuff for doing completion.

  my $i;
  my @matches;

  sub TUI_completion_function {
    my($text,$state)=@_;
    $i = ($state ? $i : 0);

    if (! $i) {
      if ($text =~ /^\s*(\S+)\s+(\S+)$/) {
        # MODE CMD^
        #    completes CMD
        # MODE/CMD OPTION^
        #    no matches

      } elsif ($text =~ /^\s*(\S+)\s+$/) {
        # MODE ^
        #    completes CMD
        # MODE/CMD ^
        #    no matches

      } elsif ($text =~ /^\s*(\S+)$/) {
        # MODE^
        # MODE/CMD^

      } else {
        @matches=();
      }
    }
  }
}

#
# Takes the current mode (as a list), the interface description, and
# the current line and acts on the line.
#
sub Line {
  my($moderef,$cmdref,$line)=@_;

  $line =~ s/\s+$//;
  $line =~ s/^\s+//;
  return  if (! $line);

  my(@cmd)=shellwords($line);
  return Cmd($moderef,$cmdref,@cmd);
}

BEGIN {
  my(%Cmds) =
    (
     ".."     => [ "Go up one level",     "Mode",0 ],
     "/"      => [ "Go to top level",     "Mode",1 ],
     "help"   => [ "Online help",         "Help"   ],
     "exit"   => [ "Exit",                "Exit",0 ],
     "quit"   => [ "An alias for exit",   "Exit",0 ],
     "abort"  => [ "Exit without saving", "Exit",1 ]
    );
  my($Moderef,$Cmdref);

  #
  # Returns an array of strings (commands or modes) that can be
  # entered given a mode
  #
  sub GetStrings {
    my ($moderef,$cmdref) = @_;
    my @strings;

    if (!defined $Cmdref || ref $Cmdref ne "HASH") {
      $Cmdref = $cmdref;
    }
    my $desc = GetMode(@{$moderef});
    if ( ref $desc eq "HASH" ) {
      @strings = grep !/^\./, sort keys %$desc;
    }
    push @strings,keys %Cmds;
    return @strings;
  }

  #
  # Takes the current mode (as a list), the interface description, and the
  # current command (as a list) and executes the command.
  #
  sub Cmd {
    my($moderef,$cmdref,@args)=@_;
    my($cmd)=shift(@args);
    $Moderef=$moderef;
    $Cmdref=$cmdref;
    my(@mode,$desc,$mode,$help);

    if (exists $Cmds{lc $cmd}) {
      $desc=$Cmds{lc $cmd};

    } else {
      ($mode,@mode)=CheckMode(\$cmd);

      if ($mode && $cmd) {
        #
        # MODE/CMD [ARGS]
        # CMD [ARGS]
        #
        $desc=CheckCmd($mode,$cmd);

      } elsif ($mode && @args) {
        #
        # MODE CMD [ARGS]
        #
        $cmd=shift(@args);
        $desc=CheckCmd($mode,$cmd);

      } elsif ($mode) {
        #
        # MODE
        #
        $desc=[ "","Mode",2,@mode ]
      }
    }

    my(@args0);
    if (ref $desc eq "ARRAY") {
      ($help,$cmd,@args0)=@$desc;
      if (! defined &$cmd) {
        $cmd="::$cmd";
        if (! defined &$cmd) {
          return "ERROR: invalid subroutine\n";
        }
      }
      return &$cmd(@args0,@args);
    } else {
      return "ERROR: unknown command\n";
    }
  }

  #
  # Takes a mode and/or command (as a list) and determines the mode
  # to use.  Returns a description of that mode.
  #
  sub CheckMode {
    my($cmdref)=@_;
    my($cmd)=$$cmdref;
    my(@mode,$tmp2);

    if ($cmd =~ s,^/,,) {
      @mode=split(m|/|,$cmd);
    } else {
      @mode=(@$Moderef,split(m|/|,$cmd));
    }

    my($tmp)=GetMode(@mode);
    if ($tmp) {
      $$cmdref="";
    } else {
      $tmp2=pop(@mode);
      $tmp=GetMode(@mode);
      $$cmdref=$tmp2  if ($tmp);
    }

    @mode=()  if (! $tmp);
    return ($tmp,@mode);
  }

  #
  # Takes a mode (as a list) and returns it's description (or "" if it's
  # not a mode).
  #
  sub GetMode {
    my(@mode)=@_;
    my($tmp)=$Cmdref;
    my($mode);

    foreach $mode (@mode) {
      if (exists $$tmp{$mode}  &&
          ref $$tmp{$mode} eq "HASH") {
        $tmp=$$tmp{$mode};
      } else {
        $tmp="";
        last;
      }
    }
    $tmp;
  }

  ##############################################

  #
  # A command to change the mode.
  #    ..    op=0
  #    /     op=1
  #    MODE  op=2
  #
  sub Mode {
    my($op,@mode)=@_;

    if ($op==0) {
      # Up one level
      if ($#$Moderef>=0) {
        pop(@$Moderef);
      } else {
        return "WARNING: Invalid operation\n";
      }

    } elsif ($op==1) {
      # Top
      @$Moderef=();

    } elsif ($op==2) {
      # Change modes
      @$Moderef=@mode;

    } else {
      return "ERROR: Invalid mode operation: $op\n";
    }
    return "";
  }

  sub Help {
    my($cmd,@args)=@_;

    my($tmp,$mode,@mode);

    ($tmp,@mode)=CheckMode(\$cmd)  if ($cmd);
    if (! $tmp) {
      @mode=@$Moderef;
      if (@mode) {
        $tmp=GetMode(@mode);
      } else {
        $tmp=$Cmdref;
      }
    }

    return "IMPOSSIBLE: invalid mode\n"  if (! $tmp);

    my($mess);
    $cmd=shift(@args)  if (! $cmd && @args);
    if ($cmd) {
      #
      # Help on a command
      #
      if (exists $Cmds{$cmd}) {
        $tmp=$Cmds{$cmd};
        $mess=$$tmp[0];

      } elsif (exists $$tmp{$cmd}) {
        $tmp=$$tmp{$cmd};
        if (ref $tmp  ne  "ARRAY") {
          $mess="Invalid command $cmd";
        } else {
          $mess=$$tmp[0];
          $mess="No help available"  if (! $mess);
        }
      } else {
        $mess="Invalid command: $cmd";
      }

    } else {
      #
      # Help on a mode
      #
      if (exists $$tmp{".HELP"}) {
        $mess=$$tmp{".HELP"};
        my(@gc)=sort grep /^([^.]|\.\.)/i,keys %Cmds;
        my(@cmd)=sort grep /^[^.]/,keys %{ $tmp };
        my(@m,@c)=();
        foreach $cmd (@cmd) {
          if (ref $$tmp{$cmd} eq "ARRAY") {
            push(@c,$cmd);
          } elsif (ref $$tmp{$cmd} eq "HASH") {
            push(@m,$cmd);
          }
        }
        $mess .= "\n\nAdditional help:\n\n";
        $mess .= "   Modes: @m\n"  if (@m);
        $mess .= "   Cmds : @gc";
        $mess .= "\n"              if (@c);
        $mess .= "          @c"    if (@c);

      } else {
        $mess="No help available";
      }
    }

    return "\n$mess\n\n";
  }
}

#
# Takes a mode and command and return a description of the command.
#
sub CheckCmd {
  my($moderef,$cmd)=@_;
  return $$moderef{$cmd}
    if (exists $$moderef{$cmd}  &&
        ref $$moderef{$cmd} eq "ARRAY");
  return ();
}

sub Exit {
  my($flag)=@_;
  return "exit[$flag]";
}

#    sub {
#      map {lc($_)} (keys %commands, keys %aliases)
#    };

#  $term->Attribs->{'do_expand'}=1;
#  $term->Attribs->{'completion_entry_function'} =
#    sub {
#      $term->Attribs->{'line_buffer'} =~ /\s/ ?
#        &{$term->Attribs->{'filename_completion_function'}}(@_) :
#          &{$term->Attribs->{'list_completion_function'}}(@_)
#        };
#  $term->Attribs->{'completion_word'}=[(map {lc($_)} (keys %commands))];

########################################################################
########################################################################
# POD
########################################################################
########################################################################

=pod

=head1 NAME

Term::TUI - simple tool for building text-based user interfaces

=head1 SYNOPSIS

If TUI_Run is the only routine being used:

  use Term::TUI;
  $flag=TUI_Run($command,\%desc);

  $version=Term::TUI::TUI_Version;

If other TUI subroutines are used:

  use Term::TUI qw(:all);
  $flag=TUI_Run($command,\%desc);

  TUI_Out($message);

  $flag=TUI_Script(\%desc,$script,$sep);

=head1 DESCRIPTION

Many times, I've wanted to quickly write a nice text-based user interface
around a set of perl routines only to end up writing the full (though
simple) parser and interface to make it nice enough, and friendly enough,
to be usable.

This module creates a simple but powerful text based user interface around
perl routines, adding such features as command line history, command line
editing, online help, and command completion, while hiding all details of
the interface from the programmer.

The interface is described in a simple hash which is passed to the
B<TUI_Run> command.  This routine exits only when the user has exited
the program (returning a flag signalling any special exit conditions).

=head1 ROUTINES

=over 4

=item TUI_Run

  use Term::TUI;
  $flag=TUI_Run($command,\%desc);

The TUI_Run command is used to run the interface.  It prompts the user
for commands and executes them (based on description of passed in as
%desc) until the user exits.  The return flag is 0 unless the user exited
with the Abort command when it is 1.

=item TUI_Script

  use Term::TUI qw(:all);
  $flag=TUI_Script(\%desc,$script [,$sep]);

This allows you to pass in commands in a "script" instead of an interactive
session.  The script is a series of commands separated by a semicolon
(or the string included in $sep).

=item TUI_Version

  use Term::TUI qw(:all);
  $vers=TUI_Version;

Returns the version of the module.

=item TUI_Out

  use Term::TUI qw(:all);
  TUI_Out($mess);

This is used in the routines given in the description hash to send a
message to STDOUT.

=back

=head1 INTERFACE DESCRIPTION

The interface allows you to describe multiple "modes" organized in
a simple tree-like hierarchy (or modes, submodes, subsubmodes, etc.),
each of which has it's own set of commands specific to that mode.  I've
modeled it after a unix filesystem with directories being "modes" and
executables being equivalent to commands.  So, you might want to model
the following tree:

      /
      +--------------------+
      math                 string
      |                    |
      +-----+-----+        +------+
      hex   add*  mult*    len*   subs*
      |
      +-----+
      add*  mult*

Here the "executables" are marked with asterixes(*). So in math mode, you
could type "add" or "mult" to add a list of numbers together or multiply
them together.  It also has a submode "hex" where you can do that in
hexidecimal.

I find this type of interface very conveniant in many cases, but a nuisance
to write.  This module handles this trivially.  The above interface can
be written with the following 2 perl commands:

   %modes =
    (".HELP"  => "This is the main help.\nNot a lot of info here.",
     "math"   => {".HELP" => "A simple calculator.  Currently it can\n" .
                             "only add and multiply in hex or decimal.",
                  "add"   => [ "Add numbers together."  ,    Add,0 ],
                  "mult"  => [ "Multiply numbers together.", Mult,0 ],
                  "hex"   => {".HELP"  => "Math in hex.",
                              "add"   => [ "Add hex numbers together.",
                                           Add,1 ],
                              "mult"  => [ "Multiply hex numbers together.",
                                           Mult,1 ]
                             }
                 },
     "string" => {".HELP" => "String operations",
                  "subs"  => [ "Take STRING,POS,LEN and returns substring.",
                               Substring ],
                  "len"   => [ "Returns the length of a string.",
                               Length ]
                 }
   );

   $flag=TUI_Run("sample",\%modes);
   print "*** ABORT ***\n"  if ($flag);

You also have to write an Add, Mult, Substring, and Length subroutine
of course, but once that's done, you end up with a rather nice text
based user interface.  The following are excerpts from a session using
the sample interface defined above:

Changing modes is trivial.  Just type in the new mode using a syntax
similar to the unix filesystem:

   sample> string
   sample:string> /math/hex
   sample:math/hex> ..
   sample:math> hex
   sample:math/hex> /
   sample>

When in a given mode, you can just type commands relevant to that
mode:

   sample:string> subs barnyard 1 3
     Substring = arn
   sample:string> len barnyard
     Length = 8

You can also explicitely type in the mode for a command.  In this
situation, commands can be typed as MODE/CMD ARGS or MODE CMD ARGS
 equivalently:

   sample:string> /math/hex/add 4 6 1
     Total = b
   sample:string> /math mult 4 6 2
     Total = 48

There are several built-in commands including "..", "/", "help",
"abort", "exit", and "quit".  The last two ("exit" and "quit")
are equivalent and mean to exit and return 0.  "abort" exits with
a value of 1.

There is also online help:

   sample> help

   This is the main help.
   Not a lot of info here.

   Additional help:

      Modes: math string
      Cmds : .. / abort exit help quit

   sample> help /string

   String operations

   Additional help:

      Cmds : .. / abort exit help quit
             len subs

   sample> math
   sample:math> help

   A simple calculator.  Currently it can only
   add and multiply in hex or decimal.

   Additional help:

      Modes: hex
      Cmds : .. / abort exit help quit
             add mult

   sample:math> help add

   Add numbers together.

   sample:math> help /string len

   Returns the length of a string.

   sample:math> help /string/subs

   Take STRING,POS,LEN and returns a substring.

Currently, Term::TUI does not have much in the way of bells and whistles,
and I doubt it ever will.  It's not designed for a full-blown, feature-rich
user interface.  It's mainly intended for simple control or config tools
(similar to lpc for example) used primarily by the sysadmin type people
(who else is interested in a text-based interface after all :-).

There is also a non-interactive form which allows the same interface to
be called in scripts.

   TUI_Script(\%modes,"/math add 3 5; string; subs barnyard 1 3");

returns

   Total = 8
   Substring = arn

TUI DOES use one of the Term::ReadLine modules for the interactive session,
so if you have Term::ReadLine::GNU or Term::ReadLine::Perl installed, you
can use things like command history and command line editing.

=head1 KNOWN PROBLEMS

None known at this point.

=head1 AUTHOR

Sullivan Beck (sbeck@cpan.org)

=cut

1;
# Local Variables:
# indent-tabs-mode: nil
# End:

