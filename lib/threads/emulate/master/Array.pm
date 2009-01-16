package threads::emulate::master::Array;

our $debug = 0;

sub new {
    print "new(@_)$/" if $debug >= 2;
    my $self = bless { value => [], "lock" => -1 }, shift;
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

    #print "LOCK(@_)$/";
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
    print "FETCH(@_)$/" if $debug >= 2;
    my $self  = shift;
    my $index = shift;
    $self->{value}->[$index];
}

sub STORE {
    print "STORE(@_)$/" if $debug >= 2;
    print "lock()$/"    if $debug >= 1;
    my $self  = shift;
    my $index = shift;
    my $value = shift;
    $self->{value}->[$index] = $value;
}

sub FETCHSIZE {
    print "FETCHSIZE(@_)$/" if $debug >= 2;
    my $r = shift;
    scalar @{ $r->{value} };
}

sub STORESIZE {
    print "STORESIZE(@_)$/" if $debug >= 2;
    print "lock()$/"        if $debug >= 1;
    @{ shift()->{value} } = (undef) x shift;
}

sub EXTEND {
    print "EXTEND(@_)$/" if $debug >= 2;
    my $r = shift;
    @{ $r->{value} } = (undef) x shift;
}

sub EXISTS {
    print "EXISTS(@_)$/" if $debug >= 2;
    exists shift()->{value}->[ shift() ];
}

sub DELETE {
    print "DELETE(@_)$/" if $debug >= 2;
    delete shift()->{value}->[ shift() ];
}

sub CLEAR {
    print "CLEAR(@_)$/" if $debug >= 2;
    @{ shift()->{value} } = ();
}

sub PUSH {
    print "PUSH(@_)$/" if $debug >= 2;
    print "lock()$/"   if $debug >= 1;
    push @{ shift()->{value} }, @_;
}

sub POP {
    print "POP(@_)$/" if $debug >= 2;
    pop @{ shift()->{value} };
}

sub SHIFT {
    print "SHIFT(@_)$/" if $debug >= 2;
    my $r = shift;
    shift @{ $r->{value} };
}

sub UNSHIFT {
    print "UNSHIFT(@_)$/" if $debug >= 2;
    print "lock()$/"      if $debug >= 1;
    unshift @{ shift()->{value} }, @_;
}

sub SPLICE {
    print "SPLICE(@_)$/" if $debug >= 2;
    my $self   = shift;
    my $offset = shift;
    my $length = shift;
    my @value  = @_;
    splice @{ $self->{value} }, $offset, $length, @value;
}

42;
