use Test::More tests => 2;

BEGIN { 
    use warnings;
    use strict;
    use_ok( 'threads::emulate' );
}

ok(($threads::emulate::pid and kill 0 => $threads::emulate::pid), "Fork \"master\" is runing");
