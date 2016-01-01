#!/usr/bin/env perl

use strict;
use warnings;
use JSON;
use Data::Dumper;

use lib $ENV{CUSTOM_PERL_LIB};

use EvE::Evecrest;

sub load_file {
	my ($name) = @_;
	my ($f, $str);
	if (! defined($name)) {
		return -1;
	}
	$str = "";
	open($f, "< $name") or return $!;
	while (my $l = <$f>) { $str .= $l; }
	close($f);
	return $str;
}

sub load_json {
	my ($name) = @_;
	my $str = load_file("$name");
	my $var = from_json($str);
	return $var;
}

sub load_dump {
	my ($name) = @_;
	my $str = load_file($name);
	my $var = eval $str;
	return $var;
}

sub to_file {
	my ($name, $str) = @_;
	my $f;
	if (! defined($name) || ! defined($str)) {
		return -1;
	}
	open($f, "> $name") or return $!;
	print $f $str;
	close($f);
	return 1;
}

sub dump_json {
	my ($name, $var) = @_;
	if (to_file($name, to_json($var)) != 1) {
		return $!;
	}
	return 1;
}

sub dump_dump {
	my ($name, $var) = @_;
	if (to_file($name, Dumper($var)) != 1) {
		return $!;
	}
	return 1;
}

sub dump_it {
	my ($name,$var) = @_;
	if (! defined($name) || ! defined($var)) {
		return -1;
	}
	if (dump_dump($name, $var) != 1) {
		return $!;
	}
	if (dump_json($name, $var) != 1) {
		return $!;
	}
	return 1;
}

sub getNameId_fromArray {
	my ($arr) = @_;
	my @out;
	foreach my $var (@{ $arr }) {
		my $tmp = $var->{href};
		$tmp =~ s/\D*(\d+)\//$1/;
		my $t = { name => $var->{name}, id => $tmp };
		push(@out, $t);
	}
	return \@out;
}

sub getIdfromURI {
	my ($uri) = @_;
	$uri =~ s/\D*(\d+)\//$1/;
	return $uri;
}

sub getTypefromURI {
	my ($uri) = @_;
	$uri =~ s/\D\/(\D+)\/\d+\//$1/;
	return $uri;
}

sub getIdName_fromArray {
	my ($arr) = @_;
	my %out;
	foreach my $var (@{ $arr }) {
		my $tmp = getIdfromURI($var->{href});
		$out{$tmp} = $var->{'name'};
	}
	return \%out;
}

sub itemGroup_filter {
	my ($var, $filter, $filter_hash) = @_;
	my $filtered = { number => 0, children => 0, filter => $filter };
	for (my $i=0; $i <= $#{ $var->{'items'} }; $i++) {
		if ($var->{'items'}[$i]{'name'} =~ /$filter/) {
			my @items;
			my $arr = getIdName_fromArray($var->{'items'}[$i]{'child'}{'types'});
			foreach my $k (keys %{ $arr }) {
				my $tmp;
				if (defined($filter_hash)) {
					if (defined($filter_hash->{ $k })) {
						$tmp = { id => $k, name => $arr->{$k} };
					}
					else {
						next;
					}
				}
				else {
					$tmp = { id => $k, name => $arr->{$k} };
				}
				push(@items, $tmp);
			}
			if ($#items == -1) {
				next;
			}
			$filtered->{ getIdfromURI($var->{'items'}[$i]{'href'}) } = 
			{
				name => $var->{'items'}[$i]{'name'},
				items => \@items
			};
			$filtered->{'children'} += scalar(@items);
			$filtered->{'number'} += 1;
		}
	}
	return $filtered;
}

sub itemGroupTree {
	my ($name) = @_;
	my $p = EvE::Evecrest->new({ debug => 0 });
	my $tree = $p->load_child_multipage({ name=> "itemGroups" });
	my $num = $#{ $tree->{'items'} };
	for (my $i=0; $i <= $num; $i++) {
		my $one = $tree->{'items'}[$i];
		print "Loading $i / $num\n" if $p->{'debug'} >= 2;
		$one->{child} = $p->load_url($one->{href});
	}
	dump_it($name, $tree);
	return $tree;
}

sub getMarketPrices {
	my ($name) = @_;
	my $p = EvE::Evecrest->new({ debug => 0 });
	my $prices = $p->load_child_href({ name => "marketPrices" });
	dump_it($name, $prices);
	return $prices;
}

sub marketPriceFilter {
	my ($var, $filter) = @_;
	my $filtered = { number => 0, children => 0, filter => $filter };
	for (my $i=0; $i <= $#{ $var->{'items'} }; $i++) {
		if ($var->{'items'}[$i]{'type'}{'name'} =~ /$filter/) {
			$filtered->{ $var->{'items'}[$i]{'type'}{'id'} } = $var->{'items'}[$i]{'type'}{'name'};
			$filtered->{'number'} += 1;
		}
	}
	return $filtered;
}

my ($var, $target, $json);
if ($#ARGV == -1) {
	print "usage: eveitemGroupProcessor.pl [-f|--file ItemGroup_Data_File] [-t|--target target_Data_File] [-j|--json]\n";
	exit;
}
while ($ARGV[0] && $ARGV[0] ne "") {
	if ($ARGV[0] =~ /(--file|-f)/) {
		shift;
		if ($ARGV[0] && $ARGV[0] =~ /.*\.json$/) {
			$var = load_json($ARGV[0]);
		}
		else {
			$var = load_dump($ARGV[0]);
		}
	} elsif ($ARGV[0] =~ /(--target|-t)/) {
		shift;
		$target = $ARGV[0];
	} elsif ($ARGV[0] =~ /(--json|-j)/) {
		$json = 1;
	}
	shift;
}

if (defined($var) && ref($var) ne "HASH") {
	#print "Error on value '".Dumper($var)."'\n";
	#print "Grabbing itemGroup tree anew\n";
	$var = itemGroupTree(".itemGroupTree");
}
else {
	#print "Grabbing itemGroup tree\n";
	$var = itemGroupTree(".itemGroupTree");
}

#print "Grabbing marketPrices\n";
my $filteredmarket = marketPriceFilter(getMarketPrices(".marketPrices"), "Blueprint");

my $filtereditems = itemGroup_filter($var, "Blueprint", $filteredmarket);
if (defined($target)) {
	dump_it($target, $filtereditems);
}
else {
	if (defined($json)) {
		print to_json($filtereditems);
	}
	else {
		print Dumper($filtereditems);
	}
	print "\n";
}

exit 0;

