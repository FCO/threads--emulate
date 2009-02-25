package threads::emulate::share::Scalar;
use threads::emulate::share;
use base threads::emulate::share;
use IO::Socket;
use Time::HiRes qw/usleep/;

use strict;
use warnings;

use threads::emulate noFork => 0;

our $debug = 0;

sub TIESCALAR {
    print "TIESCALAR()$/" if $debug >= 2;
    my $self     = bless {}, shift;
    my $id       = shift;
    my $value    = shift;
    my $sockpath = "/tmp/threads::emulate.sock";
    $self->connect($sockpath);
    if ( defined $id ) {
        $self->set_id($id);
    }
    else {
        $self->set_id( $self->send("CREATE:SCALAR") );
    }
    $self->lock();
    $self->STORE($value) if defined $value;
    $self->unlock();
    $self;
}

sub FETCH {
    print "FETCH(@_)$/" if $debug >= 2;
    my $self = shift;
    my $a = $self->lock();
    my $value = $self->send( "FETCH:" . $self->get_id );
    my $ret;
    if($self->get_obj_type eq "1CODE1") {
        $ret = eval "sub $value";
    }else{
        $ret   = $self->get_ref_or_value($value);
    }
    $self->unlock();
    $ret;
}

sub STORE {
    print "STORE(@_)$/" if $debug >= 2;
    print "lock()$/"    if $debug >= 1;
    my $self     = shift;
    my $value    = shift;
    $self->lock();
    $self->obj_type("");
    if(ref $value eq "CODE") {
        $self->obj_type("1CODE1");
        use B::Deparse;
        $value = B::Deparse->new->coderef2text($value);
    }else{
        $value =
          ref $value ? threads::emulate::share::share($value) : $value;
    }
#print "value: $value$/" if defined $value;
    $self->send(
        "STORE:" . ( $self->get_id ) . ":" . $self->value_or_id($value) );
    $self->unlock();
}

42;
