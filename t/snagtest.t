use 5.006;
use Test::More qw( no_plan );
use warnings;
use strict;

my $script = "snag";		# script we're testing

# XXXX this is latest as of 09.08.31
#### start boilerplate for script name and temporary directory support

$ENV{'SHELL'} = "/bin/sh";
my $td = "td_$script";		# temporary test directory named for script
# Depending on how circs, use blib, but prepare to use lib as fallback.
my $blib = (-e "blib" || -e "../blib" ?	"-Mblib" : "-Ilib");
my $bin = ($blib eq "-Mblib" ?		# path to testable script
	"blib/script/" : "") . $script;
my $cmd = "2>&1 perl -x $blib " .	# command to run, capturing stderr
	(-x $bin ? $bin : "../$bin") . " ";	# exit status will be in "$?"

use File::Path;
sub mk_td {		# make $td with possible cleanup
	-e $td			and rm_td();
	mkdir($td)		or die "$td: couldn't mkdir: $!";
}
sub rm_td {		# remove $td but make sure $td isn't set to "."
	! $td || $td eq "."	and die "bad dirname \$td=$td";
	eval { rmtree($td); };
	$@			and die "$td: couldn't remove: $@";
}

#### end boilerplate

# xxx what we're actually testing
use File::Value;

{	# file_value tests

mk_td();
my $x = '   /hi;!echo *; e/fred/foo/pbase        ';
my $y;

is file_value(">$td/fvtest", $x, "raw"), "", 'write returns ""';

is file_value("<$td/fvtest", $y, "raw"), "", 'read returns ""';

is $x, $y, 'raw read of what was written';

my $z = (-s "$td/fvtest");
is $z, length($x), "all bytes written";

file_value("<$td/fvtest", $x);
is $x, '/hi;!echo *; e/fred/foo/pbase', 'default trim';

file_value("<$td/fvtest", $x, "trim");
is $x, '/hi;!echo *; e/fred/foo/pbase', 'explicit trim';

file_value("<$td/fvtest", $x, "untaint");
is $x, 'hi', 'untaint test';

file_value("<$td/fvtest", $x, "trim", 0);
is $x, '/hi;!echo *; e/fred/foo/pbase', 'trim, unlimited';

file_value("<$td/fvtest", $x, "trim", 12);
is $x, '/hi;!echo', 'trim, max 12';

file_value("<$td/fvtest", $x, "trim", 12000);
is $x, '/hi;!echo *; e/fred/foo/pbase', 'trim, max 12000';

like file_value("<$td/fvtest", $x, "foo"), '/must be one of/',
'error message test';

like file_value("$td/fvtest", $x),
'/file .*fvtest. must begin.*/', 'force use of >, <, or >>';

is file_value(">$td/Whoa\\dude:!
  Adventures of HuckleBerry Finn", "dummy"), "", 'write to weird filename';

file_value(">$td/fvtest", "   foo		\n\n\n");
file_value("<$td/fvtest", $x, "raw");
is $x, "foo\n", 'trim on write';

rm_td();

}

#########################

{	# elide tests

is elide("abcdefghi"), "abcdefghi", 'simple no-op';

is elide("abcdefghijklmnopqrstuvwxyz", "7m", ".."),
"ab..xyz", 'truncate explicit, middle';

is elide("abcdefghijklmnopqrstuvwxyz"),
"abcdefghijklmn..", 'truncate implicit, end';

is elide("abcdefghijklmnopqrstuvwxyz", 22),
"abcdefghijklmnopqrst..", 'truncate explicit, end';

is elide("abcdefghijklmnopqrstuvwxyz", 22, ".."),
"abcdefghijklmnopqrst..", 'truncate explicit, end, explicit ellipsis';

is elide("abcdefghijklmnopqrstuvwxyz", "22m"),
"abcdefghi...qrstuvwxyz", 'truncate explicit, middle';

is elide("abcdefghijklmnopqrstuvwxyz", "22m", ".."),
"abcdefghij..qrstuvwxyz", 'truncate explicit, middle, explicit ellipsis';

is elide("abcdefghijklmnopqrstuvwxyz", "22s"),
"..ghijklmnopqrstuvwxyz", 'truncate explicit, start';

# XXXX this +4% test isn't really implemented
is elide("abcdefghijklmnopqrstuvwxyz", "22m+4%", "__"),
"abcdefghij__qrstuvwxyz", 'truncate explicit, middle, alt. ellipsis';

}

{
mk_td();
my $x;

$x = `$cmd $td/foo`;
chop($x);
is $x, "$td/foo", "snag simple file";

ok(-f "$td/foo", "file is a file");

use Errno;
$x = `$cmd $td/bar/foo`;
chop($x);
# Avoid using english diagnostic for comparison (fails in other locales)
#like $x, qr/.o such file or directory/, "non-existent intermediate dir";
$! = 2;		# expect this error, but need locale-based string
my $z = "" . $! . "";	# hope this forces string context
like $x, qr/$z/, "non-existent intermediate dir";

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

$x = `$cmd --lshigh $td/zaf1`;
chop($x);
is $x, "$td/zaf501", "list high version";

$x = `$cmd --lslow $td/zaf1`;
chop($x);
is $x, "$td/zaf500", "list low version";

rm_td();
}

#done_testing;
