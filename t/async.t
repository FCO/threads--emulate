use Test::More tests => 8;

BEGIN { 
    use_ok( 'threads::emulate' ); # 1
}

ok(ref async{} eq "threads::emulate::async", "async() return a object"); # 2

my $x : Shared;

$x = "NotOK";

async{
   sleep 1;
   $x .= "K";
};

$x = "";

$x .= "O";
sleep 1;

ok(($x eq "OK" or $x eq "KO"), "async() is parallel"); # 3

#SKIP:{
#   skip "I have to solve this fucking problem...", 4;

   my $thr = async{my $not_shared; $not_shared = "OK"; sleep 1; $not_shared};
   
   ok(($thr->join eq "OK"), "join() is working with scalar context"); # 4
   
   $thr = async{my @not_shared; @not_shared = qw/O K/; sleep 1; @not_shared};
   
   ok((join("-", $thr->join) eq "O-K"), "join() is working with list context"); # 5
   
   $thr = async{my @not_shared; @not_shared = qw/O K/; sleep 1; @not_shared};
   
   my @ret;
   my $tid = $thr->get_tid;
   
   until(@ret = $thr->get_return) {
       sleep 1;
   }
   
   ok((join("-", @ret) eq "O-K"), "get_return() is working"); # 6
   
   ok($tid =~ /^\d+$/, "get_tid() says that the id of the thread is $tid"); # 7

#}

TODO: {
   local $TODO = "  There's a error here... but I have to find it...";
#   skip "I have to do it...", 1;
   $x = "NotOK";

   $thr = async{local $SIG{USR1} = sub{$x = "OK"}; sleep 2};
   
   $thr->kill(10);
   sleep 2;
   ok($x eq "OK", "kill() is working"); # 8
}





