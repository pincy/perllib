#!/usr/bin/env perl

use strict;
use warnings;

use JSON;
use Data::Dumper;

use lib $ENV{CUSTOM_PERL_LIB};

use EvE::Eveapi;

my $file = "";
my $apifile = undef;
my ($cid,@groups);


sub loadFile {
	my ($name) = @_;
	if (! defined($name)) { return undef; }
	my $file;
	my $str = "";
	open($file, "< $name") or return { error => "Could not open $name, $!" };
	while (my $l = <$file>) { $str .= $l; }
	close($file);
	return from_json($str);
}

sub loadItems {
	my ($data) = @_;
	my @items;
	foreach my $group (sort keys %{ $data }) {
		if (ref($data->{$group}) ne "HASH") {
			next;
		}
		foreach my $single (@{ $data->{$group}{items} }) {
			push(@items, $single->{id});
		}
	}
	@items = sort {$a <=> $b} @items;
	#print "Loaded typeIDs: ".join(", ", @items)."\n";
	return \@items;
}

sub checkForInArray {
	my ($check, $arr) = @_;
	foreach my $single (@{ $arr } ) {
		if ($single =~ /^$check$/) {
			return $single;
		}
#elsif (int($single) > int($check)) {
#			last;
#		}
	}
	return -1;
}

sub getGroupKey {
	my ($data,$key) = @_;
	foreach my $group (keys %{ $data }) {
		if (ref($data->{$group}) ne "HASH") {
			next;
		}
		foreach my $single (@{ $data->{$group}{items} }) {
			if ($single->{id} eq $key) {
				return $group;
			}
		}
	}
	return -1;
}

sub getName {
	my ($data,$group,$id) = @_;
	foreach my $single (@{ $data->{$group}{items} }) {
		if ($single->{id} eq $id) {
			return $single->{name};
		}
	}
	return "";
}

sub printAllGroups {
	my ($data) = @_;
	if (! defined($data)) {
		print "Could not print data\n";
	}
	foreach my $key (sort keys %{ $data }) {
		if (ref($data->{$key}) ne "HASH") {
			next;
		}
		print $key.": ".$data->{$key}{'name'}."\n";
	}
}

sub printAllForGroups {
	my ($data,$arr) = @_;
	if (! defined($data) || ! defined($arr)) { return undef; }
	foreach my $elem (@{ $arr }) {
		if (defined($data->{$elem}) && ref($data->{$elem}) eq "HASH") {
			print $elem.": ".$data->{$elem}{'name'}."\n";
			foreach my $single (@{ $data->{$elem}{'items'} }) {
				print "\t".$single->{'id'}.": ".$single->{'name'}."\n";
			}
		}
		else {
			print "Group $elem not found!\n";
		}
	}
}

sub getAPIData {
	my ($key) = @_;
	my $api = EvE::Eveapi->new($key);
	my $accountdata = $api->loadPath([ "account", "APIKeyInfo" ]);
	my $res = $accountdata->{result}{key}{rowset}{row};
	my @cids = (ref($res) eq "ARRAY" ? @{ $res } : ( $res ) );
	my $data;
	foreach my $cid (@cids) {
		$api->attr("characterID", $cid->{characterID});
		my $tmp = $api->loadPath(["char", "AssetList"]);
		$data = mergeAssetAPIData($data,$tmp);
		my $industry = $api->loadPath([ "char", "IndustryJobs" ]);
		my $indres = $industry->{result}{rowset}{row};
		my @jobs = (ref($indres) eq "ARRAY" ? @{ $indres } : ( $indres ) );
		my @bpos;
		foreach my $job (@jobs) {
			if (! defined($job)) {
				next;
			}
			if (int($job->{activityID}) >= 2 && int($job->{activityID}) <= 5) {
				push(@bpos, $job->{blueprintTypeID});
			}
			else {
				# non original action
			}
		}
		if (! defined($data->{industry})) {
			$data->{industry} = [];
		}
		$data->{industry} = [ @{ $data->{industry} }, @bpos ];
	}
	return $data;
}

sub mergeAssetAPIData {
	my ($a1, $a2) = @_;
	if (defined($a1->{result}{rowset}{row})) {
		foreach my $item (@{ $a2->{result}{rowset}{row} }) {
			push(@{ $a1->{result}{rowset}{row} }, $item);
		}
	}
	else {
		return $a2;
	}
	return $a1;
}

