package threads::emulate;
use IO::Socket;
use IO::Select;

use threads::emulate::share;
use threads::emulate::master::Scalar;
use threads::emulate::master::Array;
use threads::emulate::master::Hash;

use strict;
use warnings;

our($sockpath, $obj, %vars, %threads);
$main::tid = 0;

my $thread_id = 0;

$main::_tid = 0;

our $pid;

sub _create {
   my $self = shift;
   my %par = @_;
   our $sockpath = "/tmp/" . __PACKAGE__ . ".sock";
   unlink $sockpath;
   unless(exists $par{noFork} and $par{noFork}) {
      $pid = fork();
      _master() unless $pid;
   }
}

sub get_obj {
   our $obj;
}

our @lock;
{
my $tid;
sub main::async (&){
   my $sub = shift;
   my $run = shift;
   my $async = threads::emulate::async->new($sub);
   $thread_id = $async->get_tid;
   @{ $async->{"return"} } = ();
   push @{ $async->{"return"} }, $async->run;
   $async;
}
}

sub main::lock {
   my $var = shift;
   obj_exec($var, "lock", $thread_id);
   push @lock, $var;
}

sub main::unlock {
   my $var = shift;
   obj_exec($var, "unlock", $thread_id);
   @lock = grep {$_ ne $var} @lock;
}

sub obj_exec {
   my $value  = shift;
   my $method = shift;
   my @pars   = @_;
   my $ret;
   if(my $ref = ref $value) {
      my $obj;
      if($ref eq "SCALAR"){
         $ret = $obj->$method(@pars) if $obj = tied $$value;
      }
      elsif($ref eq "ARRAY"){
         $ret = $obj->$method(@pars) if $obj = tied @$value;
      }
      elsif($ref eq "HASH"){
         $ret = $obj->$method(@pars) if $obj = tied %$value;
      }
      else{
         return;
      }
   }else{
      return;
   }
   $ret;
}


sub _master {
   local $SIG{INT} = 'IGNORE';
   $SIG{INT} = sub{exit(0)};
   $thread_id = "master";
   my @cmds = qw/
                 FETCH  STORE    FETCHSIZE STORESIZE
                 EXTEND EXISTS   DELETE    CLEAR
                 PUSH   POP      SHIFT     UNSHIFT
                 SPLICE FIRSTKEY NEXTKEY   SCALAR
                 LOCK   UNLOCK   objtype   getobjtype
                /;
   
   my $commands = join "|", @cmds;

   my $id;
   local $|=1;
   my $sock = IO::Socket::UNIX->new(Type => SOCK_STREAM, Local => $sockpath, Listen => 1, Reuse => 1) || die "ERRO(1): $!$/";
   $sock->autoflush(1);
   my $select = IO::Select->new($sock);
   SOCK: while(my @socks = $select->can_read){
      FOR: for my $new_sock(@socks) {
         if($new_sock == $sock){
            $select->add($sock->accept);
         }else{
            my $msg;
            {
               local $/ = "\r\n";
               $msg = scalar <$new_sock>;
            }
            $msg =~ s/\r\n$// if defined $msg;
            last SOCK if defined $msg and $msg eq "EXIT";
            next unless defined $msg;
            if($msg =~ /^CREATE:(SCALAR|ARRAY|HASH)$/){
               my $idcomplete = "fer$1(" . ($id++) . ")";
               my $type = "threads::emulate::master::" . (ucfirst(lc $1));
               $vars{$idcomplete} = $type->new($idcomplete);
               master_send($new_sock, $idcomplete);
               next FOR;
            }elsif($msg =~ /^($commands):(fer(?:SCALAR|ARRAY|HASH)\(\d+\)):?(.*)$/) {
               my $resp = $vars{$2}->$1(split /:/, $3);
               master_send($new_sock, $resp);
            }
         }
      }
   }
   $_->close for $select->handles;
   print "SAINDO!$/";
   exit(0);
}

sub master_send {
   my $sock = shift;
   my $msg  = shift;
   local $\ = "\r\n";
   if(defined $msg){
      print {$sock} $msg;
   }else{
      print {$sock} "";
   }
}

use Time::HiRes qw/usleep/;

sub import {
   my $class = shift;
   my $self = bless {}, $class;
   $self->_create;
   my $count;
   our $obj = $self;
   require threads::emulate::async;
   $self
}

sub send {
   my $self = shift;
   my $msg = shift;
   {
      local $\ = "\r\n";
      my $sock = $self->{sock};
      print { $sock } $msg;
   }
   my $resp = $self->read;
   $resp;
}

sub read {
   my $self = shift;
   my $resp;
   {
      local $/ = "\r\n";
      my $sock = $self->{sock};
      chomp($resp = scalar <$sock>);
   }
   $resp
}

sub _exit {
   my $self = shift || {};
   return if $thread_id ne "0";
   $thread_id = "done";
   my $count;
   until(-S $sockpath) {
      ++$count < 600 || die "...";
      usleep 50;
   }
   $self->{sock} = IO::Socket::UNIX->new(Type => SOCK_STREAM, Peer => $sockpath);
   $self->{sock}->autoflush(1);
   $count = 0;
   for(keys %threads) {
      $count++ if kill 0 => $threads{$_};
      #kill 9 => $threads{$_};
   }
   #printf {STDERR} "Program finished with %s thread%s running.$/", $count, ($count>1?"s":"") if $count;
   $self->send("EXIT");
}

sub DESTROY {
   my $self = shift;
   $self->_exit;# if $thread_id eq "0";
}

END {
   kill 2 => $pid;
   _exit();
   #for(keys %threads) {
   #   kill 9 => $threads{$_};
   #}
   #kill 9 => -$$;
   wait;
   unlink $sockpath if $thread_id eq "master";
}

42;
