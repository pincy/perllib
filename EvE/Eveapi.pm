package EvE::Eveapi 0.02;

use strict;
use warnings;
use LWP::Simple;
use JSON;
use XML::Simple;
use File::Copy;


#** @file EvE::Eveapi
# @brief Simple lib for accessing the XML API.
#
# Further explanation may come here some day.
#*

#** @method new (optional %$args)
# @brief constructor, may be called with args hash
#
#
# Valid Fields in the optional args are:
# 	- debug {0 == off, 1 == on}
# 	- agent {string for the LWP::UserAgent}
# 	- keyID
# 	- vCode
# 	- characterID
# 	- file {filename to load API Keys from, uses loadFile}
#*

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $args = shift || undef;
	my $self = {};
	$self->{'debug'} = (defined($args->{debug}) ? $args->{debug} : 0);
	$self->{'api_root'} = "https://api.eveonline.com";
	$self->{'ua'} = LWP::UserAgent->new();
	my $ua_str = (defined($args->{agent}) ?$args->{agent} : "perl_simple_api");
	$self->{'ua'}->agent($ua_str);
	$self->{keyID} = (defined($args->{keyID}) ?$args->{keyID} : undef);
	$self->{vCode} = (defined($args->{vCode}) ?$args->{vCode} : undef);
	$self->{characterID} = (defined($args->{characterID}) ?$args->{characterID} : undef);
	$self->{'url'} = undef;
	bless ($self, $class);
	if (defined($args->{file})) {
		$self = $self->loadFile($args->{file});
	}
	return $self;
}

#** @method attr ($attr,optional $val)
# @brief sets/gets attribute
#
# If called with val, it sets the value of val in attr.
# In any way, it returns the value of attr
#*

sub attr {
	my ($self, $attr, $val) = @_;
	if (! defined($self) || ! defined($attr)) { return undef; }
	if (defined($val)) {
		$self->{$attr} = $val;
	}
	return $self->{$attr};
}

#** @method loadFile (filename)
# @brief loads the API credentials from filename
#
# Loads a json file, containing one or more API credentials.
# for a single API key, it expects a hash_ref with keyID and vCode,
# for multiple the hash_refs may be listed in an array
# filename may be 
# 	- string with filename
# 	- array_ref with [filename,index]
#	- hash_ref with {name => filename, index => x}
#*

sub loadFile {
	my ($self, $name) = @_;
	if (! defined($self)) { return _dieError("called without self"); }
	my ($f,$str,$index);
	if (ref($name) eq "ARRAY") { ($name,$index) = @{ $name };}
	if (ref($name) eq "HASH") {
		$index = $name->{index};
		$name = $name->{name} || $name->{filename} || undef;
	}
	if (! defined($index)) { $index = 0; }
	if (! defined($name)) { return _dieError("called without filename"); }
	open($f, "< $name") or return _dieError("Error on opening $name\n");
	while (my $l = <$f>) { $str = "$str$l"; }
	close($f);
	my $ret = from_json($str) || undef;
	if (defined($ret) && ref($ret) eq "ARRAY") { $ret = $ret->[$index]; }
	if ($self->{debug}) { print "Read from file $name: $ret\n"; }
	if (defined($ret->{keyID})) { $self->{keyID} = $ret->{keyID}; }
	if (defined($ret->{vCode})) { $self->{vCode} = $ret->{vCode}; }
	if ($self->{debug}) { print "Loaded: keyID: $self->{keyID}, vCode: $self->{vCode}\n"; }
	return $self;
}

#** @method saveFile ($name, optional $data)
# @brief save data or the current API credentials to name
#
# If data is omitted, the current API credentials are written to name.
# In case name already exists, it will try to make a backup with the "bak"
# extension
#*

sub saveFile {
	my ($self, $name, $data) = @_;
	if (! defined($self) || ! defined($name)) { return _dieError("called without self or filename?"); }
	my $f;
	if ($self->{debug}) { print "Writing to file $name: $data\n"; }
	if (-f $name) {
		if ($self->{debug}) { print "File $name exists, creating backup\n"; }
		if (syscopy($name, $name."bak") == 0) {
			return _dieError("could not backup existing file. Error: '$!'");
		}
	}
	open($f, "> $name") or return _dieError("Error on opening $name\n");
	if (! defined($data)) {
		$data = { keyID => $self->{keyID}, vCode => $self->{vCode} }
	}
	print $f to_json($data);
	close($f);
	return $self;
}

sub _dieError {
	my ($self, $msg) = @_;
	if (! defined($msg)) { $msg = $self; }
	print STDERR $msg;
	return undef;
}

