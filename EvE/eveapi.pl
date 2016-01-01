#!/usr/bin/env perl

use strict;
use warnings;

use lib $ENV{CUSTOM_PERL_LIB};

use EvE::Eveapi;
use JSON;
use Data::Dumper;
use DateTime::Format::Strptime;
use utf8;
binmode STDOUT, ":utf8";

#** @file eveapi.pl
# @brief simple api information requester
#
# API lib example, able to fetch Account Information.
#
# Arguments:
# 	- -h {show the help message}
# 	- -o {Request generall data}
# 	- -a {Request industry data}
# 	- --fromfile|-f {Request all data for a key in filename}
# 	- --id|-i {KeyID}
# 	- --vcode|-vc {vCode}
# 	- --characterid|-cid {characterID}
# 	- --verbose|-v {Toggle verbose mode}
#*

# formatting utf8 chars
my $t = "\x{2501}";
my $tr = "\x{2511}";
my $tm = "\x{252f}";
my $lm = "\x{251d}";
my $bl = "\x{2515}";
my $ll = "\x{2502}";

#holding vars
my ($id,$vcode,$charid,$mode,$v);
my $now = time();
my @activities = ("None", "Manufacturing", "Research Stuff",
	"Research TE", "Research ME", "Copy", "Duping",
	"Reverse Engineering", "Invention");


my %descs = ( -o => ["Request generall data", \&requestoverall],
				-a => ["Request industry data", \&getindustry],
				-f => ["Request all data for a saved key", \&fromfile],
				-h => ["Show the help message", \&printhelp], );

my @args = ();

while ($ARGV[0] && $ARGV[0] ne "") {
	if ($ARGV[0] =~ /^(--id|-i)$/) {
		shift;
		$id = $ARGV[0];
	}
	elsif ($ARGV[0] =~ /^(--vcode|-vc)$/) {
		shift;
		$vcode = $ARGV[0];
	}
	elsif ($ARGV[0] =~ /^(--characterid|-cid)$/) {
		shift;
		$charid = $ARGV[0];
	}
	elsif ($ARGV[0] =~ /^(--fromfile|-f)$/) {
		$mode = $ARGV[0];
		shift;
		push(@args,$ARGV[0]);
	}
	elsif (descscontains($ARGV[0])) {
		$mode = $ARGV[0];
	}
	elsif ($ARGV[0] =~ /^(--verbose|-v)$/) {
		print "Verbose mode enabled\n";
		$v = 1;
	}
	shift;
}

if (!$mode) {
	printhelp();
}

if ($#args == -1) {
	@args = undef;
}

my $api = EvE::Eveapi->new({ keyID => $id, vCode => $vcode, characterID => $charid, debug => $v });

$descs{$mode}[1]->(\@args);

sub descscontains {
	my ($i) = @_;
	foreach my $cur (keys %descs) {
		if ($cur =~ /$i/) {
			return 1;
		}
	}
	return 0;
}

sub printhelp {
	print "Usage is: $0 [mode] --id|-i keyID --vcode|-vc vCode [--characterid|-cid characterID]\n";
	print "Modes are:\n";
	foreach my $m (keys %descs) {
		print "\t$m\t".$descs{$m}->[0]."\n";
	}
	exit;
}

sub hourstodays {
	my ($h) = @_;
	my $d = 0;
	while ($h >= 24) {
		$d++;
		$h -= 24;
	}
	return ($d,$h);
}

sub secondstodays {
	my ($c) = @_;
	my @diff = (0,0,0,0);
	my @stat = (24 * 60 * 60, 60 * 60, 60);
	for (my $i=0; $i <= $#stat; $i++) {
		while ($c >= $stat[$i]) {
			$diff[$i] += 1;
			$c -= $stat[$i];
		}
	}
	$diff[-1] = $c;
	return \@diff;
}

sub sortbykey {
	my ($arr_ref, $key) = @_;
	my @arr = @{$arr_ref};
	my @tmp = ();
	my @sorted = ();
	foreach my $elem (@arr) {
		push(@tmp, $elem->{$key});
	}
	@tmp = sort(@tmp);
	for (my $i=0; $i <= $#arr; $i++) {
		my $elem = $arr[$i];
		for (my $j=0; $j <= $#tmp; $j++) {
			if ($elem->{$key} eq $tmp[$j]) {
				$sorted[$j] = $elem;
				last;
			}
		}
	}
	return \@sorted;
}

sub printit {
	my ($toprint,$args) = @_;
	if (defined($args)) { return; }
	if (ref($toprint) eq "ARRAY") {
		print $t x 3, $tm, $toprint->[0], "\n";
		for (my $i=1; $i <= $#{ $toprint }; $i++) {
			print " " x 3;
			print ($i == $#{ $toprint } ? $bl : $lm);
			if (ref($toprint->[$i]) eq "ARRAY") {
				my @arr = @{ $toprint->[$i] };
				print $t x 3, $tm, $arr[0], "\n";
				for (my $j=1; $j <= $#arr; $j++) {
					print " " x 3, $ll, " " x 3;
					print ($j == $#arr ? $bl : $lm);
					print $arr[$j], "\n";
				}
			}
			else {
				print $toprint->[$i], "\n";
			}
		}
	}
	elsif (! defined($toprint)) {
		print $t x 16, "\n";
	}
	else {
		print $toprint, "\n";
	}
}

sub timediff {
	my ($str) = @_;
	my $p = DateTime::Format::Strptime->new( pattern => "%F %T" );
	my $pt = $p->parse_datetime($str)->epoch - $now;
	if ($pt <= 0) {
		return "Finished";
	}
	my @diff = @{ secondstodays($pt) };
	my @txt = ("D","H","M","s");
	my @out = ();
	for (my $i=0; $i<= $#txt; $i++) {
		if ($diff[$i] != 0) {
			push(@out, $diff[$i].$txt[$i]);
		}
	}
	return join(" ", @out);
}

sub fromfile {
	my ($args) = @_;
	my ($f,$name);
	if ($#{$args} != -1) {
		$name = $args->[0];
	}
	open($f, "< $name") or die "Could not open $name\n";
	my $str = "";
	while (my $l = <$f>) {
		$str .= $l;
	}
	close($f);
	my $data = from_json($str);
	if (ref($data) eq "ARRAY") {
		my @jobs = ();
		my $counter = 0;
		my @accs = ();
		foreach my $elem (@{$data}) {
			#$api = Eveapi->new({ keyID => $elem->{keyID}, vCode => $elem->{vCode}});
			$api->loadFile([ $name, $counter ]);
			$counter++;
			my $account = requestoverall();
			foreach my $char (@{ $account->{chars} }) {
				$api->attr("characterID", $char->{characterID});
				@jobs = (@jobs, @{ getindustry(1) });
			}
		}
		@jobs = @{ sortbykey(\@jobs, "endDate") };
		printit();
		printit("Industry job summary:");
		my @out = ();
		for (my $i=0; $i <= $#jobs; $i++) {
			my $job = $jobs[$i];
			my $tmp = $activities[int($job->{activityID})]." ";
			$tmp .= $job->{blueprintTypeName}." ends: ".$job->{endDate};
			$tmp .= " (".timediff($job->{endDate}).")";
			$tmp .= " {".$job->{installerName}."}";
			push(@out, $tmp);
		}
		printit(\@out);
	}
	else {
		print "Could not handle data in $name\n";
		print "ref is ".ref($data)."\n";
		print Dumper($data), "\n";
	}
}


# requesting subs 

sub requestoverall {
	my ($p) = @_;

	if (! defined($api->{keyID}) || ! defined($api->{vCode})) {
		print "No id or vcode specified\n";
	}
	my $account = {};
	my @out = ();
	my $dom = $api->loadPath([ "account", "APIKeyInfo" ]);
	if ($dom) {
		if ($dom->{result}{key}{type}) {
			push(@out, "Key Type: ".$dom->{result}{key}{type});
		}
		my @chars;
		if (ref($dom->{result}{key}{rowset}{row}) eq "ARRAY") {
			@chars = @{ $dom->{result}{key}{rowset}{row} };
		}
		else {
			@chars = ( $dom->{result}{key}{rowset}{row} );
		}
		$account->{chars} = \@chars;
		push(@out, scalar(@chars)." Character(s) found:");
		my @innerout = ();
		for (my $i=0; $i <= $#chars; $i++) {
			my $char = $chars[$i];
			my $tmp = $char->{characterName}.": ".$char->{corporationName};
			if ($char->{allianceName}) {
				$tmp .= " [".$char->{allianceName}."]";
			}
			$tmp .= "\t{".$char->{characterID}."}";
			push(@innerout, $tmp);
		}
		push(@out,\@innerout);
		print "Dumping Data:\n", Dumper($dom), "\n" if $v;
	}
	else {
		print "Error on parsing data\n";
	}

	# get account info
	$dom = $api->loadPath([ "account", "AccountStatus" ]);
	if ($dom) {
		if ($dom->{result}{paidUntil}) {
			push(@out, "Paid until: ".timediff($dom->{result}{paidUntil}));
		}
		push(@out, "Created: ".$dom->{result}{createDate});
		my $tmp = "Logon count: ".$dom->{result}{logonCount};
		$tmp .= " Time: ".int($dom->{result}{logonMinutes}/60);
		$tmp .= "H ".($dom->{result}{logonMinutes}%60)."M";
		push(@out, $tmp);
		$account->{dom} = $dom;
		print "Dumping Data:\n", Dumper($dom), "\n" if $v;
	}
	else {
		print "Error on parsing data\n";
	}
	printit(\@out, $p);
	return $account;
}

sub getindustry {
	my ($p) = @_;
	if (! defined($api->{characterID})) {
		print "No characterID specified\n";
		return undef;
	}

	my @jobs = ();
	my @out = ();
	my $dom = $api->loadPath([ "char", "IndustryJobs" ]);
	if ($dom) {
		if ($dom->{result}{rowset}{row}) {
			if (ref($dom->{result}{rowset}{row}) eq "ARRAY") {
				@jobs = @{ $dom->{result}{rowset}{row} };
			}
			else {
				@jobs = ( $dom->{result}{rowset}{row} );
			}
			@jobs = @{ sortbykey(\@jobs, "endDate") };
			printit("Industry jobs:", $p);
			my @out = ();
			for (my $i=0; $i<=$#jobs; $i++) {
				my $job = $jobs[$i];
				my $tmp = $activities[int($job->{activityID})]." ";
				$tmp .= $job->{blueprintTypeName}." ends: ".$job->{endDate};
				push(@out, $tmp);
			}
			printit(\@out, $p);
			print "Dumping Data:\n", Dumper($dom), "\n" if $v;
		}
		else {
			printit("No jobs found", $p);
		}
	}
	else {
		print "Error on parsing data\n";
	}
	return \@jobs;
}


