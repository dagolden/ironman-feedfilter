#!/usr/bin/env perl
# feedfilter.pl - downloads and filters the Perl Ironman feed for English
# entries. Results sent to STDOUT.
#
# The heuristic filters out entries unless the content is mostly latin
# characters and English is close to the best guess of a language.  Short
# entries with code seem to confuse Lingua::Identify, so we take entries that
# seem "close-enough".  Tuned via trial-and-error.
#
# Copyright (c) 2010 by David Golden - This may be used or copied under the
# same terms as Perl itself.

use 5.008001;
use strict;
use warnings;
use utf8;
use autodie;

use IO::File;
use Lingua::Identify qw(:language_identification);
use Time::Piece;
use URI;

use XML::Atom::Feed;
$XML::Atom::ForceUnicode = 1;
$XML::Atom::DefaultVersion = "1.0";

# Global heuristic tuning
my $latin_target = 0.95;  # 95% latin chars
my $lang_fuzz = 0.02;     # English within 2% probability of best language

run();

#--------------------------------------------------------------------------#

sub latin_ratio {
  my $string = shift;
  my $alpha =()= $string =~ /(\p{Alphabetic})/g;
  my $latin =()= $string =~ /(\p{Latin})/g;
  
  return 0 if ! $latin || !$alpha; # !$alpha probably redundant
  return $latin / $alpha;
}

sub run {
  my $ironman_url = "http://ironman.enlightenedperl.org";
  my $in_feed = XML::Atom::Feed->new(URI->new($ironman_url));
  unless ($in_feed) {
    warn "Couldn't read $ironman_url.  Exiting.\n";
    exit;
  }

  my $out_feed = XML::Atom::Feed->new;
  $out_feed->title("Planet Iron Man: English Edition");
  $out_feed->subtitle( $in_feed->subtitle );
  $out_feed->id("tag:feeds.dagolden.com,".gmtime->year().":ironman:english");
  $out_feed->generator("XML::Atom/" . XML::Atom->VERSION);
  $out_feed->updated( gmtime->datetime . "Z" );
  for my $l ( $in_feed->link ) {
    $out_feed->link($l);
  }

  for my $e ( $in_feed->entries ) {
    my $content = $e->content->body;
    my $latin = latin_ratio($content);
    my %lang = langof($content);
    my $best = [sort { $lang{$b} <=> $lang{$a} } keys %lang]->[0];
    $lang{en} ||= 0;
    $out_feed->add_entry($e)
      if $latin > $latin_target && ($lang{$best} - $lang{en} < $lang_fuzz);
  }

  my $outfile = "$ENV{HOME}/feeds.dagolden.com/ironman-english.xml";
  open my $out_fh, ">", "$outfile\.$$";
  binmode($out_fh, ":utf8");
  print {$out_fh} $out_feed->as_xml;
  close $out_fh;
  rename "$outfile\.$$", $outfile;
  exit;
}

# vim: ts=2 sts=2 sw=2:
