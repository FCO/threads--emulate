#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'threads::emulate' );
}

diag( "Testing threads::emulate $threads::emulate::VERSION, Perl $], $^X" );
