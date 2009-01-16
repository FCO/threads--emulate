package threads::emulate::master::Scalar;

our $debug = 0;

sub new {
    print "new(@_)$/" if $debug >= 2;
    my $self = bless { value => "", "lock" => -1 }, shift;
    $self->{id} = shift;
    $self;
}

sub objtype {
    my $self = shift;
    $self->{objtype} = shift;
}

sub getobjtype {
    my $self = shift;
    $self->{objtype};
}

sub LOCK {
    my $self = shift;
    my $thr  = shift;
    my $ret  = 0;
    if ( $self->{"lock"} == -1 ) {
        $self->{"lock"} = $thr;
        $ret = 1;
    }
    $ret;
}

sub UNLOCK {
    my $self = shift;
    my $thr  = shift;
    my $ret;
    if ( $self->{"lock"} == $thr ) {
        $self->{"lock"} = -1;
        $ret = 1;
    }
    else {
        warn "Var locked by another thread...$/";
        $ret = 0;
    }
    $ret;
}

sub FETCH {
    print "MASTER:FETCH(@_)$/" if $debug >= 2;
    my $self = shift;
    $self->{value};
}

sub STORE {
    print "MASTER:STORE(@_)$/" if $debug >= 2;
    print "lock()$/"           if $debug >= 1;
    my $self  = shift();
    my $value = shift;
    $self->{value} = $value;
}

42;
