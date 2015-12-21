#!/usr/bin/perl -ws
# Created by Ben Okopnik on Thu Jun 28 09:11:52 EDT 2007
#
# Copyright (C) 2007 Ben Okopnik <ben@okopnik.com>
# Copyright (C) 2007 Ben Okopnik <ben@okopnik.com>
# Copyright (C) 2015 Jesse Monroy <jesse650@gmail.com>
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.

=pod
################################## Changelog ##############################
02/03/15 02-56 v4.4
# Contributor Jesse Monroy added a new regex to handle all-new date 
# format now being issued for .org and .info domains.

09/20/09 19:47 v4.3
* Added a new regex based on daum.net; modified existing regex for cdn1.net
(Sukbum Hong is working hard to earn that "Gold Star" contributor status! :)

06/20/09 13:10 v4.2
* Added a 'retries_max' feature for unreliable domains (thanks again to
Sukbum Hong for the suggestion). This has resulted in my list of
"problem domains" becoming significantly smaller. Also added '-w' to force
"whois" instead of "jwhois"; some domains (e.g., the entire ".jobs" kit)
require this.

06/18/09 21:59 v4.1
* Added .co.jp - very odd format for expirations. Thanks, Sukbum Hong!

12/30/08 12:33 v4.0
* Hostfile parsing is now a bit more robust (tolerant of comments and blanks
in the host list file.) Thanks to Eric S. Raymond for the pointer!

11/09/08 09:55 v3.9
* North Koreans (silently) switched their WHOIS and now use an invalid year
(9999.) This crashes 'timegm()' - so I've added a "ridiculous year" detector.

10/22/08 09:33 v3.8
* Added several Korean formats - 'gabia.com', 'yesnic.com', 'cfolder.net'.
Thanks, Sukbum Hong!

08/27/08 19:55 v3.7
* Tweaked for the PairNIC date format. Thanks to Janek Hellqvist for the
heads-up!

07/27/08 22:33 v3.6
* Added a .ca "special": 'Renewal date:'

11/05/07 21:01 v3.5
* Tweaked to resolve .cz ("expire:" along with "expires:")

09/25/07 12:27 v3.4
* Tweaked regexes to include the ".name" date syntax.

08/15/07  1:06 v3.3
* Added a bit more CLI error checking (trips off on '-d foo.com', etc.)

08/14/07 23:03 v3.2
* Polished the regexen based on Rick Moen's list of 270 TLDs
* Wrapped the date-calc section in an eval for cases where the date is past
	the Unix "death boundary" (18-Jan-2038)

08/08/07 23:26 v3.1
* Added another regex to parse the weird structure of 'extragalactic.net';
	modified another regex slightly to accomodate 'expire date' for 'nic.it'.

07/29/07  1:26 v3.0
* MAJOR REVISION:
	o The format of the 'domain-list' file has been changed, although the
	  old format is still valid. You can now add the name of the host for
	  'whois' to use as the second argument on the line; however, using the
	  '-s' command line argument will force all lookups to be done via the
	  specified host.
	o Fixed up a number of regexen for the 'jwhois' differences

07/28/07  0:41 - v2.2
* Added 'jwhois' as the preferred option, with a warning if it's not
	installed. Caching for 'jwhois' is disabled when '-X' is in effect;
	'-H' is no longer a hard-wired argument to 'whois' ('jwhois' doesn't
	support it), but is still appended if 'whois' is used.
* Tweaked a couple of the regexen to process new TLDs (.fi, .ly, etc.)
* Giving serious thought to modifying the format of the -F files; it would
	be nice to be able to specify the whois server for individual domains.

07/20/07  9:36 - v2.1
* Added a bunch of tracing/debugging statements to the date parser, making
	the '-X' option much more useful
* Built a 'switch-case' structure around the parser so that only one regex
	would apply to any given host
* Added a '-H' argument to 'whois' ("elide legal disclaimer") to make
	debugging output less annoying (and maybe speed things up fractionally)
