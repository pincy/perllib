package Utils::Database 0.01;

use strict;
use warnings;
use DBI;

#** @file Utils::Database.pm
# @brief simple Database Interface
#
#*

#** @method new (args)
# @brief the constructor
#
# @description
# args may be a hash_ref with the fields
# 	- type (the database type)
# 	- path (the path to the database)
# 	- username
# 	- password
# 	- dbargs (will be handed to the connect method)
# At least in one of the constructor or the connect call a type and 
# path needs to be provided.
#*

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {};
	my $args = shift || undef;
	$self->{fields} = ["type", "path", "username", "password", "dbargs"];
	if (defined($args)) {
		for (my $i=0; $i<=$#{ $self->{fields} }; $i++) {
			my $field = $self->{fields}->[$i]
			if (ref($args) eq "ARRAY") {
				$self->{$field} = $args->[$i];
			} elsif (ref($args) eq "HASH") {
				$self->{$field} = $args->{$field} || undef;
			}
		}
	}
	bless ($self, $class);
	return $self;
}

#** @method checkfields (fields)
# @brief check if fields exist in self
#
# @description
# If fields is an array_ref, it will check for each provided key.
# Else fields will be handled like a scalar
#
# @returns undef on error or not defined field
# @returns 1 on success
#*

sub checkfields {
	my ($self, $fields) = @_;
	if (! defined($self)) {
		return undef;
	}
	if (defined($fields)) {
	 	if (ref($fields) eq "ARRAY") {
			foreach my $field (@{ $fields }) {
				if (! defined($self->{$field})) {
					return undef;
				}
			}
		}
		else (! defined($self->{$fields})) {
			return undef;
		}
	}
	return 1;
}

#** @method connect (args)
# @brief establishes the connectioin to the database
#
# @description
# Optional args is handled like args in the constructor and will
# be saved in self for future.
# The Database handle will be held in self->{dbh}.
#
# @returns undef on argument error
# @returns 0 on database connection error
# @returns 1 on success
#*

sub connect {
	my ($self, $args) = @_;
	if (! checkfields($self,["type","path"])) {
		return undef;
	}
	if (defined($args)) {
		for (my $i=0; $i<=$#{ $self->{fields} }; $i++) {
			my $field = $self->{fields}->[$i]
			if (ref($args) eq "ARRAY") {
				$self->{$field} = $args->[$i] || $self->{$field} || undef;
			} elsif (ref($args) eq "HASH") {
				$self->{$field} = $args->{$field} || $self->{$field} || undef;
			}
		}
	}
	$self->{dbh} = DBI->connect("dbi:".$self->{type}.":dbname=".$self->{path},
					(defined($self->{username}) ? $self->{username} : ""),
					(defined($self->{password}) ? $self->{password} : ""),
					(defined($self->{dbargs}) ? $self->{dbargs} : {}))
					or return 0;
	return 1;
}

#** @method sendqry (query)
# @brief for sending a query without a returned value
#
# @returns undef on bad arguments
# @returns the return status of connect() if it fails
# @returns an error string on fail
# @returns 1 on success
#*

sub sendqry {
	my ($self, $q) = @_;
	if (! defined($self) || ! defined($q)) {
		return undef;
	}
	if (! defined($self->{dbh})) {
		if ((my $dbret = $self->connect()) != 1) {
			return $dbret;
		}
	}
	$self->{dbh}->do($q);
	if ($self->{dbh}->errstr()) {
		return "Error: ".$self->{dbh}->errstr().", on ".$q;
	}
	return 1;
}

#** @method preparedqry (query, binds)
# @brief for sending a prepared query without a returned value
#
# @description
# If binds is just a array_ref, the call will be executed for each
# element.
# If binds is a nested array_ref, the call will be executed with t
# he nested array_ref
#
# @returns undef on bad arguments
# @returns the return status of connect() if it fails
# @returns an error string on fail
# @returns 1 on success
#*

sub preparedqry {
	my ($self, $q, $binds) = @_;
	if (! defined($self) || ! defined($q)) {
		return undef;
	}
	if (! defined($self->{dbh})) {
		if ((my $dbret = $self->connect()) != 1) {
			return $dbret;
		}
	}
	my $sth = $self->{dbh}->prepare($q);
	if (ref($binds) eq "ARRAY" && ref($binds->[0]) eq "ARRAY") {
		foreach my $rows (@{ $binds }) {
			$sth->execute(@{ $rows });
			if ($self->{dbh}->errstr()) {
				my $ret = "Error: ".$self->{dbh}->errstr().", on ".$q;
				$ret .= " with (".join(", ", @{ $rows }).")";
				return $ret;
			}
		}
	} elsif (ref($binds) eq "ARRAY") {
		foreach my $row (@{ $binds }) {
			$sth->execute(( $row ));
			if ($self->{dbh}->errstr()) {
				my $ret = "Error: ".$self->{dbh}->errstr().", on ".$q;
				$ret .= " with (".$row.")";
				return $ret;
			}
		}
	}
	return 1;
}

sub fetchqry {
	my ($self, $q, $binds) = @_;
	if (! defined($self) || ! defined($q)) {
		return undef;
	}
	if (! defined($self->{dbh})) {
		if ((my $dbret = $self->connect()) != 1) {
			return $dbret;
		}
	}
	my @vals = [];
	my $sth = $self->{dbh}->prepare($q);
	if (ref($binds) eq "ARRAY" && ref($binds->[0]) eq "ARRAY") {
		foreach my $rows (@{ $binds }) {
			$sth->execute(@{ $rows });
			my $ans = $sth->fetchrow_arrayref();
			push(@vals, $ans);
			if ($self->{dbh}->errstr()) {
				my $ret = "Error: ".$self->{dbh}->errstr().", on ".$q;
				$ret .= " with (".$row.")";
				return $ret;
			}
		}
	} elsif (ref($binds) eq "ARRAY") {
		foreach my $row (@{ $binds }) {
			$sth->execute(( $row ));
			my $ans = $sth->fetchrow_arrayref();
			push(@vals, $ans);
			if ($self->{dbh}->errstr()) {
				my $ret = "Error: ".$self->{dbh}->errstr().", on ".$q;
				$ret .= " with (".$row.")";
				return $ret;
			}
		}
	}
	return \@vals;
}

1;

