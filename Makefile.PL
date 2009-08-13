use strict;
use warnings;
use ExtUtils::MakeMaker;

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
        'File::Glob' => 0,
        'Fcntl' => 0,
        'Pod::Usage' => 0,
        'Getopt::Long' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'File-Value-*' },
);