sub _getchild {
	my ($self, $arg) = @_;
	if (! defined($arg) ) { $arg = $self; }
	if (ref($arg) eq "HASH") {
		my @keys = keys %{ $arg };
		return [$keys[0], @{ _getchild($arg->{$keys[0]}) } ];
	}
	return [$arg];
}

#** @method load (optional $url)
# @brief loads url, or tries to load self->{url}
#
#*

sub load {
	my ($self, $url) = @_;
	if (! defined($self) || (! defined($url) && ! defined($self->{url}))) { return _dieError("called without self or url"); }
	if (defined($url)) { $self->{url} = $url; }
	my $resp = $self->{ua}->get($self->{url});
	if ($resp->is_success) {
		my $content = $resp->content;
		my $parser = new XML::Simple();
		my $tmp = $parser->XMLin($content);
		$self->{last} = $tmp;
		return $tmp;
	}
	else {
		return _dieError("response was ".$resp->code." - ".$resp->message."\n");
	}
	return undef;
}

#** @method loadPath (arg)
# @brief builds the url Path for the load function and calls it. plzusethis!!!
#
# arg needs to contain the path to be called. It may be:
# 	- array_ref {e.g. [ "account", "APIKeyInfo" ] }
# 	- hash_ref {e.g. { "account" => "APIKeyInfo" } }
# If arg contains a character path and characterID was not set, it will be set to
# the first characterID returned by the API
#*

sub loadPath {
	my ($self, $arg) = @_;
	if (! defined($self) || ! defined($arg)) { return _dieError("called without self or path to call"); }
	my $str = "/";
	if (ref($arg) eq "HASH") {
		$arg = _getchild($arg);
	} elsif (ref($arg) eq "ARRAY") {
		my @arr = @{ $arg };
		$str .= join("/", @arr);
	}
	else {
		$str = $arg;
	}
	if ($str =~ /^char/i && ! defined($self->{characterID})) {
		my $tmp = $self->loadPath(["Acccount","Characters"]);
		if (ref($tmp->{result}{rowset}{row}) eq "ARRAY") {
			$self->{characterID} = $tmp->{result}{rowset}{row}[0]{characterID};
		}
		else {
			$self->{characterID} = $tmp->{result}{rowset}{row}{characterID};
		}
	}
	$str .= ".xml.aspx?";
	if ($str =~ /^\/(corp|char|account)/) {
		if (! defined($self->{keyID}) || ! defined($self->{vCode})) {
			dieError("keyID or vCode not set/loaded");
		}
		$str .= "keyID=".$self->{keyID}."&";
		$str .= "vCode=".$self->{vCode};
		if ($str =~ /^\/char/) {
			if (! defined($self->{characterID})) {
				dieError("characterID not set/loaded");
			}
			$str .= "&characterID=".$self->{characterID};
		}
	}
	if ($self->{debug}) { print "dbg: query string: $str\n"; }
	$self->{url} = $self->{api_root}.$str;
	return $self->load();
}

###
# static possible data export
# - didn't find a dynamic way to get all api endpoints yet -
# status 22.09.2015
###
sub getpossibles {
	return {
		account => [ "AccountStatus", "APIKeyInfo", "Characters" ],
		api => [ "CallList" ],
		char => [ "AccountBalance", "AssetList", "CalendarEventAttendees",
			"CharacterSheet", "ContactList", "ContactNotifications", "Contracts",
			"ContractItems", "ContractBids", 
			"FacWarStats", "IndustryJobs", "Killlog", "Locations", "MailBodies",
			"MailingLists", "MailMessages", "MarketOrders", "Medals",
			"Notifications", "NotificationTexts", "Research", "SkillInTraining",
			"SkillQueue", "Standings", "UpcomingCalendarEvents", "WalletJournal",
			"WalletTransactions" ],
		corp => [ "AccountBalance", "AssetList", "ContactList", "ContainerLog",
			"Contracts", "ContractItems", "ContractBids", "CorporationSheet",
			"FacWarStats", "IndustryJobs", "Killlog", "Locations", "MarketOrders",
			"Medals", "MemberMedals", "MemberSecurity", "MemberSecurityLog",
			"MemberTracking", "OutpostList", "OutpostServiceDetail",
			"Shareholders", "Standings", "StarbaseDetail", "StarbaseList",
			"Titles", "WalletJournal", "WalletTransactions" ],
		eve => [ "AllianceList", "CertificateTree", "CharacterAffiliation",
			"CharacterID", "CharacterInfo", "CharacterName",
			"ConquerableStationList", "ErrorList", "FacWarStats",
			"FacWarTopStats", "RefTypes", "SkillTree", "TypeName" ],
		map => [ "FacWarSystems", "Jumps", "Kills", "Sovereignty",
			"SovereigntyStatus" ],
		server => [ "ServerStatus" ]
	};
}

1;
