package threads::emulate::master::Array;

use strict;
use warnings;

our $debug = 0;

sub new {
    pop(@_);
    print "new(@_)$/" if $debug >= 2;
    my $self = bless { value => [], "lock" => -1 }, shift;
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
    my $self = shift;
    my $thr  = shift;
    my $ret  = 0;
    if ( $self->{"lock"} == -1 or $self->{"lock"} == $thr ) {
        $self->{"lock"} = $thr;
        $ret = 1;
    }
    $ret;
}

sub UNLOCK {
    pop(@_);
    my $self = shift;
    my $thr  = shift;
    my $ret;
    if ( $self->{"lock"} == $thr or $self->{"lock"} == -1 ) {
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
    pop(@_);
    print "FETCH(@_)$/" if $debug >= 2;
    my $self  = shift;
    my $index = shift;
    $self->{value}->[$index];
}

sub STORE {
    pop(@_);
    print "STORE(@_)$/" if $debug >= 2;
    print "lock()$/"    if $debug >= 1;
    my $self  = shift;
    my $index = shift;
    my $value = join ":", @_ if @_ > 1;
    $value    = shift unless @_ > 1;
    $self->{value}->[$index] = $value;
}

sub FETCHSIZE {
    pop(@_);
    print "FETCHSIZE()$/" if $debug >= 2;
    my $self = shift;
    scalar @{ $self->{value} };
}

sub STORESIZE {
    pop(@_);
    print "STORESIZE(@_)$/" if $debug >= 2;
    print "lock()$/"        if $debug >= 1;
    my $self = shift;
    my $size = shift;
    $#{ $self->{value} } = $size;
}

sub EXTEND {
    pop(@_);
    print "EXTEND(@_)$/" if $debug >= 2;
    my $self = shift;
    my $size = shift;
    $#{ $self->{value} } = $size - 1;
}

sub EXISTS {
    pop(@_);
    print "EXISTS(@_)$/" if $debug >= 2;
    exists shift()->{value}->[ shift() ];
}

sub DELETE {
    pop(@_);
    print "DELETE(@_)$/" if $debug >= 2;
    my $self  = shift;
    my $index = shift;
    delete $self->{objtypeonindex}->{$index} if exists $self->{objtypeonindex}->{$index};
    delete $self->{value}->[ $index ];
}

sub CLEAR {
    pop(@_);
    print "CLEAR(@_)$/" if $debug >= 2;
    my $self = shift;
    $self->{objtypeonindex} = [];
    $self->{value} = [];
}

sub PUSH {
    pop(@_);
    print "PUSH(@_)$/" if $debug >= 2;
    print "lock()$/"   if $debug >= 1;
    my $self = shift;
    #push @{ $self->{value} }, @_;
    for my $value (@_){
       $self->{value}->[$#{$self->{value}} + 1] = $value;
    }
}

sub POP {
    pop(@_);
    print "POP(@_)$/" if $debug >= 2;
    my $self = shift;
    my $index = $self->FETCHSIZE;
    delete $self->{objtypeonindex}->{$index} if exists $self->{objtypeonindex} and exists $self->{objtypeonindex}->{$index};
    pop @{ $self->{value} };
}

sub SHIFT {
    pop(@_);
    print "SHIFT(@_)$/" if $debug >= 2;
    my $self = shift;
    my %temp = map { $_ - 1 => $self->{objtypeonindex}->{$_} } keys %{ $self->{objtypeonindex} };
    $self->{objtypeonindex} = { %temp };
    shift @{ $self->{value} };
}

sub UNSHIFT {
    pop(@_);
    print "UNSHIFT(@_)$/" if $debug >= 2;
    print "lock()$/"      if $debug >= 1;
    unshift @{ shift()->{value} }, @_;
}

sub SPLICE {
    pop(@_);
    print "SPLICE(@_)$/" if $debug >= 2;
    my $self   = shift;
    my $offset = shift;
    my $length = shift;
    my @value  = @_;
    my $qtd = @value;
    my @temp;
    for my $key (keys %{$self->{objtypeonindex}}){
        $temp[$key] = $self->{objtypeonindex}->{$key};
    }
    splice @temp, $offset, $length, (0) x $qtd;
    $self->{objtypeonindex} = { map {$_ => $temp[$_]} grep {$temp[$_]} 0 .. $#temp };
    splice @{ $self->{value} }, $offset, $length, @value;
}

42;
