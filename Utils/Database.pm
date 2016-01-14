package Utils::Database 0.01;

use strict;
use warnings;
use DBI;

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

sub connect {
	my ($self, $args) = @_;
	if (! checkfields($self,["type","path"])) {
		return undef;
	}
	$self->{dbh} = DBI->connect("dbi:".$self->{type}.":dbname=".$self->{path},
					(defined($self->{username}) ? $self->{username} : ""),
					(defined($self->{password}) ? $self->{password} : ""),
					(defined($self->{dbargs}) ? $self->{dbargs} : {}));
}



