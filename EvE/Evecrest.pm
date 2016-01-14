package EvE::Evecrest 0.03;

use strict;
use warnings;
use LWP::UserAgent;
use JSON;

#** @file EvE::Evecrest.pm
# @brief a simple lib for the EvE Online CREST API.
#
# @description
# Using this lib, you have to watch your application for rate limits.
#
# @TODO
# Missing Features:
# 	- partner href and other things, than child href
# 	- SSO
#**

#** @method new (args)
# @brief constructor
#
# @description
# Valid Fields for the optional args are:
# 	- debug {0 == off, 1 == on}
# 	- agent {string for the LWP::UserAgent}
# On creation, the root will be called and available for traversing on return.
# The Evecrest object will allways contain the tree from the last call under the
# {last} attribute.
#*

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {};
	my $arg = shift || undef;
	$self->{'debug'} = (defined($arg->{debug}) ? $arg->{debug} : 0);
	$self->{'crest_root'} = "https://public-crest.eveonline.com/";
	$self->{'ua'} = LWP::UserAgent->new();
	my $ua_str = (defined($arg->{agent}) ?$arg->{agent} : "perl_simple_crest");
	$self->{'ua'}->agent($ua_str);
	$self->{'last'} = undef;
	bless ($self, $class);
	load_url($self, $self->{'crest_root'});
	return $self;
}

#** @method load_url (url)
# @brief justdontusethis! never! ever!
#
#*

sub load_url {
	my ($self, $url) = @_;
	if (!defined($self) || !defined($url)) {
		return undef;
	}
	print "requesting $url\n" if $self->{'debug'} >= 2;
	my $resp = $self->{'ua'}->get($url);
	if ($resp->is_success) {
		$self->{'last'} = from_json($resp->content);
		return $self->{'last'};
	}
	else {
		print "$url returned $resp->status_line \n No JSON:\n $resp->content \n" if $self->{'debug'} >= 1;
		return undef;
	}
}

#** @method load_child_href (arg)
# @brief load the href of the child with name
#
# @description
# arg is expected to be a hash_ref with the field
# name. The function will look on the current top of the tree
# for this name and load its child href.
# Optional field is tree, where another current top can be set
#**

sub load_child_href {
	my ($self, $arg) = @_;
	if (!defined($self) || ! defined($arg)) {
		return undef;
	}
	my $tree = $arg->{'tree'} if defined($arg->{'tree'});
	my $name = $arg->{'name'} if defined($arg->{'name'});
	if (!defined($self) || !defined($name)) {
		return undef;
	}
	# using the tree from the last call
	if (!defined($tree)) {
		$tree = $self->{'last'} ;
	}
	# we're doing an initial call for the root
	if (!defined($self->{'last'})) {
		$self->{'last'} = $self->load_url($self->{'crest_root'});
	}
	else {
		if (ref($name) eq "ARRAY") {
			if (!defined($tree->{$name->[0]}{$name->[1]}{'href'})) {
				print "$name->[0] - $name->[1] not found in current tree\n" if $self->{'debug'} >= 1;
				return undef;
			}
			else {
				$self->{'last'} = $self->load_url($tree->{$name->[0]}{$name->[1]}{'href'});
			}
		}
		else {
			if (!defined($tree->{$name}{'href'})) {
				my $index = $self->search_in_array({ search => $name, arr => $tree->{'items'} });
				if (ref($index) eq "ARRAY") {
					if (defined($tree->{'items'}[$index->[0]]{$index->[1]}) &&
						defined($tree->{'items'}[$index->[0]]{'href'})) {
						$self->{'last'} = $self->load_url($tree->{'items'}[$index->[0]]{'href'});
					}
				} else {
					print "$name not found in current tree\n" if $self->{'debug'} >= 1;
					return undef;
				}
			}
			else {
				$self->{'last'} = $self->load_url($tree->{$name}{'href'});
			}
		}
	}
	return $self->{'last'};
}

#** @method load_child_multipage (arg)
# @brief same as load_child_href, but for multipage targets
#
#**

sub load_child_multipage {
	my ($self, $arg) = @_;
	if (!defined($self) || ! defined($arg)) {
		return undef;
	}
	my $tree = $arg->{'tree'} if defined($arg->{'tree'});
	my $name = $arg->{'name'} if defined($arg->{'name'});
	if (!defined($self) || !defined($name)) {
		return undef;
	}
	# using the tree from the last call
	if (!defined($tree)) {
		$tree = $self->{'last'} ;
	}
	my @items = ();
	do {
		$tree = $self->load_child_href({
				tree => $tree,
				name => $name,
			});
		@items = (@items, @{$self->{'last'}{'items'}});
		$name = "next";
	} while (defined($self->{'last'}{'next'}));
	$self->{'last'}{'items'} = \@items;
	return $self->{'last'};
}

#** @method search_in_array (arg)
# @brief searches for a string in the supplied array and returns its index
#
# @description
# arg may be a 
# 	- hash_ref with the fields \a search and \a arr
# 	- array_ref with [ $search, $arr]
#*

sub search_in_array {
	my ($self, $arg) = @_;
	if (!defined($self) && ! defined($arg)) {
		return undef;
	}
	my $search = $arg->{'search'} if defined($arg->{'search'});
	my $arr = $arg->{'arr'} if defined($arg->{'arr'});
	if (ref($arg) eq "ARRAY") {
		($search,$arr) = @{ $arg };
	}
	if (!defined($arr)) {
		foreach my $k (keys %{$self->{'last'}}) {
			if (ref($self->{'last'}{$k}) eq "ARRAY") {
				$arr = $self->{'last'}{$k};
				last;
			}
		}
	}
	for (my $i=0; $i <= $#{$arr}; $i++) {
		if (ref($arr->[$i]) eq "HASH") {
			foreach my $k (keys %{$arr->[$i]}) {
				if ($k =~ /$search/) {
					return $i;
				}
				elsif ($arr->[$i]{$k} =~ /$search/) {
					return [$i, $k];
				}
			}
		}
	}
	return undef;
}


1;