sub getOwned {
	my ($data,$api) = @_;
	if (! defined($data) || ! defined($api)) { return undef; }
	my $owned = {};
	my $items = loadItems($data);
	my @bpos;
	if (ref($api) ne "ARRAY") {
		$api = [ $api ];
	}
	foreach my $single (@{ $api }) {
		@bpos = ( @bpos, @{ $single->{industry} } );
		foreach my $location (@{ $single->{result}{rowset}{row} }) {
			if (! defined($location->{rowset})) {
				#print "- Item $location->{typeID}\n";
				if (checkForInArray($location->{typeID}, $items) != -1) {
					#print "\tBPO $location->{typeID} found\n";
					push(@bpos, $location->{typeID});
				}
			}
			else {
				my @itemsarr;
				if (ref($location->{rowset}{row}) eq "ARRAY") {
					@itemsarr = @{ $location->{rowset}{row} };
				}
				else {
					@itemsarr = ( $location->{rowset}{row} );
				}
				foreach my $item (@itemsarr) {
					#print "  Item $item->{typeID}\n";
					if (defined($item->{rawQuantity}) && $item->{rawQuantity} == -1
							&& checkForInArray($item->{typeID}, $items) != -1) {
						#print "\tBPO $item->{typeID} found\n";
						push(@bpos, $item->{typeID});
					}
				}
			}
		}
	}
	@bpos = sort {$a <=> $b} @bpos;
	foreach my $bpo (@bpos) {
		my $group = getGroupKey($data, $bpo);
		if (defined($owned->{$group})) {
			$owned->{$group}{$bpo} = 1;
		}
		else {
			$owned->{$group} = {$bpo => 1};
		}
	}
	return $owned;
}

sub getMissingInGroup {
	my ($data,$owned,$groups) = @_;
	my $missing = {};
	if ($#groups == -1) {
		# populate groups from owned
		foreach my $group (keys %{ $owned }) {
			push(@{ $groups }, $group);
		}
	}
	foreach my $group (@{ $groups }) {
		$missing->{$group} = {};
		foreach my $item (@{ $data->{$group}{items} }) {
			if (defined($owned->{$group}{$item->{id}})) {
				next;
			}
			else {
				$missing->{$group}{$item->{id}} = getName($data,$group,$item->{id});
			}
		}
		if (scalar keys %{ $missing->{$group} } == 0) {
			delete($missing->{$group});
		}
	}
	return $missing;
}

sub printMissing {
	my ($data, $missing) = @_;
	foreach my $group (sort { $a <=> $b } (keys %{ $missing })) {
		print $data->{$group}{'name'}.":\n";
		foreach my $item (sort { $a <=> $b } (keys %{ $missing->{$group} })) {
			print "\t".$missing->{$group}{$item}."\n";
		}
	}
}

if ($#ARGV == -1) {
	print "usage: -f|--file BPO_Data_File -a|--api API_Data_File [groups]\n";
	print "API_Data_File may be either a dump from the API, or a json containing one or Multiple ApiKeys\n";
	print "groups may be groups to look for missing BPOs, if omitted,\n";
	print "it will print all started and not fully owned groups of BPOs\n";
	exit;
}


while ($ARGV[0] && $ARGV[0] ne "") {
	if ($ARGV[0] =~ /(--file|-f)/) {
		shift;
		$file = $ARGV[0];
	} elsif ($ARGV[0] =~ /(--api|-a)/) {
		shift;
		$apifile = $ARGV[0];
	} elsif ($ARGV[0] =~ /(--characterid|-c)/i) {
		shift;
		$cid = $ARGV[0];
	}
	else {
		push(@groups, $ARGV[0]);
	}
	shift;
}

my $data = loadFile($file);
if (! defined($apifile)) {
	if ($#groups == -1) {
		printAllGroups($data);
	}
	else {
		printAllForGroups($data,\@groups);
	}
}
else {
	my $api_file_data = loadFile($apifile);
	my $api_data;
	if (ref($api_file_data) eq "HASH" && defined($api_file_data->{vCode})) {
		$api_data = getAPIData({ keyID => $api_file_data->{keyID}, vCode => $api_file_data->{vCode} });
	} elsif (ref($api_file_data) eq "ARRAY") {
		$api_data = [];
		foreach my $account (@{ $api_file_data }) {
			if (defined($account->{keyID}) && defined($account->{vCode})) {
				push(@{ $api_data }, getAPIData({ keyID => $account->{keyID}, vCode => $account->{vCode} }));
			}
			else {
				print "Not matching data for Account ".Dumper($account)."\n";
			}
		}
	}
	else {
		$api_data = $api_file_data;
	}
	#print Dumper($api_data), "\n";
	my $owned = getOwned($data, $api_data);
	#print Dumper($owned), "\n";
	my $missing = getMissingInGroup($data,$owned,\@groups);
	printMissing($data, $missing);
}

