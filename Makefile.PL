use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    EXE_FILES		=> [ 'snag' ],
    NAME                => 'File::Value',
    AUTHOR              => 'John A. Kunze <jak@ucop.edu>',
    VERSION_FROM        => 'lib/File/Value.pm',
    ABSTRACT_FROM       => 'lib/File/Value.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'Apache2')
      : ()),
    PM			=> {
    	'lib/File/Value.pm' => 'blib/lib/File/Value.pm',
    },
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'File-Value-*' },
);
