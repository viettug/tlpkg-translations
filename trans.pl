#!/usr/bin/env perl
# $Id: trans.pl 14198 2009-07-09 11:39:06Z preining $
#
# Copyright 2009 Norbert Preining
# This file is licensed under the GNU General Public License version 2
# or any later version.
#
# translation infrastructure for TeX Live programs
# if $::lang is set then that one is used
# if $::lang is unset try to auto-deduce it from LC_MESSAGES/Registry
# if $::opt_lang is set use that instead
#
# this module implements parsing .po files, but no specialities of .po
# files are supported. Only reading of msgstr and msgid and concatenating
# multiple lines. Furthermore, strings replacements are done:
#    \n  -> <newline>
#   \"   -> "
#   \\   -> \
#

use strict;
$^W = 1;

use utf8;
no utf8;

if (defined($::opt_lang)) {
  $::lang = $::opt_lang;
  if ($::lang eq "zh") {
    # set language to simplified chinese
    $::lang = "zh-cn";
  }
} else {
  if ($^O =~ /^MSWin(32|64)$/i) {
    # trying to deduce automatically the country code
    my $foo =  TeXLive::TLWinGoo::reg_country();
    if ($foo) {
      $::lang = $foo;
    } else {
      debug("Didn't get any usuful code from reg_country: $foo...\n");
    }
  } else {
    # we load POSIX and locale stuff
    require POSIX;
    import POSIX qw/locale_h/;
    # now we try to deduce $::lang
    my $loc = setlocale(&POSIX::LC_MESSAGES);
    my ($lang,$area,$codeset);
    if ($loc =~ m/^([^_.]*)(_([^.]*))?(\.([^@]*))?(@.*)?$/) {
      $lang = defined($1)?$1:"";
      $area = defined($3)?$3:"";
      if ($lang eq "zh") {
        if ($area =~ m/^(TW|HK)$/i) {
          $lang = "zh-tw";
        } else {
          # fallback to zh-cn for anything else, that is
          # zh-cn, zh-sg, zh, and maybe something else
          $lang = "zh-cn";
        }
      }
    }
    $::lang = $lang if ($lang);
  }
}


our %TRANS;

#
# __ takes a string argument and checks that it 
sub __ ($) {
  my $key = shift;
  my $ret;
  # if no $::lang is set just return without anything
  if (!defined($::lang)) {
    $ret = $key;
  } else {
    $ret = $key;
    $key =~ s/\\/\\\\/g;
    $key =~ s/\n/\\n/g;
    $key =~ s/"/\\"/g;
    # if the translation is defined return it
    if (defined($TRANS{$::lang}->{$key})) {
      $ret = $TRANS{$::lang}->{$key};
      if ($::debug_translation && ($key eq $ret)) {
        print STDERR "probably untranslated in $::lang: >>>$key<<<\n";
      }
    } else {
      # if we cannot find it, return $s itself
      if ($::debug_translation && $::lang ne "en") {
        print STDERR "no translation in $::lang: >>>$key<<<\n";
      }
      # $ret is already set initially
    }
  }
  # translate back $ret:
  $ret =~ s/\\n/\n/g;
  $ret =~ s/\\"/"/g;
  $ret =~ s/\\\\/\\/g;
  return $ret;
}

if (($::lang ne "en") && ($::lang ne "C")) {
  if (! -r "$::installerdir/tlpkg/translations/$::lang.po") {
    tlwarn ("\n  Sorry, no translations available for $::lang; falling back to English.
  (If you'd like to help translate the installer's messages, please see
  http://tug.org/texlive/doc.html#install-tl-xlate for information.)\n\n");
  } else {
    # merge the translated strings into the text string
    open(LANG, "<$::installerdir/tlpkg/translations/$::lang.po");
    my $msgid;
    my $msgstr;
    my $inmsgid;
    my $inmsgstr;
    while (<LANG>) {
      chomp;
      next if m/^\s*#/;
      if (m/^\s*$/) {
        if ($inmsgid) {
          debug("msgid $msgid without msgstr in $::lang.po\n");
          $inmsgid = 0;
          $inmsgstr = 0;
          $msgid = "";
          $msgstr = "";
          next;
        }
        if ($inmsgstr) {
          if ($msgstr) {
            if (!utf8::decode($msgstr)) {
              warn("decoding string to utf8 didn't work: $msgstr\n");
            }
            # we decode msgid too to get \\ and not \
            if (!utf8::decode($msgid)) {
              warn("decoding string to utf8 didn't work: $msgid\n");
            }
            $TRANS{$::lang}{$msgid} = $msgstr;
          } else {
            ddebug("untranslated $::lang: ...$msgid...\n");
          }
          $inmsgid = 0;
          $inmsgstr = 0;
          $msgid = "";
          $msgstr = "";
          next;
        }
        next;
      }
      if (m/^msgid\s+"(.*)"\s*$/) {
        if ($msgid) {
          warn("stray msgid line: $_");
          next;
        }
        $inmsgid = 1;
        $msgid = $1;
        next;
      }
      if (m/^"(.*)"\s*$/) {
        if ($inmsgid) {
          $msgid .= $1;
        } elsif ($inmsgstr) {
          $msgstr .= $1;
        } else {
          tlwarn("cannot parse $::lang.po line: $_\n");
        }
        next;
      }
      if (m/^msgstr\s+"(.*)"\s*$/) {
        if (!$inmsgid) {
          tlwarn("msgstr $1 without msgid\n");
          next;
        }
        $msgstr = $1;
        $inmsgstr = 1;
        $inmsgid = 0;
      }
    }
    close(LANG);
  }
}


1;

__END__

### Local Variables:
### perl-indent-level: 2
### tab-width: 2
### indent-tabs-mode: nil
### End:
# vim:set tabstop=2 expandtab: #

