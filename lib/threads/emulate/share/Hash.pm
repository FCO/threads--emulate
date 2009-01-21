package threads::emulate::share::Hash;
use threads::emulate::share;
use base threads::emulate::share;
use IO::Socket;

use strict;
use warnings;

our $debug = 0;

sub prepare_key {
    my $self = shift;
    push @{ $self->{"keys"} }, keys %{ $self->{value} };
}

sub TIEHASH {
    print "TIEHASH(@_)$/" if $debug >= 2;
    print "lock()$/"      if $debug >= 1;
    my $self     = bless {}, shift;
    my $id       = shift;
    my %value    = @_;
    my $sockpath = "/tmp/threads::emulate.sock";
    $self->connect($sockpath);
    if ( defined $id ) {
        $self->set_id($id);
    }
    else {
        $self->set_id( $self->send("CREATE:HASH") );
    }
    if (%value) {
        my ( $k, $v );
        $self->STORE( $k, $v ) while ( $k, $v ) = each %value;
    }
    $self;
}

sub FETCH {
    print "FETCH(@_)$/" if $debug >= 2;
    my $self  = shift;
    my $index = shift;
    $self->lock();
    my $value = $self->send( "FETCH:" . ( $self->get_id ) . ":$index" );
    my $ret;
    my $txt = $self->get_obj_type_on_index($index);
    if(defined $txt and $txt eq "1CODE1") {
        $ret = eval "sub $value";
    }else{
        $ret = $self->get_ref_or_value($value);
    }
    $self->unlock();
    $ret;
}

sub STORE {
    print "STORE(@_)$/" if $debug >= 2;
    my $self  = shift;
    my $index = shift || return;
    my $value = shift || return;
    print "lock()$/" if $debug >= 1;
    $self->lock();
    if(ref $value eq "CODE") {
        $self->obj_type_on_index($index, "1CODE1");
        use B::Deparse;
        $value = B::Deparse->new->coderef2text($value);
    }else{
        $value =
          ref $value ? threads::emulate::share::share($value) : $value;
    }
    my $ret = $self->send( join ":", "STORE", ( $self->get_id ),
        $index, $self->value_or_id($value) );
    $self->unlock();
    $ret;
}

sub DELETE {
    print "DELETE(@_)$/" if $debug >= 2;
    my $self  = shift;
    my $index = shift;
    $self->lock();
    my $ret = $self->send( "DELETE:" . ( $self->get_id ) . ":$index" );
    $self->unlock();
    $ret;
}

sub CLEAR {
    print "CLEAR(@_)$/" if $debug >= 2;
    my $self = shift;
    $self->lock();
    my $ret = $self->send( "CLEAR:" . ( $self->get_id ) );
    $self->unlock();
    $ret;
}

sub EXISTS {
    print "EXISTS(@_)$/" if $debug >= 2;
    my $self  = shift;
    my $index = shift;
    $self->lock();
    my $ret = $self->send( "DELETE:" . ( $self->get_id ) . ":$index" );
    $self->unlock();
    $ret;
}

sub FIRSTKEY {
    print "FIRSTKEY(@_)$/" if $debug >= 2;
    my $self = shift;
    $self->lock();
    my $ret = $self->send( "FIRSTKEY:" . ( $self->get_id ) );
    $self->unlock();
    return unless $ret;
    $ret;
}

sub NEXTKEY {
    print "NEXTKEY(@_)$/" if $debug >= 2;
    my $self = shift;
    my $last = shift;
    $self->lock();
    my $ret = $self->send( "NEXTKEY:" . ( $self->get_id ) . ":$last" );
    $self->unlock();
    return unless $ret;
    $ret;
}

sub SCALAR {
    print "SCALAR(@_)$/" if $debug >= 2;
    my $self = shift;
    $self->lock();
    my $ret = $self->send( "SCALAR:" . ( $self->get_id ) );
    $self->unlock();
    $ret;
}

42;
