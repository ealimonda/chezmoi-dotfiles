#!/usr/bin/perl
#*******************************************************************************************************************
##* Config files                                                                                                    *
##*******************************************************************************************************************
##* File:             iTermColorize.pl                                                                              *
##* Copyright:        (c) 2012 alimonda.com; Emanuele Alimonda                                                      *
##*                   Public Domain                                                                                 *
##*******************************************************************************************************************

use strict;
use Getopt::Long ();

our %opts = {
	verbose => 0,
	tmuxoverride => 1,
	preview => 0,
};

sub usage {
	my $message = $_[0];
	if (defined $message && length $message) {
		$message .= "\n"
		unless $message =~ /\n$/;
	}

	my $command = $0;
	$command =~ s#^.*/##;

	print STDERR (
		$message,
		"Usage: $command <0-1.0> <0-1.0> [optional name] # Lightness and saturation values\n" .
		"Colorize terminal tab based on the current host name, and an optional name suffix.\n" .
		"An iTerm 2 example (recolorize dark grey background and black text):\n" .
		"  $command 0.7 0.4\n"
	);
	die("\n");
}

sub hashCode {
	my $hash = 0;
	use integer;
	foreach(split //,shift) {
		$hash = (127*abs($hash)+ord($_))%4194304;
	}
	print "Hash: $hash\n" if $opts{verbose} ge 3;
	return $hash;
}

sub get_random_by_string {
	# Get always the same 0...1 random number based on an arbitrary string
	# Initialize random gen by server name hash
	return hashCode(shift)/4194304;
}

sub decorate_terminal {
	# Set terminal tab / decoration color.

	# Please note that iTerm 2 / Konsole have different control codes over this.
	# Note sure what other terminals support this behavior.

	#:param color: tuple of (r, g, b)

	my ($red, $green, $blue) = @_;
	print "R:$red G:$green B:$blue\n" if $opts{verbose} ge 1;

	# iTerm 2
	# http://www.iterm2.com/#/section/documentation/escape_codes"
	#sys.stdout.write("\033]6;1;bg;red;brightness;%d\a" % int(r * 255))
	#sys.stdout.write("\033]6;1;bg;green;brightness;%d\a" % int(g * 255))
	#sys.stdout.write("\033]6;1;bg;blue;brightness;%d\a" % int(b * 255))
	my ($prefix, $suffix);
	($prefix, $suffix) = ("\033Ptmux;\033", "\033\\") if ($opts{tmuxoverride} and exists $ENV{TMUX});
	print "$prefix\033]6;1;bg;red;brightness;${red}\a$suffix" unless $opts{preview};
	print "$prefix\033]6;1;bg;green;brightness;${green}\a$suffix" unless $opts{preview};
	print "$prefix\033]6;1;bg;blue;brightness;${blue}\a$suffix" unless $opts{preview};

	# Konsole
	# TODO
	# http://meta.ath0.com/2006/05/24/unix-shell-games-with-kde/
}


sub rainbow_unicorn {
	# Colorize terminal tab by your server name.

	# Create a color in HSL space where lightness and saturation is locked, tune only hue by the server.

	# http://games.adultswim.com/robot-unicorn-attack-twitchy-online-game.html

	my ($lightness, $saturation, $extraname) = @_;
	my $name = `hostname -f`;
	$name = "$name/$extraname" if $extraname;
	print "Name: $name\n" if $opts{verbose} ge 2;

	my $hue = get_random_by_string($name);

	my ($r, $g, $b) = hsv_to_rgb($hue, $saturation, $lightness);
	#my ($r, $g, $b) = hsv_to_rgb(0.7,0.4,0.7);

	decorate_terminal($r, $g, $b);
}

sub hsv_to_rgb {
	my ($h,$s,$v) = @_;

	# handle greyscale case
	return ($v,$v,$v) if ($s == 0);

	my ($i, $f, $p, $q, $t);

	$h = int($h * 360);

	$h /= 60;  # convert to sector between 0 and 5
	$i = int($h);
	$f = $h - $i;
	$p = int(255 * $v * (1-$s));
	$q = int(255 * $v * (1-$s*$f));
	$t = int(255 * $v * (1-$s*(1-$f)));
	$v = int(255 * $v);

	return ($v, $t, $p) if $i == 0;
	return ($q, $v, $p) if $i == 1;
	return ($p, $v, $t) if $i == 2;
	return ($p, $q, $v) if $i == 3;
	return ($t, $p, $v) if $i == 4;
	return ($v, $p, $q);
}

Getopt::Long::GetOptions(
	'tmux!' => \$opts{tmuxoverride},
	'v+' => \$opts{verbose},
	'preview' => \$opts{preview},
) or usage("Invalid commmand line options.");

usage("Invalid command line options.") if $#ARGV < 1;

my ($lightness, $saturation, $name) = @ARGV;

rainbow_unicorn($lightness, $saturation, $name)
