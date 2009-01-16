package threads::emulate::share::Hash;
use threads::emulate::share;
use base threads::emulate::share;
use IO::Socket;

our $debug = 0;

sub prepare_key {
   my $self = shift;
   push @{ $self->{"keys"} }, keys %{ $self->{value} };
}

sub TIEHASH {
   print "TIEHASH(@_)$/" if $debug >= 2;
   print "lock()$/" if $debug >= 1;
   my $self  = bless {}, shift;
   my $id    = shift;
   my %value = @_;
   my $sockpath = "/tmp/threads::emulate.sock";
   $self->connect($sockpath);
   if(defined $id) {
      $self->set_id($id);
   }else{
      $self->set_id($self->send("CREATE:HASH"));
   }
   if(%value){
      my($k, $v);
      $self->STORE($k, $v) while ($k, $v) = each %value;
   }
   $self
}

sub FETCH {
   print "FETCH(@_)$/" if $debug >= 2;
   my $self  = shift;
   my $index = shift;
   my $value = $self->send("FETCH:" . ($self->get_id) . ":$index");
   $self->get_ref_or_value($value);
}

sub STORE {
   print "STORE(@_)$/" if $debug >= 2;
   my $self  = shift();
   my $index = shift;
   my $value = shift;
   print "lock()$/" if $debug >= 1;
   $value = ref $value ? threads::emulate::share::easyshare_attr($value) : $value;
   #$self->send(join ":", "STORE", ($self->get_id), $index, $value);
   $self->lock(&main::get_tid);
   $self->send(join ":", "STORE", ($self->get_id), $index, $self->value_or_id($value));
   $self->unlock(&main::get_tid);
}

sub DELETE {
   print "DELETE(@_)$/" if $debug >= 2;
   my $self  = shift;
   my $index = shift;
   $self->lock(&main::get_tid);
   $self->send("DELETE:" . ($self->get_id) . ":$index");
   $self->unlock(&main::get_tid);
   $ret
}

sub CLEAR {
   print "CLEAR(@_)$/" if $debug >= 2;
   my $self = shift;
   $self->lock(&main::get_tid);
   $self->send("CLEAR:" . ($self->get_id));
   $self->unlock(&main::get_tid);
}

sub EXISTS {
   print "EXISTS(@_)$/" if $debug >= 2;
   my $self  = shift;
   my $index = shift;
   $self->send("DELETE:" . ($self->get_id) . ":$index");
}

sub FIRSTKEY {
   print "FIRSTKEY(@_)$/" if $debug >= 2;
   my $self = shift;
   my $ret = $self->send("FIRSTKEY:" . ($self->get_id));
   return unless $ret;
   $ret
}

sub NEXTKEY {
   print "NEXTKEY(@_)$/" if $debug >= 2;
   my $self = shift;
   my $last = shift;
   my $ret = $self->send("NEXTKEY:" . ($self->get_id) . ":$last");
   return unless $ret;
   $ret
}

sub SCALAR {
   print "SCALAR(@_)$/" if $debug >= 2;
   my $self = shift;
   $self->send("SCALAR:" . ($self->get_id) . ":$index");
}




42;
