package threads::emulate::share::Array;
use threads::emulate::share;
use base threads::emulate::share;
use IO::Socket;

use strict;
use warnings;

our $debug = 0;

sub TIEARRAY {
    print "TIEARRAY()$/" if $debug >= 2;
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
    my $ret;
    if($self->get_obj_type_on_index($index) eq "1CODE1") {
        $ret = eval "sub $value";
    }else{
        $ret = $self->get_ref_or_value($value);
    }
    $ret
}

sub STORE {
    print "STORE(@_)$/" if $debug >= 2;
    print "lock()$/"    if $debug >= 1;
    my $self  = shift;
    my $index = shift;
    my $value = shift;
    $self->lock();
    if(ref $value eq "CODE") {
        $self->obj_type_on_index($index, "1CODE1");
        use B::Deparse;
        $value = B::Deparse->new->coderef2text($value);
    }else{
        $value =
          ref $value ? threads::emulate::share::share($value) : $value;
    }
    my $resp =
      $self->send( "STORE:"
          . ( $self->get_id )
          . ":$index:"
          . $self->value_or_id($value) );
    $self->unlock();
    $resp;
}

sub FETCHSIZE {
    print "FETCHSIZE()$/" if $debug >= 2;
    my $self = shift;
    $self->send( "FETCHSIZE:" . ( $self->get_id ) );
}

sub STORESIZE {
    print "STORESIZE(@_)$/" if $debug >= 2;
    print "lock()$/"        if $debug >= 1;
    my $self  = shift;
    my $count = shift;
    $self->lock();
    my $resp = $self->send( "STORESIZE:" . ( $self->get_id ) . ":$count" );
    $self->unlock();
    $resp;
}

sub EXTEND {
    print "EXTEND(@_)$/" if $debug >= 2;
    my $self  = shift;
    my $count = shift;
    $self->lock();
    my $resp = $self->send( "EXTEND:" . ( $self->get_id ) . ":$count" );
    $self->unlock();
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
    $self->lock();
    my $resp = $self->send( "DELETE:" . ( $self->get_id ) . ":$index" );
    $self->unlock();
    $resp;
}

sub CLEAR {
    print "CLEAR(@_)$/" if $debug >= 2;
    my $self = shift;
    $self->lock();
    my $resp = $self->send( "CLEAR:" . ( $self->get_id ) );
    $self->unlock();
    $resp;
}

sub PUSH {
    print "PUSH(@_)$/" if $debug >= 2;
    print "lock()$/"   if $debug >= 1;
    my $self  = shift;
    my @value = @_;
    my @value_;
    for my $value (@value){
        my $count++;
        if(ref $value eq "CODE") {
            $self->obj_type_on_index($self->FETCHSIZE + $count, "1CODE1");
            use B::Deparse;
            push @value_, B::Deparse->new->coderef2text($value);
        }else{
            if(ref $value){
                $value_[$#value + 1] = threads::emulate::share::share($value);
                #print threads::emulate::share::share($value), $/;
            }else{
                push @value_, $value;
            }
              #ref $value ? threads::emulate::share::share($value) : $value;
        }
    }
    $self->lock();
    my $resp =
      $self->send( "PUSH:" . ( $self->get_id ) . ":" . ( join ":", @value_ ) );
    $self->unlock();
    $resp;
}

sub POP {
    print "POP(@_)$/" if $debug >= 2;
    my $self = shift;
    $self->lock();
    my $resp = $self->send( "POP:" . ( $self->get_id ) );
    $self->unlock();
    $resp;
}

sub SHIFT {
    print "SHIFT(@_)$/" if $debug >= 2;
    my $self = shift;
    $self->lock();
    my $resp = $self->send( "SHIFT:" . ( $self->get_id ) );
    $self->unlock();
    $resp;
}

sub UNSHIFT {
    print "UNSHIFT(@_)$/" if $debug >= 2;
    print "lock()$/"      if $debug >= 1;
    my $self = shift;
    $self->lock();
    my @value = @_;
    my @value_;
    for my $value (@value){
        if(ref $value eq "CODE") {
            $self->obj_type_on_index(0, "1CODE1");
            use B::Deparse;
            push @value_, B::Deparse->new->coderef2text($value);
        }else{
            push @value_,
              ref $_ ? threads::emulate::share::share($value) : $value;
        }
    }
    my $resp = $self->send(
        "UNSHIFT:" . ( $self->get_id ) . ":" . ( join ":", @value_ ) );
    $self->unlock();
    $resp;
}

sub SPLICE {
    print "SPLICE(@_)$/" if $debug >= 2;
    my $self   = shift;
    my $offset = shift;
    my $length = shift;
    my @value  = @_;
    my @value_;
    for my $value(@value){
        if(ref $value eq "CODE") {
            use B::Deparse;
            push @value_, B::Deparse->new->coderef2text($value);
        }else{
            push @value_,
              ref $value ? threads::emulate::share::share($value) : $value;
        }
    }
    $self->lock();
    my $resp =
      $self->send( "SPLICE:"
          . ( $self->get_id ) . ":"
          . ( join ":", $offset, $length, @value_ ) );
    for my $ind (0 .. $#value){
        if(ref $value[$ind] eq "CODE") {
            $self->obj_type_on_index($offset + $ind, "1CODE1");
        }
    }
    $self->unlock();
    $resp;
}

42;
