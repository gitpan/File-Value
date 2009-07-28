package File::Value;

use warnings;
use strict;

=head1 NAME

File::Value - manipulate file name or content as a single value (V0.01)

=cut

our $VERSION;
$VERSION = sprintf "%d.%02d", q$Name: Release-0-12 $ =~ /Release-(\d+)-(\d+)/;

=head1 SYNOPSIS

 use File::Value;           # to import routines into a Perl script

 ($msg = file_value(">pid_file", $pid))  # Example: store a file value
         and die("pid_file: $msg\n");
  ...
 ($msg = file_value("<pid_file", $pid))  # Example: read a file value
         and die("pid_file: $msg\n");

 print elide($title, "${displaywidth}m")      # Example: fit long title
        if (length($title) > $displaywidth);  # by eliding from middle

=head1 DESCRIPTION

These are general purpose routines that support the treatment of a file's
contents or a file's name as a single data value.

=cut

#=head1 EXPORT
#
#A list of functions that can be exported.  You can delete this section
#if you don't export anything, such as for a purely object-oriented module.
#

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(
	elide
	file_value
	high_version
	snag_dir
	snag_file
	snag_version
);
our @EXPORT_OK = qw(
);

=head1 FUNCTIONS

=cut

=head2 elide( $s, $max, $ellipsis )

Take input string $s and return a shorter string with an ellipsis marking
what was deleted.  The optional $max parameter (default 16) specifies the
maximum length of the returned string, and may optionally be followed by
a letter indicating where the deletion should take place:  'e' means the
end of the string (default), 's' the start of the string, and 'm' the
middle of the string.  The optional $ellipsis parameter specifies how the
deleted characters will be represented; it defaults to ".." for 'e' or 's'
deletion, and to "..." for 'm' deletion.

=cut

# xxx unicode friendly??
#
# XXXX test with \n in string???
my $max_default = 16;		# is there some sense to this? xxx use
				# xxx fraction of display width maybe?

sub elide { my( $s, $max, $ellipsis )=@_;

	return undef
		if (! defined($s));
	$max ||= $max_default;
	return undef
		if ($max !~ /^(\d+)([esmESM]*)([+-]\d+%?)?$/);
	my ($maxlen, $where, $tweak) = ($1, $2, $3);

	$where ||= "e";
	$where = lc($where);

	$ellipsis ||= ($where eq "m" ? "..." : "..");
	my $elen = length($ellipsis);

	my ($side, $offset, $percent);		# xxx only used for "m"?
	if (defined($tweak)) {
		($side, $offset, $percent) = ($tweak =~ /^([+-])(\d+)(%?)$/);
	}
	$side ||= ""; $offset ||= 0; $percent ||= "";
	# XXXXX finish this! print "side=$side, n=$offset, p=$percent\n";

	my $slen = length($s);
	return $s
		if ($slen <= $maxlen);	# doesn't need elision

	my $re;		# we will create a regex to edit the string
	# length of orig string after that will be left after edit
	my $left = $maxlen - $elen;

	my $retval = $s;
	# Example: if $left is 5, then
	#   if "e" then s/^(.....).*$/$1$ellipsis/
	#   if "s" then s/^.*(.....)$/$ellipsis$1/
	#   if "m" then s/^.*(...).*(..)$/$1$ellipsis$2/
	if ($where eq "m") {
		# if middle, we split the string
		my $half = int($left / 2);
		$half += 1	# bias larger half to front if $left is odd
			if ($half > $left - $half);	# xxx test
		$re = "^(" . ("." x $half) . ").*("
			. ("." x ($left - $half)) . ")\$";
			# $left - $half might be zero, but this still works
		$retval =~ s/$re/$1$ellipsis$2/;
	}
	else {
		my $dots = "." x $left;
		$re = ($where eq "e" ? "^($dots).*\$" : "^.*($dots)\$");
		if ($where eq "e") {
			$retval =~ s/$re/$1$ellipsis/;
		}
		else {			# else "s"
			$retval =~ s/$re/$ellipsis$1/;
		}
	}
	return $retval;
}

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

=cut

# if length is 0, go for it.
#
my $ridiculous = 4294967296;	# max length is 2^32  XXX better way?

