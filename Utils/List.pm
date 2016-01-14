package Utils::List 0.02;

use strict;
use warnings;
use utils::Backup;

#** @file Utils::List.pm
# @brief simple linked list
#
# Provides a single linked list for anonymous data
#*

#** @method new (args)
# @brief the constructor
#
# @description
# args may be:
#	- just the data
#	- hash_ref with the fields {data, head, next}
#	- array_ref with the fields [data, head, next]
# If \a data or \a next are not set, they will be undefined.
# Fallback for \a head is $self.
#*

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {};
	my $args = shift || undef;
	my ($data,$next) = undef;
	if (defined($args) && ref($args) eq "HASH") {
		$self->{data} = $args->{data} || undef;
		$self->{head} = $args->{head} || $self;
		$self->{next} = $args->{next} || undef;
	} elsif (defined($args) && ref($args) eq "ARRAY") {
		$self->{data} = $args->[0] || undef;
		$self->{head} = $args->[1] || $self;
		$self->{next} = $args->[2] || undef;
	} elsif (defined($args)) {
		$self->{data} = $args;
		$self->{head} = $self;
		$self->{next} = undef;
	}
	bless ($self, $class);
	return $self;
}

#** @method head (optional args)
# @brief getter/setter method
#
# @description
# If optional args is supplied, it will be set before
# returning the new value.
#*

sub head {
	my ($self, $args) = @_;
	if (defined($self) && defined($args)) {
		$self->{head} = $args
	}
	return $self->{head};
}

#** @method data (optional args)
# @brief getter/setter method
#
# @description
# If optional args is supplied, it will be set before
# returning the new value.
#*

sub data {
	my ($self, $args) = @_;
	if (defined($self) && defined($args)) {
		$self->{data} = $args;
	}
	return $self->{data};
}

#** @method next (optional args)
# @brief getter/setter method
#
# @description
# If optional args is supplied, it will be set before
# returning the new value.
#*

sub next {
	my ($self, $args) = @_;
	if (defined($self) && defined($args)) {
		$self->{next} = $args;
	}
	return $self->{next};
}

#** @method get (index)
# @brief returns the element at index
#
# @description
# If index is greater than num of Elements or
# negative, the last element in the list
#*


sub get {
	my ($self, $index) = @_;
	if (! defined($self) || $index < 0) {
		return undef;
	}
	my $tmp = $self->{head};
	my $cur = 0;
	while ($cur != $index) {
		if (defined($tmp->{next})) {
			$tmp = $tmp->{next};
			$cur++;
		}
		else {
			return undef;
		}
	}
	return $tmp;
}

#** @method add (data, optional index)
# @brief creates a new element with data and saves it at index or the end
#
#*

sub add {
	my ($self, $data, $index) = @_;
	if (! defined($self) || ! defined($data)) {
		return undef;
	}
	if (ref($data) eq "HASH") {
		$index = $data->{index};
		$data = $data->{data};
	} elsif (ref($data) eq "ARRAY") {
		$index = $data->[1];
		$data = $data->[0];
	}
	else {
		if (! defined($index)) {
			$index = -1;
		}
	}
	my $tmp = $self->{head};
	# insert at the beginning
	if ($index == 0) {
		my $elem = List->new({ data => $data, head => undef, next => $self->{head} });
		do {
			$tmp->{head} = $elem;
			$tmp = $tmp->{next};
		} while (defined($tmp->{next}));
		return $elem;
	}
	my $cur = 0;
	my $last = undef;
	while (defined($tmp->{next}) && $cur != $index) {
		$last = $tmp;
		$tmp = $tmp->{next};
		$cur++;
	}
	# cases:
	# - insert at the beginning
	# - insert in the middle
	# - insert at the end
	if ($cur == $index) {
		my $elem = utils::List->new({ data => $data, head => $self->{head}, next => $tmp->{next} });
		$last->{next} = $elem;
	}
	else {
		my $elem = utils::List->new({ data => $data, head => $self->{head}, next => undef });
		$tmp->{next} = $elem;
	}
	return $self->{head};
}

#** @method remove (optional index)
# @brief removes the element at index or the last, if none supplied
#
#*

sub remove {
	my ($self, $index) = @_;
	if (! defined($self)) {
		return undef;
	}
	if (! defined($index) || $index < 0) {
		$index = -1;
	}
	if ($self->{head} == $self && ! defined($self->{next})) {
		my $tmp = $self->{data};
		$self->{data} = undef;
		return $tmp;
	}
	my $cur = 0;
	my $last = undef;
	my $tmp = $self->{head};
	while (defined($tmp->{next}) && $cur != $index) {
		$last = $tmp;
		$tmp = $tmp->{next};
		$cur++;
	}
	my $data = $tmp->{data};
	$last->{next} = undef;
	$tmp = undef;
	return $data;
}

#** @method load (filename)
# @brief loads the in filename saved listed
#
# @returns undefined on ambigous arguments
# @returns -1 if \a filename is not readable
# @returns -2 if opening fails
# @returns the loaded list
#*

sub load {
	my ($self, $filename) = @_;
	if (! defined($self) || ! defined($filename)) {
		return undef;
	}
	if (! -r $filename) {
		return -1;
	}
	my ($fh, $str);
	open($fh, "<", $filename) or return -2;
	while (my $line = <$fh>) {
		$str .= $line;
	}
	close($fh);
	my $data = from_json($str);
	return $data;
}

#** @method save (filename)
# @brief saves the supplied list starting with the supplied element
#
# @returns undefined on ambigous arguments
# @returns -1 if filename exists and backup fails
# @returns self on success
#*

sub save {
	my ($self, $filename) = @_;
	if (! defined($self) || ! defined($filename)) {
		return undef;
	}
	if (-f $filename) {
		if (utils::Backup::backup($filename) != 0) {
			return -1;
		}
	}
	my $fh;
	open($fh, ">", $filename);
	print $fh, to_json($self);
	close($fh);
	return $self;
}

1;

