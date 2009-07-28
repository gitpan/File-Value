#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'File::Value' );
}

diag( "Testing File::Value $File::Value::VERSION, Perl $], $^X" );
