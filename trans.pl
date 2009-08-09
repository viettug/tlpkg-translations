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

sub __ ($) {
  my $s = shift;
  # if no $::lang is set just return without anything
  my $ss = $s;
  $ss =~ s/\\n/\n/g;
  return $ss if !defined($::lang);
  my $key = $s;
  $key =~ s/\n/\\n/g;
  # if the translation is defined return it
  if (defined($TRANS{$::lang}->{$key})) {
    my $t = $TRANS{$::lang}->{$key};
    $t =~ s/\n/\\n/g;
    if ($::debug_translation && ($s eq $t)) {
      print STDERR "probably untranslated in $::lang: >>>$key<<<\n";
    }
    return $TRANS{$::lang}->{$key};
  } 
  # if we cannot find it, return $s itself
  if ($::debug_translation && $::lang ne "en") {
    print STDERR "no translation in $::lang: >>>$key<<<\n";
  }
  return $ss;
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
            $msgid =~ s/\\"/"/g;
            $msgstr =~ s/\\n/\n/g;
            $msgstr =~ s/\\"/"/g;
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

