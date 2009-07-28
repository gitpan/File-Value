use Test::More;
use warnings;
use strict;

my $script = 'snag';		# script we're testing

#### start boilerplate for script name and temporary directory support

my $td = "td_$script";			# temporary testing directory
my $bin = 'blib/script/' . $script;	# path to testable script
my $cmd = '2>&1 perl -x -Mblib ' .	# command to set it off
	(-x $bin ? $bin : "../$bin") . ' ';

use File::Path;
sub rm_td {				# to remove $td without big stupidity
	die("bad dirname \$td=$td")		if (! $td or $td eq '.');
	eval { rmtree($td); };
	die("$td: couldn't remove: $@")		if ($@);
}
sub mk_td {				# make $td with possible cleanup
	rm_td()		if (-e $td);
	mkdir($td)	or die("$td: couldn't mkdir: $!");
}

#### end boilerplate

# xxx what we're actually testing
use File::Value;

{
mk_td;
my $x;

# XXXX how to capture exit status
$x = `$cmd $td/foo`;
chop($x);
is $x, "$td/foo", "snag simple file";

ok(-f "$td/foo", "file is a file");

$x = `$cmd $td/bar/foo`;
chop($x);
like $x, qr/.o such file or directory/, "non-existent intermediate dir";

$x = `$cmd $td/bar/`;
chop($x);
is $x, "$td/bar/", "snag simple directory";

ok(-d "$td/bar", "directory is a directory");

$x = `$cmd -f $td/bar`;
chop($x);
is $x, "$td/bar", "snag file, forcing replace of directory";

ok(-f "$td/bar", "replacement is a file");

$x = `$cmd --next $td/bar`;
chop($x);
is $x, "$td/bar1", "snag next version of unnumbered file";

$x = `$cmd --next $td/bar/`;
chop($x);
like $x, qr/different/, "snag next dir version of file version";

$x = `$cmd --next $td/bar500`;
chop($x);
is $x, "$td/bar002", "snag version 2 padded 3, low 500, pre-existing";

$x = `$cmd --next $td/zaf500`;
chop($x);
is $x, "$td/zaf500", "snag version 500 padded 3, low 500 of non-existing";

$x = `$cmd --next $td/zaf1`;
chop($x);
is $x, "$td/zaf501", "snag version 501 padded 1, low 1 of pre-existing";

rm_td;
}

done_testing;
