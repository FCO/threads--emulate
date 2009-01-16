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
    print scalar caller, " TIESCALAR(@_)$/" if $debug >= 2;
    my $self     = bless {}, shift;
    my $id       = shift;
    my $value    = shift;
    my $sockpath = "/tmp/threads::emulate.sock";
    return unless -S $sockpath;
    $self->connect($sockpath);
    if ( defined $id ) {
        $self->set_id($id);
    }
    else {
        $self->set_id( $self->send("CREATE:SCALAR") );
    }
    $self->lock(&main::get_tid);
    $self->STORE($value) if defined $value;
    $self->unlock(&main::get_tid);
    $self;
}

sub FETCH {
    print "FETCH(@_)$/" if $debug >= 2;
    my $self = shift;
    my $name = $self->{name};
    $self->lock(&main::get_tid);
    my $value = $self->send( "FETCH:" . $self->get_id );
    $self->unlock(&main::get_tid);
    $self->get_ref_or_value($value);
}

sub STORE {
    print "STORE(@_)$/" if $debug >= 2;
    print "lock()$/"    if $debug >= 1;
    my $self = shift;
    $self->lock(&main::get_tid);
    my $value = shift;
    $value =
      ref $value ? threads::emulate::share::easyshare_attr($value) : $value;
    $self->send(
        "STORE:" . ( $self->get_id ) . ":" . $self->value_or_id($value) );
    $self->unlock(&main::get_tid);
}

42;
