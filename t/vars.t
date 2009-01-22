use Test::More tests => 38;

use threads::emulate;

my $scalar : Shared;

ok(ref(tied $scalar) eq "threads::emulate::share::Scalar", "Shared scalar created");

ok(($scalar = 42) == 42, "Shared scalar accept value");

ok($scalar == 42, "Shared scalar retain value");

$scalar = sub{"OK"};

ok((ref $scalar eq "CODE" and $scalar->() eq "OK"), "Shared scalar accepting code refs");

my @array : Shared;

ok(ref(tied @array) eq "threads::emulate::share::Array", "Shared array created");

ok(($array[0] = 42) == 42, "Shared array accept value with \"STORE\"");

ok($array[0] == 42, "Shared array retain value added by \"STORE\"");

ok(push(@array, 42), "Shared array accept value with \"PUSH\"");

ok($array[1] == 42, "Shared array retain value added by \"PUSH\"");

$array[2] = sub{"OK"};

ok((ref $array[2] eq "CODE" and $array[2]->() eq "OK"), "Shared array accepting code refs added by \"STORE\"");

SKIP: {
   skip("Not done yet", 1);

   push @array, sub{"OK"};

   ok((ref $array[3] eq "CODE" and $array[3]->() eq "OK"), "Shared array accepting code refs added by \"PUSH\"");
}

@array = ();

ok(not(exists($array[0])), "Shared array accepting \"ERASE\"");

@array = (1 .. 4);

ok(@array == 4, "Shared array remember the positions");

splice @array, 1, 0, "OK";

ok((@array == 5 and $array[1] eq "OK"), "Shared array accepting \"SPLICE\"");

SKIP: {
   skip("Not done yet", 1);

   splice @array, 0, 0, sub{"OK"};

   ok(
      (ref $array[0] eq "CODE" 
       and $array[3]->() eq "OK" 
       and @array == 6
      ), "Shared array accepting code refs added by \"SPLICE\"");
}

@array = (1 .. 10);

ok((shift(@array) == 1 and @array == 9), "Shared array accepting \"SHIFT\"");

ok((pop(@array) == 10 and @array == 8), "Shared array accepting \"POP\"");

SKIP: {
   skip("Not done yet", 1);
   unshift(@array, 10);
   ok(($array[0] == 10 and @array == 9), "Shared array accepting \"UNSHIFT\"");
}

@array = (0 .. 9);

ok((delete $array[3] == 3 and @array == 10), "Shared array accepting \"DELETE\"");

SKIP: {
   skip("Not done yet", 1);
   my ($u, $d, $t) = @array[0 .. 2];
   ok(($u == 0 and $d == 1 and $t == 2), "Shared array accepting more than one position");
}

my %hash : Shared;

ok(ref(tied %hash) eq "threads::emulate::share::Hash", "Shared hash created");

ok(($hash{"the answer about life universe and everything"} = 42) == 42, "Shared hash accept value with \"STORE\"");

ok($hash{"the answer about life universe and everything"} == 42, "Shared hash retain value added by \"STORE\"");

%hash = (1 => 2, 3 => 4, 5 => 6);

ok(keys %hash == 3, "Shared hash seted by once and \"FIRSTKEY\" and \"NEXTKEY\" working");

$hash{"sub"} = sub {"OK"};

ok(
   (ref $hash{"sub"} eq "CODE" 
    and $hash{"sub"}->() eq "OK" 
   ), "Shared hash accepting code refs");


$scalar = [1 .. 5];

ok(ref(tied @{$scalar}) eq "threads::emulate::share::Array", "Shared array_ref created in a shared scalar");

ok($scalar->[4] == 5, "The shared array_ref in the shared scalar is working");

$array[0] = [1 .. 5];

ok(ref(tied @{$array[0]}) eq "threads::emulate::share::Array", "Shared array_ref created in a shared array");

ok($array[0]->[4] == 5, "The shared array_ref in the shared array is working");

$hash{array} = [1 .. 5];

ok(ref(tied @{$hash{array}}) eq "threads::emulate::share::Array", "Shared array_ref created in a shared hash");

ok($hash{array}->[4] == 5, "The shared array_ref in the shared hash is working");

{
   package teste;
   sub new {
      bless {1..6}, shift;
   }
   sub set_1 {
      my $self = shift;
      $self->{1} = shift;
   }
   sub get_1 {
      shift()->{1};
   }
}

$scalar = teste->new;

ok(ref $scalar eq "teste", "Shared scalar recived a object");

ok(ref tied %$scalar eq "threads::emulate::share::Hash", "Hash_ref on the object is shared");

ok($scalar->set_1("OK") eq "OK", "Method set is working");

ok($scalar->get_1 eq "OK", "Method get is working");

ok($scalar->set_1([1 .. 5, "OK"]), "Seting a attribute as a array_ref...");

ok($scalar->get_1->[5] eq "OK", "Method get is working with array_ref");


SKIP: {
   eval "use Data::Dumper";
   skip "There's no Data::Dumper", 1 if $@;

   my $dump = Data::Dumper->Dumper($scalar);
   
   ok(eval($dump)->get_1->[5] eq "OK", "Data::Dumper is working in this shared object");
}

sleep 1;
