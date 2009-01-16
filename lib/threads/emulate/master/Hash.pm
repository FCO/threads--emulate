package threads::emulate::master::Hash;
use threads::emulate::share;
use base threads::emulate::share;
use IO::Socket;

use strict;
use warnings;

our $debug = 0;

sub objtype {
   my $self = shift;
   $self->{objtype} = shift;
}

sub getobjtype {
   my $self = shift;
   $self->{objtype};
}

sub LOCK {
   #print "TRYING TO LOCK(@_)$/" if $debug >= 2;
   my $self = shift;
   my $thr  = shift;
   my $ret = 0;
   if($self->{"lock"} == -1) {
      $self->{"lock"} = $thr;
      $ret = 1;
      print "LOCK($self $thr)$/" if $debug >= 2;
   }
   $ret;
}

sub UNLOCK {
   print "UNLOCK(@_)$/" if $debug >= 2;
   my $self = shift;
   my $thr  = shift;
   my $ret;
   if($self->{"lock"} == $thr) {
      $self->{"lock"} = -1;
      $ret = 1;
   } else {
      $ret = 0;
   }
   $ret
}

sub prepare_key {
   my $self = shift;
   push @{ $self->{"keys"} }, keys %{ $self->{value} };
}

sub new {
   print "new(@_)$/" if $debug >= 2;
   my $self = bless { value => {}, "lock" => -1 }, shift;
   $self->{id} = shift;
   $self
}

sub FETCH {
   print "FETCH(@_)$/" if $debug >= 2;
   my $self = shift;
   my $index = shift;
   $self->{value}->{$index};
}

sub STORE {
   print "STORE(@_)$/" if $debug >= 2;
   print "lock()$/" if $debug >= 1;
   my $self  = shift;
   my $index = shift;
   my $value = shift;
   $self->{value}->{$index} = $value;
}

sub DELETE {
   print "DELETE(@_)$/" if $debug >= 2;
   delete shift()->{value}->{shift()};
}

sub CLEAR {
   print "CLEAR(@_)$/" if $debug >= 2;
   %{ shift()->{value} } = ();
}

sub EXISTS {
   print "EXISTS(@_)$/" if $debug >= 2;
   exists shift()->{value}->{shift()};
}

sub FIRSTKEY {
   print "FIRSTKEY(@_)$/" if $debug >= 2;
   my $r = shift;
   my $a = scalar keys %{ $r->{value} };
   (each %{ $r->{value} })[0];
}

sub NEXTKEY {
   print "NEXTKEY(@_)$/" if $debug >= 2;
   my $r = shift;
   each %{ $r->{value} };
}

sub SCALAR {
   print "EXISTS(@_)$/" if $debug >= 2;
   scalar %{shift()->{value}};
}




42;
