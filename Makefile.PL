use 5.000000;
use strict;
use warnings;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile(
    EXE_FILES		=> [ 'snag' ],
    NAME                => 'File::Value',
    AUTHOR              => 'John A. Kunze <jak@ucop.edu>',
    VERSION_FROM        => 'VERSION',
    ABSTRACT_FROM       => 'lib/File/Value.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'Apache2')
      : ()),
    PM			=> {
    	'lib/File/Value.pm' => 'blib/lib/File/Value.pm',
    },
    PL_FILES            => {},
    PREREQ_PM => {
        'Getopt::Long'	=> 0,
        'File::Glob'	=> 0,
        'Pod::Usage'	=> 0,
        'Fcntl'		=> 0,
	'warnings'	=> 0,
	'strict'	=> 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'File-Value-*' },
);
