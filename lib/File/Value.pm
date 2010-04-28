package File::Value;
 
use 5.006;
use warnings;
use strict;

our $VERSION;
$VERSION = sprintf "%d.%02d", q$Name: Release-0-21 $ =~ /Release-(\d+)-(\d+)/;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(
	file_value
	list_high_version
	list_low_version
	snag_dir
	snag_file
	snag_version
);
our @EXPORT_OK = qw(
);

# if length is 0, go for it.
#
my $ridiculous = 4294967296;	# max length is 2^32  XXX better way?

sub file_value { my( $file, $value, $how, $length )=@_;

	my $ret_value = \$_[1];
	use constant OK => "";		# empty string on return means success

	$file		or return "needs a file name";

	# make caller be explicit about whether doing read/write/append
	#
	$file !~ /^\s*(<|>|>>)\s*(\S.*)/ and
		return "file ($file) must begin with '<', '>', or '>>'";
	my ($mode, $statfname) = ($1, $2);

	$how ||= "trim";		# trim (def), raw, untaint
	$how = lc($how);
	$how ne "trim" && $how ne "raw" && $how ne "untaint" and
		return "third arg ($how) must be one of: trim, raw, or untaint";

	if ($mode =~ />>?/) {	# if we're doing value-to-file (> or >>)
		# ignore $how and $length, but we need specified $value
		! defined($value) and
			return "needs a value to put in '$file'";
		# for $how, here we only understand "trim" or "raw", but
		# "trim" removes initial and final \n, adding one final \n
		if ($how eq "trim") {
			$value =~ s/^\s+//s;
			$value =~ s/\s+$/\n/s;
		}
		! open(OUT, $file) and
			return "$statfname: $!";
		my $r = print OUT $value;
		close(OUT);
		return ($r ? OK : "write failed: $!");
	}

	# If we get here, we're doing file-to-value case.

	my $go_for_it = (defined($length) && $length eq "0" ? 1 : 0);
	my $statlength = undef;

	if (defined($length)) {
		$length !~ /^\d+$/ and
			return "length unspecified or not an integer";
	}
	elsif ($statfname ne "-") {
		# no length means read whole file, but be reasonable
		$statlength = (-s $statfname);
		! defined($statlength) and
			return "$statfname: $!";
		$length = ($statlength > $ridiculous
			? $ridiculous : $statlength);
	}
	else {
		$length = $ridiculous;
	}

	! open(IN, $file) and
		return "$statfname: $!";
	if ($go_for_it) {		# don't be reasonable about length
		local $/;
		$$ret_value = <IN>;
		close(IN);
	}
	else {
		my $n = read(IN, $$ret_value, $length);
		close(IN);
		! defined($n) and
			return "$statfname: failed to read $length bytes: $!";
		# XXXX do we have to read in a loop until all bytes come in?
		return "$statfname: read fewer bytes than expected"
			if (defined($statlength) && $n < $statlength);
	}

	if ($how eq "trim") {
		$$ret_value =~ s/^\s+//;
		$$ret_value =~ s/\s+$//;
	}
	elsif ($how eq "untaint") {
		if ($$ret_value =~ /([-\@\w.]+)/) {
			$$ret_value = $1;
		}
	}
	# elsif ($how eq "raw") { then no further processing }

	return OK;
}

use File::Glob ':glob';		# standard use of module, which we need
				# as vanilla glob won't match whitespace

sub list_high_version { my( $template )=@_;

	$template ||= "";
	my ($max, $n, $fname) = (-1, -1, undef);
	for (grep(   /$template\d+$/, bsd_glob("$template*")   )) {
		($n) = m/(\d+)$/;	# extract number for comparisons
		$max < $n and
			($max, $fname) = ($n, $_);
	}
	return ($max, $fname);
}

# Tempting for program maintenance to combine computation of low and high,
# but that would make computation of the high (by far the most common call)
# pay a performance penalty for a seldom used value.  So we separate.
#
sub list_low_version { my( $template )=@_;

	$template ||= "";
	my ($min, $n, $fname) = (-1, -1, undef);
	for (grep(   /$template\d+$/, bsd_glob("$template*")   )) {
		($n) = m/(\d+)$/;	# extract number for comparisons
		$min > $n || $min < 0 and
			($min, $fname) = ($n, $_);
	}
	return ($min, $fname);
}

