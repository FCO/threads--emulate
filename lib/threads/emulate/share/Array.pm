package threads::emulate::share::Array;
use threads::emulate::share;
use base threads::emulate::share;
use IO::Socket;

our $debug = 0;

sub TIEARRAY {
    print "TIEARRAY(@_)$/" if $debug >= 2;
    my $self     = bless {}, shift;
    my $id       = shift;
    my @value    = @_;
    my $sockpath = "/tmp/threads::emulate.sock";
    $self->connect($sockpath);
    if ( defined $id ) {
        $self->set_id($id);
    }
    else {
        $self->set_id( $self->send("CREATE:ARRAY") );
    }
    $self->PUSH(@value) if @value;
    $self;
}

sub FETCH {
    print "FETCH(@_)$/" if $debug >= 2;
    my $self  = shift;
    my $index = shift;
    my $value = $self->send( "FETCH:" . ( $self->get_id ) . ":$index" );
    $self->get_ref_or_value($value);
}

sub STORE {
    print "STORE(@_)$/" if $debug >= 2;
    print "lock()$/"    if $debug >= 1;
    my $self  = shift;
    my $index = shift;
    my $value = shift;
    $value =
      ref $value ? threads::emulate::share::easyshare_attr($value) : $value;
    $self->lock(&main::get_tid);
    my $resp =
      $self->send( "STORE:"
          . ( $self->get_id )
          . ":$index:"
          . $self->value_or_id($value) );
    $self->unlock(&main::get_tid);
    $resp;
}

sub FETCHSIZE {
    print "FETCHSIZE(@_)$/" if $debug >= 2;
    my $self = shift;
    $self->send( "FETCHSIZE:" . ( $self->get_id ) );
}

sub STORESIZE {
    print "STORESIZE(@_)$/" if $debug >= 2;
    print "lock()$/"        if $debug >= 1;
    my $self  = shift;
    my $count = shift;
    $self->lock(&main::get_tid);
    my $resp = $self->send( "STORESIZE:" . ( $self->get_id ) . ":$count" );
    $self->unlock(&main::get_tid);
    $resp;
}

sub EXTEND {
    print "EXTEND(@_)$/" if $debug >= 2;
    my $self  = shift;
    my $count = shift;
    $self->lock(&main::get_tid);
    my $resp = $self->send( "EXTEND:" . ( $self->get_id ) . ":$count" );
    $self->unlock(&main::get_tid);
    $resp;
}

sub EXISTS {
    print "EXISTS(@_)$/" if $debug >= 2;
    my $self  = shift;
    my $index = shift;
    my $resp  = $self->send( "EXISTS:" . ( $self->get_id ) . ":$index" );
}

sub DELETE {
    print "DELETE(@_)$/" if $debug >= 2;
    my $self  = shift;
    my $index = shift;
    $self->lock(&main::get_tid);
    my $resp = $self->send( "DELETE:" . ( $self->get_id ) . ":$index" );
    $self->unlock(&main::get_tid);
    $resp;
}

sub CLEAR {
    print "CLEAR(@_)$/" if $debug >= 2;
    my $self = shift;
    $self->lock(&main::get_tid);
    my $resp = $self->send( "CLEAR:" . ( $self->get_id ) );
    $self->unlock(&main::get_tid);
    $resp;
}

sub PUSH {
    print "PUSH(@_)$/" if $debug >= 2;
    print "lock()$/"   if $debug >= 1;
    my $self  = shift;
    my @value = @_;
    my @value_;
    push @value_,
      ref $_
      ? $self->value_or_id( threads::emulate::share::easyshare_attr($_) )
      : $_
      for @value;
    $self->lock(&main::get_tid);
    my $resp =
      $self->send( "PUSH:" . ( $self->get_id ) . ":" . ( join ":", @value_ ) );
    $self->unlock(&main::get_tid);
    $resp;
}

sub POP {
    print "POP(@_)$/" if $debug >= 2;
    my $self = shift;
    $self->lock(&main::get_tid);
    my $resp = $self->send( "POP:" . ( $self->get_id ) );
    $self->unlock(&main::get_tid);
    $resp;
}

sub SHIFT {
    print "SHIFT(@_)$/" if $debug >= 2;
    my $self = shift;
    $self->lock(&main::get_tid);
    my $resp = $self->send( "SHIFT:" . ( $self->get_id ) );
    $self->unlock(&main::get_tid);
    $resp;
}

sub UNSHIFT {
    print "UNSHIFT(@_)$/" if $debug >= 2;
    print "lock()$/"      if $debug >= 1;
    my $self = shift;
    $self->lock(&main::get_tid);
    my @value = @_;
    push @value_,
      ref $_
      ? $self->value_or_id( threads::emulate::share::easyshare_attr($_) )
      : $_
      for @value;
    my $resp = $self->send(
        "UNSHIFT:" . ( $self->get_id ) . ":" . ( join ":", @value_ ) );
    $self->unlock(&main::get_tid);
    $resp;
}

sub SPLICE {
    print "SPLICE(@_)$/" if $debug >= 2;
    my $self   = shift;
    my $offset = shift;
    my $length = shift;
    my @value  = @_;
    my @value_ = ref $_ ? threads::emulate::share::easyshare_attr($_) : $_
      for @value;
    $self->lock(&main::get_tid);
    my $resp =
      $self->send( "SPLICE:"
          . ( $self->get_id ) . ":"
          . ( join ":", $offset, $length, @value_ ) );
    $self->unlock(&main::get_tid);
    $resp;
}

42;
