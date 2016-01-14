package Utils::Backup 0.01;

use strict;
use warnings;
use File::Copy;

sub backup {
	my ($path, $args) = @_;
	if (! -f $path) {
		return -1;
	}
	my $suffix = ".bak";
	my $filename = $path.$suffix;
	if (-f $filename) {
		my $c = 1;
		while (-f "$filename$c") {
			$c++;
		}
		$filename = "$filename$c";
	}
	if (syscopy($path, $filename) == 0) {
		return -2;
	}
	return 0;
}

1;