sub snag_opt_defaults { return {

	as_dir		 => undef,	# create node as dir (default is to
					# infer it from argument if possible)
	no_type_mismatch => 0,		# complain if mismatch (default don't)
	mknextcopy	 => 0,		# copy unnumbered file (default don't)
	};
}

sub snag_version { my( $template, $opt ) = (shift, shift);

	return (-1, "no base name given")	if ! defined $template;
	$opt ||= snag_opt_defaults();
	my $as_dir = $opt->{as_dir};	# might be undefined (ok)

	# Carve off terminal digit string $digits ("1" default).
	my $digits = ($template =~ s/(\d+)$//)
		? $1 : "1";	
	my $vfmt = '%0'. length($digits) . 'd';	# version number format

	$opt->{mknextcopy} and -f $template ||	# pre-condition of mknextcopy
		return (-1, "mknextcopy only works if '$template' is a "
			. "pre-existing file");

	$opt->{no_type_mismatch} ||= 0;	# default this option to false
	my ($hnum, $hnode) = list_high_version($template);
	if ($hnum == -1) {
		$as_dir ||= 0;		# default type here is "file"
		$hnum = $digits - 1;	# number we'll start trying for
	}
	else {				# current high is in $hnode
		my $isa_dir = -d $hnode;

		# Note that ||= can't be used to set default if 0 (or "")
		# is a valid specified value, as for $as_dir below.
		#
		if (defined $as_dir) {
			$opt->{no_type_mismatch} and	# if intolerant and 
				($isa_dir xor $as_dir) and	# a mismatch
				return (-1, "high version ($hnode" .
					($isa_dir ? "/" : "") .  ") is a " .
					($isa_dir ? "directory" : "file") .
					", different from type requested");
		}
		else {
			$as_dir = $isa_dir;	# infer type from $hnode
		}
	}

	use constant MAX_TRIES => 3;	# number of races we might run
	my $hmax = $hnum + MAX_TRIES;
	my ($try, $msg);
	while (++$hnum <= $hmax) {
		$try = $template . sprintf($vfmt, $hnum);
		$msg = $as_dir ?
			snag_dir($try) : snag_file($try);
		last			if ! $msg;	# success
		#return ($hnum, $try)	if ! $msg;	# success
		return (-1, $msg)	if $msg ne "1";	# error, not race
	}
	$msg and return (-1, "gave up after " . MAX_TRIES . " races lost");

	# If we get here, $try contains the node that we snagged.
	if ($opt->{mknextcopy}) {
		return (-1, "mknextcopy only works if '$try' is a file")
			unless -f $try; 	# re-check pre-condition
		use File::Copy;
		copy($template, $try) or
			return (-1, "mknextcopy failed: $!");
	}
	return ($hnum, $try);
}

sub snag_dir { my( $node )=@_;

	return "snag_dir: no directory given"	if ! defined $node;
	return ""	if mkdir($node);
	return "1"	if -e $node;	# potential race condition detector
	return $!;	# else return system error message
}

use Fcntl;
sub snag_file { my( $node )=@_;

	return "snag_file: no file given"	if ! defined $node;
	return ""
		# Create, but don't succeed if it doesn't exist (O_EXCL).
		# Return success even if for some reason the close fails.
		if sysopen(FH, $node, O_CREAT | O_EXCL)
			&& (close(FH) || 1);
	return "1"	if -e $node;	# potential race condition detector
	return $!;	# else return system error message
}

1;	# End of File::Value

__END__

=pod

=head1 NAME

File::Value - manipulate file name or content as a single value

=head1 SYNOPSIS

 use File::Value;              # to import routines into a Perl script

 ($msg = file_value(">pid_file", $pid))  # Example: store a file value
         and die "pid_file: $msg\n";

 ($msg = file_value("<pid_file", $pid))  # Example: read a file value
         and die "pid_file: $msg\n";

 snag_dir($dirname);           # attempt to create directory $dirname
 snag_file($filename);         # attempt to create file $filename

 ($num, $name) =               # return number and name of node created
  snag_version(                # with lowest numbered available version
   $template, {                # base name with possible terminal digits
   as_dir => undef,            # create as a directory (default file)
   no_type_mismatch => 0,      # complain if mismatch (default don't)
   mknextcopy => 0 });         # copy unnumbered file (default don't)

 list_high_version($template); # report highest version found
 list_low_version($template);  # report lowest version found

=head1 DESCRIPTION

These are general purpose routines that support the treatment of a file's
contents or a file's name as a single data value.

=for later =head1 EXPORT
A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 FUNCTIONS

=head2 file_value( $file, $value, $how, $maxlen )

Copy contents of file $file to or from a string $value, returning the
empty string on success or an error message on failure.  To copy $value
to $file, start $file with ">" or ">>".  To copy $file to $value, start
$file with "<".  The optional $how parameter qualifies how the copy will
be done:  "trim" (default) trims whitespace from either end, "untaint"
removes various suspicious characters that might cause security problems
(no guarantees), and "raw" does no processing at all.  The optional
parameter $maxlen dictates the maximum number of octets that will be
copied.  It defaults for sanity to 4GB; use a value of 0 (zero) to remove
even that limit.

=head2 snag_file( $filename ), snag_dir( $dirname )

The snag_file() and snag_dir() routines try to create directory or file
$node.  Return "" on successful creation, "1" if $node already exists,
else an error message.  We check existence only if the creation attempt
fails, which permits efficient handling of race conditions.  For example,

	$msg = -e $node ? "1"		# either branch can return "1"
		: snag_file($node);	# race lost if this returns "1"
	if ($msg eq "1") {
		$fname = snag_version("$node.v1");
	}

checks existence before calling us, avoiding subroutine and system
call overhead, and it can rely on the "1" return to detect a lost
race and take appropriate action.  Generally returns strings, so the
caller must check with string comparison (ne, eq instead of !=, ==).

=head2 snag_version( $template, $options )

Create the lowest numbered available version of a file or directory that
is higher than the highest existing version, and return a two-element
array containing the number and name of the node that was obtained, or
(-1, $error_msg) on failure.  The $options argument is an optional hash
reference in which the following keys are recognized:

  as_dir           => undef,    # create node as dir (default is to
                                # infer it from $template if possible)
  no_type_mismatch => 0,        # complain if mismatch (default don't)
  mknextcopy       => 0,        # copy unnumbered file (default don't)

If no numbered version exists, the version that will be created will be a
file, or a directory if C<as_dir> is true (default is false unless the
original node was a directory).  If C<no_type_mismatch> is true (default
is false), it is an error if the type of the highest version (file or
directory) is different from the requested type.  If a race condition is
detected, snag_version will try again with the next higher version
number, but won't do this more than a few times.  If C<mknextcopy> is
true (default false), the new node will receive a copy of the unnumbered
file corresponding to $template (it is an error if it does not exist
already as an unnumbered file).

The $template parameter is used to search for and create numbered
versions.  If it doesn't end in a digit substring ($digits), the digit
"1" is assumed.  The length of $digits determines the minimum width of
the version number, zero-padded if necessary, and the value of $digits
is the first version number to use if no numbered versions exist.
Examples:

  $template="x";	# x1, x2, ..., x9, x10, ..., x101, ...
  $template="x.3";	# x.3, x.4, ..., x.101, x.102, ...
  $template="v001";	# v001, v002, ..., v101, ..., v1001, ...

One common use case calls for version numbers only when the file or
directory that you want to create already exists.  For $name="foo",

   if (($msg = snag_file($name)) eq 1)
   	{ ($n, $name) = snag_version("$name-"); }

creates foo, foo-1, foo-2, foo-3 etc.  Another common use case calls for
version numbers on every version.  For example, if versions v996, v997,
v998 currently exist, running

   ($n, $name) = snag_version("v001");

will then create v999, v1000, v1001, etc.

=head2 list_high_version( $template )

Return the number and name of the highest numbered existing version
of $template (defaults to ""), where numbered versions have the form
/$template\d+$/, eg, "v" for v001, v02, v3, or "foo.v" for foo.v1, ...,
foo.v129 .  Return (-1, undef) if no numbered versions exist.

=head2 list_low_version( $template )

Similar to list_high_version(), but return the number and name of the lowest
numbered existing version.

=head1 SEE ALSO

touch(1)

=head1 AUTHOR

John A. Kunze, I<jak at ucop.edu>

=head1 COPYRIGHT AND LICENSE

Copyright 2009-2010 UC Regents.  Open source BSD license.
