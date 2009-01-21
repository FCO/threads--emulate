package threads::emulate::master::Scalar;

use strict;
use warnings;

our $debug = 0;

sub new {
    pop(@_);
    print "new(@_)$/" if $debug >= 2;
    my $self = bless { value => "", "lock" => -1 }, shift;
    $self->{id} = shift;
    $self;
}

sub objtype {
    pop(@_);
    my $self = shift;
    $self->{objtype} = shift;
}

sub getobjtype {
    pop(@_);
    my $self = shift;
    $self->{objtype};
}

sub LOCK {
    pop(@_);
    print "MASTER:LOCK(@_)$/" if $debug >= 2;
    my $self = shift;
    my $thrT = shift;
    my $thr = $1 if $thrT =~ /^(\d+)$/;
    return 0 unless defined $thr;
    my $ret  = 0;
    if ( $self->{"lock"} == -1 or $self->{"lock"} == $thr ) {
        print "LOCKED($thr)$/" if $debug >= 2;
        $self->{"lock"} = "$thr";
        $ret = 1;
    }
    $ret;
}

sub UNLOCK {
    pop(@_);
    print "MASTER:UNLOCK(@_)$/" if $debug >= 3;
    my $self = shift;
    my $thrT = shift;
    my $thr = $1 if $thrT =~ /^(\d+)$/;
    return 0 unless defined $thr;
    my $ret;
    if ( $self->{"lock"} == $thr or $self->{"lock"} == -1 ) {
        $self->{"lock"} = -1;
        $ret = 1;
    }
    else {
        warn "Thread $thr trying to unlock a var locked by another thread $self->{lock}...$/";
        $ret = 0;
    }
    $ret;
}

sub FETCH {
    pop(@_);
    print "MASTER:FETCH(@_)$/" if $debug >= 2;
    my $self = shift;
    #return unless exists $self->{value};
    $self->{value};
}

sub STORE {
    pop(@_);
    print "MASTER:STORE(@_)$/" if $debug >= 2;
    print "lock()$/"           if $debug >= 1;
    my $self  = shift;
    my $value = join ":", @_ if @_ > 1;
    $value = shift unless @_ > 1;
    $self->{value} = $value;
}

42;
