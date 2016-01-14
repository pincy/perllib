#!/usr/bin/env perl

use strict;
use warnings;

use lib "../..";
use utils::List;

sub check {
	my ($want, $is) = @_;
	if (! defined($want) || ! defined($is)) {
		print "[-] Expected ".(defined($want) ? $want : "undef");
		print " and got ".(defined($is) ? $is : "undef")."\n";
		return -1;
	}
	if (ref($want) ne ref($is)) {
		print "[!] Referenced types not matching. Expected ".ref($want);
		print " is ".ref($is)."\n";
		return 1;
	}
	if ($want != $is) {
		print "[0] Argument $is is not matching expected $want\n";
		return 2;
	}
	print "[X] $is is like expected $want\n";
	return 0;
}


my $und = undef;
my $l = utils::List->new(1);
check($l, $l->head());
$l->add(2);
check(2, $l->get(1)->data());
check($l, $l->get(1)->head());
$l->remove();
check(1, $l->data());
$l->remove();
check($und,$l->data());
$l = undef;
check($und, $l);
$l = utils::List->new(3);
check(3,$l->data());


