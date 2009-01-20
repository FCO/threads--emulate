use Test::More tests => 2;

BEGIN { 
    use warnings;
    use strict;
    use_ok( 'threads::emulate' );
}

my $x : Shared;
lock \$x;
async{
   lock \$x;
   $x .= "async"
};
$x .= "main::";
unlock \$x;
sleep 1;
print $x, $/;

#ok($x eq "OK", "\"lock()\" and \"unlock()\"");
