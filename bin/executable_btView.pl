#!/usr/bin/perl
## btView v0.1.1 {2012-06-09}
## Tux <http://gotux.net/>
## View files inside torrent.
#
# Edited not to require Bencode and DateTime
 
#use DateTime;
use Data::Dumper;
#use Bencode qw/bdecode/;

sub _bdecode_string {
	if ( m/ \G ( 0 | [1-9] \d* ) : /xgc ) {
		my $len = $1;

		croak _msg 'unexpected end of string data starting at %s'
		if $len > length() - pos();

		my $str = substr $_, pos(), $len;
		pos() = pos() + $len;

		#warn _msg STRING => "(length $len)", $len < 200 ? "[$str]" : () if $DEBUG;

		return $str;
	}
	else {
		my $pos = pos();
		if ( m/ \G -? 0? \d+ : /xgc ) {
			pos() = $pos;
			croak _msg 'malformed string length at %s';
		}
	}

	return;
}

sub _bdecode_chunk {
	#warn _msg 'decoding at %s' if $DEBUG;

	local $max_depth = $max_depth - 1 if defined $max_depth;

	if ( defined( my $str = _bdecode_string() ) ) {
		return $str;
	}
	elsif ( m/ \G i /xgc ) {
		croak _msg 'unexpected end of data at %s' if m/ \G \z /xgc;

		m/ \G ( 0 | -? [1-9] \d* ) e /xgc
			or croak _msg 'malformed integer data at %s';

		#warn _msg INTEGER => $1 if $DEBUG;
		return $1;
	}
	elsif ( m/ \G l /xgc ) {
		#warn _msg 'LIST' if $DEBUG;

		croak _msg 'nesting depth exceeded at %s'
		if defined $max_depth and $max_depth < 0;

		my @list;
		until ( m/ \G e /xgc ) {
			#warn _msg 'list not terminated at %s, looking for another element' if $DEBUG;
			push @list, _bdecode_chunk();
		}
		return \@list;
	}
	elsif ( m/ \G d /xgc ) {
		#warn _msg 'DICT' if $DEBUG;

		croak _msg 'nesting depth exceeded at %s'
		if defined $max_depth and $max_depth < 0;

		my $last_key;
		my %hash;
		until ( m/ \G e /xgc ) {
			#warn _msg 'dict not terminated at %s, looking for another pair' if $DEBUG;

			croak _msg 'unexpected end of data at %s'
			if m/ \G \z /xgc;

			my $key = _bdecode_string();
			defined $key or croak _msg 'dict key is not a string at %s';

			croak _msg 'duplicate dict key at %s'
			if exists $hash{ $key };

			croak _msg 'dict key not in sort order at %s'
			if not( $do_lenient_decode ) and defined $last_key and $key lt $last_key;

			croak _msg 'dict key is missing value at %s'
			if m/ \G e /xgc;

			$last_key = $key;
			$hash{ $key } = _bdecode_chunk();
		}
		return \%hash;
	}
	else {
		croak _msg m/ \G \z /xgc ? 'unexpected end of data at %s' : 'garbage at %s';
	}
}

sub bdecode {
	local $_ = shift;
	local $do_lenient_decode = shift;
	local $max_depth = shift;
	my $deserialised_data = _bdecode_chunk();
	croak _msg 'trailing garbage at %s' if $_ !~ m/ \G \z /xgc;
	return $deserialised_data;
}

 
my $fn = $ARGV[0];
 
if ($ARGV[0]) {
 
open my $file, "<", $fn; {
  local $/; $meta = <$file>;
} close $file;
 
$tor = bdecode($meta);
 
# remove all the mess
delete $tor->{info}->{pieces};
 
printf "  Created: %s \n\n", scalar(localtime($tor->{"creation date"}));
#$dt = DateTime->from_epoch(
#  epoch => $tor->{"creation date"}
#  printf "  Created: %s, %s \n\n",
#    $dt->ymd, $dt->hms;
#);
 
if ($tor->{modified-by}) {
  printf "  Modified: ",
    $tor->{modified-by};
} #modified
 
if ($tor->{comment}) {
  printf "  Comments: %s \n",
    $tor->{comment};
} #comments
 
printf "  Announce: %s \n\n  Torrent Contents: \n",
  $tor->{announce};
 
my @files = (@{ $tor->{info}->{files} }); my %seen = ();
foreach (grep { !$seen{ $_->{path}[0] }++ } @files) {
  printf "    %-40s \n", $_->{path}[0];
} printf "\n";
 
} else {
 
printf <<NFO;
 
 btView v0.1.1 {2012-06-09} by Tux
   usage: $0 dir/file.torrent
 
NFO
 
} #menu
 
## EOF: btview.pl