sub file_value { my( $file, $value, $how, $length )=@_;

	my $ret_value = \$_[1];
	use constant OK => "";		# empty string on return means success

	! defined($file) and
		return "needs a file name";

	# make caller be explicit about whether doing read/write/append
	#
	$file !~ /^\s*(<|>|>>)\s*(\S.*)/ and
		return "file ($file) must begin with '<', '>', or '>>'";
	my ($mode, $statfname) = ($1, $2);

	# we're to do value-to-file
	# in this case we ignore $how and $length
	# XXX should we not support a trim??
	if ($mode =~ />>?/) {
		! defined($value) and
			return "needs a value to put in '$file'";
		! open(OUT, $file) and
			return "$statfname: $!";
		my $r = print OUT $value;
		close(OUT);
		return ($r ? OK : "write failed: $!");
	}
	# If we get here, we're to do file-to-value.

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

	$how ||= "trim";		# trim (def), raw, untaint
	$how = lc($how);
	$how ne "trim" && $how ne "raw" && $how ne "untaint" and
		return "third arg ($how) must be one of: trim, raw, or untaint";

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

=head2 high_version( $template )

Return the number and name of the highest numbered existing version
of $template (defaults to ""), where numbered versions have the form
/$template\d+$/, eg, "v" for v001, v02, v3, or "foo.v" for foo.v1, ...,
foo.v129 .  Return (-1, undef) if no numbered versions exist.

=cut

use File::Glob ':glob';		# standard use of module, which we need
				# as vanilla glob won't match whitespace

sub high_version { my( $template )=@_;

	$template ||= "";
	my ($max, $n, $fname) = (-1, -1, undef);
	for (grep(   /$template\d+$/, bsd_glob("$template*")   )) {
		($n) = m/(\d+)$/;	# extract number for comparisons
		$max < $n and
			($max, $fname) = ($n, $_);
	}
	return ($max, $fname);
}

=head2 snag_version( $template[, $as_dir[, $no_type_mismatch]] )

Create the lowest numbered available version of a file or directory that
is higher than the highest existing version, and return a two-element
array containing the number and name of the node that was obtained, or
(-1, $error_msg) on failure.  If no numbered version exists, the version
that will be created will be a file, or a directory if $as_dir is true
(default is false).  If $no_type_mismatch is true (default is false), it
is an error if the type of the highest version (file or directory) is
different from the requested type.  If a race condition is detected,
snag_version will try again with the next higher version number, but
won't do this more than a few times.

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

=cut

sub snag_version { my( $template, $as_dir, $no_type_mismatch )=@_;

	return (-1, "no base name given")	if ! defined $template;

	# Carve off terminal digit string $digits ("1" default).
	my $digits = ($template =~ s/(\d+)$//)
		? $1 : "1";	
	my $vfmt = '%0'. length($digits) . 'd';

	$no_type_mismatch ||= 0;	# default this arg to false
	my ($hnum, $hnode) = high_version($template);
	if ($hnum == -1) {
		$as_dir ||= 0;		# default node type is "file"
		$hnum = $digits - 1;	# number we'll start trying for
	}
	else {				# current high is in $hnode
		my $isa_dir = -d $hnode;

		# Note that ||= can't be used to set default if 0 (or "")
		# is a valid specified value, as for $as_dir below.
		#
		if (defined $as_dir) {
			$no_type_mismatch and	# if intolerant of and if there
				($isa_dir xor $as_dir) and	# is a mismatch
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
		return ($hnum, $try)	if ! $msg;	# success
		return (-1, $msg)	if $msg ne "1";	# error, not race
	}
	return (-1, "gave up after " . MAX_TRIES . " races lost");
}

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

=cut

sub snag_dir { my( $node )=@_;

	return "snag_dir: no directory given"	if ! defined $node;
	return ""	if mkdir($node);
	return "1"	if -e $node;	# race condition detector
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
	return "1"	if -e $node;	# race condition detector
	return $!;	# else return system error message
}

=head1 SEE ALSO

touch(1)

=head1 AUTHOR

John A. Kunze, I<jak at ucop.edu>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-file-value at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=File-Value>.  I will be
notified, and then you'll automatically be notified of progress on your
bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc File::Value

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=File-Value>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/File-Value>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/File-Value>

=item * Search CPAN

L<http://search.cpan.org/dist/File-Value/>

=back

=head1 COPYRIGHT AND LICENSE

Copyright 2009 UC Regents.  Open source Apache License, Version 2.

=cut

1;	# End of File::Value