* Made the 'no expiration date found' error into a non-fatal warning (used
	to break list processing)
* Modified the output format slightly (warnings now appear on the same line
	as the domain name)
* Domains without a registrar will no longer be omitted from the mailed
	notifications

07/19/07 22:28 - v2.0
* Now parsing .ci domains as well (millions of people cheer, world peace
	can't be far away now...)

07/19/07 20:54 - v1.9
* Added a little regex-fu to accept lines that have whitespace at the end
* Added a Big Sekrit Option ('-X' - shhh, don't tell anybody!) for debugging

07/19/07 11:56 - v1.8
* Lots and lots of fixes for many different TLDs; much mangling of regexen.
	Now handles many more expiration date types than before. Most
	importantly, domains that don't list a registrar will now be displayed
	anyway; people probably know where to send their money, but not
	necessarily _when._

07/04/07 12:28 - v1.7
* Scrapped previous approach to the .org delay; the .orgs are now sorted to
	the end of the domain list and all except the first one wait 20 seconds.
* Added a cute little time ticker to the delay routine, just because. :)

07/03/07  1:27 - v1.6
* Added a rate limiter (3/minute) for .org domains

06/30/07 18:34 - v1.5
* Added a "domain not parseable; please report" warning
* Added an "Unable to read 'whois' info" warning for the 'fgets: connection
	reset by peer' error.
* All expiration warnings are now sent as one email instead of one per
	domain; ditto the expired domains notifications.
* The 'printf' for the 'SKIPPED' error was ignoring the '-q' option; fixed

06/30/07  8:19 - v1.4
* Removed dependency on File::Find; searching PATH 'manually'
* Added an 'exit 1' to the silent failure mode of 'croak'

06/30/07  7:06 - v1.3
* Improved the date-parsing regexes (the numerical months part can now only
	match '01-12' instead of 'any two digits'); this should increase the
	reliability of resolving 'dd-mm-yyyy' vs. 'mm-dd-yyyy' somewhat.
* More accurate reporting for the 'SKIPPED' error (now shows exact reason)
* Fixed the regexes that I screwed up while adding the Dotster extension
* Added a '-v' option

06/29/07 18:54 - v1.2
* Got rid of an unnecessary system dependency ('which') - 'File::Find' is a
	bit clunky, but better than depending on unknowns...
* Another date-processing regex (ISOC-IL: 'validity: 29-06-2007')

06/29/07 17:07 - v1.1
* Modified output format to include both exp. date and days remaining
* Added another date-processing regex (DOTSTER: 'Expires on: 29-Jun-07')

06/29/07 15:06 - v1.0
I'm finally willing to admit that this script is usable. :) Recent changes
include:

* Parsing routine for "2007/08/12" date format
* 'croak' notifies admin of problems encountered in silent mode
* Added a fallback email address for 'croak'
* Fixed GMT parsing routine miscalc (thanks to Rick Moen for the heads up)

For Nosy Nellies only: *Yes*, I'm aware of the various '*Whois.pm' modules
on CPAN. None of them do what I want; the one that comes closest
(Net::XWhois) hasn't been maintained since 2001 and only covers a smallish
subset of what I want. No, I'm not interested in taking it over and
maintaining it; I've got enough to do as it is.
 
###########################################################################
=cut

use strict;
use Time::Local;
$|++;

# Command-line variables
our ($d, $e, $F, $h, $q, $r, $s, $v, $w, $x, $X);

### FALLBACK ADDRESS FOR NOTIFICATION ############
my $address = 'root@localhost';
##################################################

my ($name) = $0 =~ /([^\/]+)$/;

my $usage =<<"+EoT+";
Usage: $name [-e=email] [-x=expir_days] [-q] [-h] <-d=domain_name|-F=domainfile>

  -d=domain        : Domain to analyze
  -e=email_address : Send a warning message by email
  -F=domain_list   : File with a list of domains, one per line
  -h               : Print this message
  -q               : Don't print to the console (REQUIRES '-e' OPTION)
  -r=max_retries   : Change the maximum number of retries (default: 3)
  -s=whois server  : Use alternate whois server
  -v               : Display current version of this script
  -x=days          : Change default (30d) expiration interval (REQUIRES '-e' OPTION)
  -w               : Use 'whois' in preference to 'jwhois' (some domains need this)

+EoT+

my $retries = 0;
my $max_retries = $r || 3;

# Locate 'whois' or (preferred) 'jwhois'
my ($whois) = grep -e, map "$_/jwhois", split /:/, $ENV{PATH};
($whois) = grep -e, map "$_/whois", split /:/, $ENV{PATH} unless $whois;
die "'whois'|'jwhois' not found in path.\n" unless $whois;
if ($whois =~ m#/whois$#){
	# $q || print "You really should install 'jwhois'; it gives better results.\n";
	# Turn down the noise (minimal output option - only works with 'whois')
	$whois .= " -H";
}
else {
	# Turn off caching for 'jwhois' if the debug option is on
	$whois .= " -f" if $X;
}

# Force 'whois' if requested
$whois = "/usr/bin/whois" if $w;

# Find a mail client (mutt or mailx)
my ($mail) = grep -e, map "$_/mutt", split /:/, $ENV{PATH};
# Switch Mutt into 'mailx' mode if found
if ($mail){
	$mail .= " -x";
}
else {
	($mail) = grep -e, map "$_/mailx", split /:/, $ENV{PATH};
}
die "No 'mailx' or 'mutt' (mail client) found in path.\n" unless $mail;

# Read the version number at the top of the changelog
if ($v){
	seek DATA, 0, 0;
	while (<DATA>){
		if (m[^\d+/\d+/\d+[^v]+v([0-9.]+)]){
			print "Version: $1\nCopyright (C) 2007 Ben Okopnik <ben\@okopnik.com>\n\n";
			exit 0;
		}
	}
}

# Email admin if '-q' is on; otherwise, just exit with the error
sub croak {
	if ($q){
		# If '-e' wasn't specified, use the fallback address
		$e ||= $address;

		# No place to send an error if this fails... :)
		open Mail, "|$mail -s 'WARNING: $name script error' $e";
		print Mail "$name [" . localtime() . "]: ", $_[0];
		close Mail;

		exit 1;
	}
	else {
		die $_[0];
	}
}

# Display the help output if requested or in case of incorrect usage
die "$usage\n" if $h;
die "\n*ERROR: '$name' requires an email address with the '-q' and the '-x' options*\n\n$usage" if ($q || $x) && ! $e;
die "\n*ERROR: '$name' requires either a domain name or a domain list as an argument*\n\n$usage" if ! $d && ! $F;
die "\n*ERROR: Please make sure you're using correct syntax (i.e., '-d=domain_name')*\n\n$usage" if (defined $d && $d =~ /^1$/) || (defined $F && $F =~ /^1$/) || (defined $s && $s =~ /^1$/) || (defined $r && $r !~ /^\d+$/);

# Set default notification interval to 30 days
if ($x){
	croak "Expiration interval must be specified in days (0-9999).\n"
		unless $x =~ /^\d{1,4}$/;
}
else {
	$x = 30;
}

# Read the domain list file
my @domains;
if ($F){
	croak "$F is not a regular file\n" unless -f $F;
	croak "Can't read $F\n" unless -r _;
	# Open the file if it exists
	open F or croak "$F: $!\n";
	while (<F>){
		# Skip blank lines; ignore comments
		next if /^\s*(?:#|$)/;
		# Strip preceding and following blanks
		s/^\s*(.*?)\s*$/$1/;

		# Separate domain and server if they exist
		my (@line) = split;
		for (@line){
			# Strip URI method and any terminal '/'s
			s#^.*://##;
			s#/$##;
		}
		push @domains, [ @line ];
	}
	close F;
}

# Having a '-F' AND a '-d' is explicitly not excluded
if ($d){
	# Strip URI method and any terminal '/'s
	$d =~ s#^.*://##;
	$d =~ s#/$##;
	push @domains, [ $d ];
}

# Set the server if specified (this REPLACES any servers defined
# in the domain-list file)
if ($s){
	$_ -> [1] = $s for @domains;
}

# Sort list to push .orgs to the end; ASCIIbetical sort otherwise
@domains = sort { ($a->[0] =~ /\.org$/i) <=> ($b->[0] =~ /\.org$/i) || $a->[0] cmp $b->[0] } @domains;

# Trim strings to specified length; return '**UNKNOWN**' if undef
sub trim {
	defined $_[0] || return "**UNKNOWN**";
	substr($_[0], 0, $_[1]);
}

# Lookup list for month number->name conversion
my (%mth,%mlookup);
@mth{map sprintf("%02d", $_), 1..12} = qw/jan feb mar apr may jun jul aug sep oct nov dec/;
# Lookup list for month name->abbrev conversion
@mlookup{qw/january february march april may june july august september october november december/} =
	(qw/jan feb mar apr may jun jul aug sep oct nov dec/) x 2;

########################## DATA COLLECTION SECTION #############################

# Process the domain list
my ($seen, %list);
TOP: for my $line (@domains){
	next TOP if $line =~ /^\s*(?:#|$)/;

	my ($host, $server) = @{$line};

	my $opt = $server ? "-h $server" : "";

	$q || print "\b\nProcessing $host... ";

	# Delay to avoid triggering rate limiter
	if ($host =~ /\.org$/i){
		$q || print "(NOTE: Subsequent ORG queries will be delayed by 20 seconds each due to rate limiting) "
			unless $seen;
		# Show the cute little time ticker :)
		if ($seen++){
			my @chars = split //, '|/-\\';
			for (0 .. 19){
				$q || print $chars[$_ % 4], "\b";
				sleep 1;
			}
			print " \b";
		}
	}

	my $out;
	while (1){	# Start the 'retry' block

		# Execute the query, save as a single string
		open Who, "$whois $opt $host|" or croak "Error executing $whois: $!\n";
		$out = do { local $/; <Who> };
		close Who;

		if (!$out || $out !~ /domain/i){
			# Whoops, the lookup failed! If we're using "jwhois", ignore the cache -
			# no point to repeated lookups otherwise.
			if ($whois =~ m#/jwhois$#){
			    $whois .= " -f";
			}

			# Skip the retries if we're troubleshooting, or if we've exceeded MAX.
			if (($retries <= $max_retries) && !$X){
				$retries++;
				$q || print "Lookup failed; retrying ($retries of $max_retries max retries)\n";
				next;
			}
			else {
				$q || print "Unable to read 'whois' info for $host. Skipping... ";
				next TOP;
			}
		}
		else {
			$retries = 0;
			last;
		}
	} # End of retry block

	# Freak out and run away if there's no match
	if ($out =~ /no match/i){
		$q || print "No match for $host!\n";
		next;
	}
	# Ditto for bad hostnames
	if ($out =~ /No whois server is known for this kind of object/i){
		$q || print "'whois' doesn't recognize this kind of object. ";
		next;
	}

	# Get rid of the DOS formatting
	$out =~ tr/\cM//d;

	# Convert multi-line 'labeled block' output to 'Label: value'
	my $debug;
	if ($out =~ /registrar:\n/i){
		$out =~ s/:\n(?!\n)/: /gsm;
		$debug .= "matched on line " . (__LINE__ - 1) . ": Multi-line 'labeled block'\n";
	}

	# Date processing; this is the heart of the program. Desired date format is '29-jun-2007'
	# 'Fri Jun 29 15:16:00 EDT 2007'
	if ($out =~ s/(date:\s*| on:\s*)[A-Z][a-z]+\s+([a-zA-Z]{3})\s+(\d+).*?(\d+)\s*$/$1$3-$2-$4/igsm){
		$debug .= "matched on line " . (__LINE__ - 1) . ": 'Fri Jun 29 15:16:00 EDT 2007'\n";
	}
	# '29-Jun-07'
	elsif ($out =~ s/(date:\s*| on:\s*)(\d{2})[\/ -](...)[\/ -](\d{2})\s*$/$1$2-$3-20$4/igsm){
		$debug .= "matched on line " . (__LINE__ - 1) . ": '29-Jun-07'\n";
	}
	# '2007-Jun-29'
	elsif ($out =~ s/[^\n]*(?:date| on|expires on\.+):\s*(\d{4})[\/-](...)[\/-](\d{2})\.?\s*$/Expiration date: $3-$2-$1/igsm){
		$debug .= "matched on line " . (__LINE__ - 1) . ": '2007-Jun-29'\n";
	}
	# '2007/06/29'
	elsif ($out =~ s/(?:valid |renewal-|expir(?:e|es|y|ation)\s*)(?:date|on)?[ \t.:]*\s*(\d{4})(?:[\/-]|\. )(0[1-9]|1[0-2])(?:[\/-]|\. )(\d{2})(?:\.?\s*[0-9:.]*\s*\w*\s*|\s+\([-A-Z]+\)?)$/Expiration date: $3-$mth{$2}-$1/igsm){
		$debug .= "matched on line " . (__LINE__ - 1) . ": '2007/06/29'\n";
	}
	# '[State]                         Connected (2009/11/30)' - .co.jp
	elsif ($out =~ s/\[State\]\s+Connected\s+\((\d{4})(?:[\/-]|\. )(0[1-9]|1[0-2])(?:[\/-]|\. )(\d{2})\)\s*$/Expiration date: $3-$mth{$2}-$1/igsm){
		$debug .= "matched on line " . (__LINE__ - 1) . ": [State]     Connected (2009/11/30)\n";
	}
	# '29-06-2007'
	elsif ($out =~ s/(?:validity:|expir(?:y|ation) date:|expire:|expires? (?:on:?|on \([dmy\/]+\):|at:))\s*(\d{2})[\/.-](0[1-9]|1[0-2])[\/.-](\d{4})\s*[0-9:.]*\s*\w*\s*$/Expiration date: $1-$mth{$2}-$3/igsm){
		$debug .= "matched on line " . (__LINE__ - 1) . ": '29-06-2007'\n";
	}
	# '[Expires on]     2007-06-29' (.jp, .ru, .ca); 'Valid Date     2016-11-02 04:21:35 EST' (yesnic.com); 'Domain Expiration Date......: 2009-01-15 GMT.' (cfolder.net)
	elsif ($out =~ s/(?:valid[- ]date|(?:renewal|expiration) date(?::|\.+:)|paid-till:|\[expires on\]|expires on ?:|expired:)\s*(\d{4})[\/.-](0[1-9]|1[0-2])[\/.-](\d{2})(?:\s*[0-9:.]*\s*\w*\s*|T[0-9:]+Z| GMT\.)$/Expiration date: $3-$mth{$2}-$1/igsm){
		$debug .= "matched on line " . (__LINE__ - 1) . ": '[Expires on]     2007-06-29' (.jp, .ru)\n";
	}
	# 'expires:     June  29[, ]+2007' (.is, PairNIC); 'Record expires on       JULY      21, 2016' (gabia.com)
	elsif ($out =~ s/(?:expires:|expires on)\s*([A-Z][a-z]+)\s+(\d{1,2})(?:\s|,)+(\d{4})\s*$/"Expiration date: " . sprintf("%02d", $2) . "-" . $mlookup{"\L$1\E"} . "-$3"/igsme){
		$debug .= "matched on line " . (__LINE__ - 1) . ": 'expires:     June  29 2007' (.is)\n";
	}
	# 'renewal: 29-June-2007'
	elsif ($out =~ s/renewal:\s*(\d{1,2})[\/ -]([A-Z][a-z]+)[\/ -](\d{4})\s*$/"Expiration date: $1-" . $mlookup{"\L$2\E"} . "-$3"/igsme){
		$debug .= "matched on line " . (__LINE__ - 1) . ": 'renewal: 29-June-2007' (.ie)\n";
	}
	# 'Record expires on........: 06-Mar-2013 EDT.' (daum.net)
	elsif ($out =~ s/record expires on\.+:\s*(\d{1,2})[\/ -]([A-Z][a-z][a-z])[\/ -](\d{4})\s*[A-Z]+\.$/"Expiration date: $1-\l$2-$3"/igsme){
		$debug .= "matched on line " . (__LINE__ - 1) . ": 'Record expires on........: 06-Mar-2013 EDT.' (daum.net)\n";
	}
	# 'expire:         20080315' (.cz, .ke)
	elsif ($out =~ s/expir[ey]:\s*(\d{4})(\d{2})(\d{2})\s*$/Expiration date: $3-$mth{$2}-$1/igsm){
		$debug .= "matched on line " . (__LINE__ - 1) . ": 'expire:         20080315' (.cz, .ke)\n";
	}
	# 'domain_datebilleduntil: 2007-06-29T00:00:00+12:00' (.nz)
	elsif ($out =~ s/domain_datebilleduntil:\s*(\d{4})[-\/](\d{2})[-\/](\d{2})T[0-9:.+-]+\s*$/Expiration date: $3-$mth{$2}-$1/igsm){
		$debug .= "matched on line " . (__LINE__ - 1) . ": 'domain_datebilleduntil: 2007-06-29T00:00:00+12:00' (.nz)\n";
	}
	# '29 Jun 2007 11:58:42 UTC' (.coop)
	elsif ($out =~ s/(?:expir(?:ation|y) date|expire[sd](?: on)?)[:\] ]\s*(\d{2})[\/ -](...)[\/ -](\d{4})\s*[0-9:.]*\s*\w*\s*$/Expiration date: $1-\L$2\E-$3/igsm){
		$debug .= "matched on line " . (__LINE__ - 1) . ": '29 Jun 2007 11:58:42 UTC' (.coop)\n";
	}
	# 'Record expires on 17/8/2100' (.hm, fi)
	elsif ($out =~ s/(?:expires(?: on|:))\s*(\d{2})[\/.-]([1-9]|0[1-9]|1[0-2])[\/.-](\d{4})\s*[0-9:.]*\s*\w*\s*$/"Expiration date: $1-".$mth{sprintf "%02d", $2} . "-$3"/iegsm){
		$debug .= "matched on line " . (__LINE__ - 1) . ": 'Record expires on 17/8/2100' (.hm)\n";
	}
	# 'Expires on..............: Sat, Mar 29, 2008'
	elsif ($out =~ s/expires on\.*:\s*(?:[SMTWF][uoehra][neduit]),\s+([A-Z][a-z]+)\s+(\d{1,2}),\s+(\d{4})\s*$/"Expiration date: " . sprintf("%02d", $2) . "-\L$1-$3"/iegsm){
		$debug .= "matched on line " . (__LINE__ - 1) . ": 'Expires on..............: Sat, Mar 29, 2008'\n";
	}
	# 'Registry Expiry Date: 2016-08-06T04:00:00Z' (.org)
        elsif ($out =~ s/Registry Expiry Date: ([0-9]{4})-([0-9]{2})-([0-9]{2})T/Expiration date: $3-$mth{$2}-$1/igsm){
                #print "\nFOUND DATE: $1 $2 $3\n";
	        $debug .= "matched on line " . (__LINE__ - 1) . ": '(.org)\n";
        }
	else {
		$debug = "No regexes matched.\n";
	}

	# Collect the data from each query
	for (split /\n/, $out){
		# Clip pre- and post- blanks
		s/^\s*(.*?)\s*$/$1/;
		# Squash repeated tabs and spaces
		tr/ \t//s;

		# This is where it all happens - regexes to capture registrar and expiration
		$list{$host}{Registrar} ||= $1 if /(?:maintained by|registration [^:]*by|authorized agency|registrar)(?:\s*|_)(?:name|id|of record)?:\s*(.*)$/i;
		$list{$host}{Expires} ||= $1 if /(?:expires(?: on)?|expir(?:e|y|ation) date\s*|renewal(?:[- ]date)?)[:\] ]\s*(\d{2}-[a-z]{3}-\d{4})/i;
	}

	# Assign default message if no registrar was found
	$list{$host}{Registrar} ||= "[[[ No registrar found ]]]";
	
	$q || print "No expiration date found in 'whois' output. Please report this domain to the author!"
		unless defined $list{$host}{Expires};

	# Debug option (activated by '-X'); exits here with parsed 'whois' output
	$debug .= "Registrar: $list{$host}{Registrar}\n" if defined $list{$host}{Registrar};
	$debug .= "Expires: $list{$host}{Expires}\n" if defined $list{$host}{Expires};
	die "\n", "=" x 70, "\n$out\n", "=" x 70, "\n$debug", "=" x 70, "\n" if $X;
}

$q || print "\n";

########################## DATA ANALYSIS SECTION #############################

# Get current time snapshot in UTC
my $now = timegm(gmtime);

# Convert dates to UTC epoch seconds; *will* fail on 19 Jan 2038. :)
my %months;
@months{qw/jan feb mar apr may jun jul aug sep oct nov dec/} = 0..11;

# Print the header if '$q' is off and there's content in %list
$q || %list && printf "\n\n%-24s%-36s%s\n%s\n", "Host", "Registrar", "Exp.date/Days left", "=" x 78;

# Process the collected data
my (%exp, %end);
for my $k (sort keys %list){
	unless (defined $list{$k}{Expires}){
		$q || printf "%-32s%s\n", trim($k, 31), "*** SKIPPED (missing exp. date) ***";
		delete $list{$k};
		next;
	}
	my @chunks = split /-/, $list{$k}{Expires};
	my $epoch;

	# The "date is ridiculously far in the future" interceptor
	if ($chunks[2] > 2038){
		$q || print "**** NOTE: Year out of range - date will NOT be calculated correctly! ****\n";
		# Set epoch to EPOCH_MAX
		$epoch = 2147212800;
	}
	else {
		eval { $epoch = timegm(0, 0, 0, $chunks[0], $months{lc $chunks[1]}, $chunks[2] - 1900) };
		if ($@){
			$q || print "$@\n";
			if ($@ =~ /too big/){
				$q || print "**** NOTE: Date past 19-Jan-2038 - date will NOT be calculated correctly! ****\n";
			}
			# Set epoch to EPOCH_MAX
			$epoch = 2147212800;
		}
	}
	my $diff = int(($epoch - $now) / 86400);
	$q || printf "%-24s%-36s%-12s/%5s\n", trim($k, 23), trim($list{$k}{Registrar}, 35),
		$list{$k}{Expires}, $diff;

	# Prepare alerts if domain is expired or the expiration date is <= $x days
	if ($e && ($diff <= $x)){
		if ($diff <= 0){
			$exp{$k} = -$diff;
		}
		else {
			$end{$k} = $diff;
		}
	}
}

# Report expired domains
if (%exp){
	open Mail, "|$mail -s '$name: Expired domains' $e" or croak "$mail: $!\n";
	print Mail "According to 'whois', the following domains have expired:\n\n";
	for my $x (sort { $exp{$a} <=> $exp{$b} } keys %exp){
		my $s = $exp{$x} == 1 ? "" : "s";
		print Mail "$x ($exp{$x} day$s ago)\n";
	}
	close Mail;
}

# Report domains that will expire within the '-x' period
if (%end){
	open Mail, "|$mail -s '$name: Domain expiration warning ($x day cutoff)' $e" or croak "$mail: $!\n";
	print Mail "According to 'whois', these domains will expire soon:\n\n";
	for my $d (sort { $end{$a} <=> $end{$b} } keys %end){
		my $s = $end{$d} == 1 ? "" : "s";
		print Mail "$d (in $end{$d} day$s)\n";
	}
	close Mail;
}

__END__

