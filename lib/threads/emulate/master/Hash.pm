package threads::emulate::master::Hash;
use threads::emulate::share;
use base threads::emulate::share;
use IO::Socket;

use strict;
use warnings;

our $debug = 0;

sub objtype {
    pop(@_);
    my $self = shift;
    $self->{objtype} = join ":", @_;
}

sub getobjtype {
    pop(@_);
    my $self = shift;
    $self->{objtype};
}

sub objtypeonindex {
    pop(@_);
    my $self  = shift;
    my $index = shift;
    $self->{objtypeonindex}->{$index} = shift;
}

sub getobjtypeonindex {
    pop(@_);
    my $self  = shift;
    my $index = shift;
    $self->{objtypeonindex}->{$index};
}

sub LOCK {
    pop(@_);
    print "TRYING TO LOCK(@_)$/" if $debug >= 2;
    my $self = shift;
    my $thr  = shift;
    my $ret  = 0;
    if ( $self->{"lock"} == -1 or $self->{"lock"} == $thr ) {
        $self->{"lock"} = $thr;
        $ret = 1;
        print "LOCK($self $thr)$/" if $debug >= 2;
    }
    $ret;
}

sub UNLOCK {
    pop(@_);
    print "UNLOCK(@_)$/" if $debug >= 2;
    my $self = shift;
    my $thr  = shift;
    my $ret;
    if ( $self->{"lock"} == $thr or $self->{"lock"} == -1 ) {
        $self->{"lock"} = -1;
        $ret = 1;
    }
    else {
        $ret = 0;
    }
    $ret;
}

sub prepare_key {
    pop(@_);
    my $self = shift;
    push @{ $self->{"keys"} }, keys %{ $self->{value} };
}

sub new {
    pop(@_);
    print "new(@_)$/" if $debug >= 2;
    my $self = bless { value => {}, "lock" => -1 }, shift;
    $self->{id} = shift;
    $self;
}

sub FETCH {
    pop(@_);
    print "FETCH(@_)$/" if $debug >= 2;
    my $self  = shift;
    my $index = shift;
    $self->{value}->{$index};
}

sub STORE {
    pop(@_);
    print "STORE(@_)$/" if $debug >= 2;
    print "lock()$/"    if $debug >= 1;
    my $self  = shift;
    my $index = shift;
    my $value = join ":", @_ if @_ > 1;
    $value    = shift unless @_ > 1;
    $self->{value}->{$index} = $value;
}

sub DELETE {
    pop(@_);
    print "DELETE(@_)$/" if $debug >= 2;
    delete shift()->{value}->{ shift() };
}

sub CLEAR {
    pop(@_);
    print "CLEAR(@_)$/" if $debug >= 2;
    %{ shift()->{value} } = ();
}

sub EXISTS {
    pop(@_);
    print "EXISTS(@_)$/" if $debug >= 2;
    exists shift()->{value}->{ shift() };
}

sub FIRSTKEY {
    pop(@_);
    print "FIRSTKEY(@_)$/" if $debug >= 2;
    my $r = shift;
    my $a = scalar keys %{ $r->{value} };
    ( each %{ $r->{value} } )[0];
}

sub NEXTKEY {
    pop(@_);
    print "NEXTKEY(@_)$/" if $debug >= 2;
    my $r = shift;
    each %{ $r->{value} };
}

sub SCALAR {
    pop(@_);
    print "EXISTS(@_)$/" if $debug >= 2;
    scalar %{ shift()->{value} };
}

42;
