package threads::emulate::async;
use Time::HiRes qw/usleep/;
use Config;
our $tid;
our %hash : shared;
our %sub;

use strict;
use warnings;

sub new {
    my $class = shift;
    my $sub   = shift;
    $hash{$tid} = { tid => ++$tid, "return" => [], pid => undef };
    my $self = bless $hash{$tid}, $class;
    $self->{sig} = {};
    my $count;
    %{ $self->{sig} } = map { $_ => $count++ } split " ", $Config{sig_name};
    $sub{$tid} = $sub;
    $self;
}

sub run {
    my $self = shift;
    my @pars = @_;
    my $pid  = fork();
    return if $pid;
    $main::_tid       = $tid;
    $self->{pid}      = $$;
    $self->{"return"} = [];
    push @{ $self->{"return"} }, $sub{ $self->{tid} }->(@pars)
      if ref $self->{"return"};
    main::unlock($_) for @threads::emulate::lock;
    kill 9 => $$;
    die;
    exit(0);
    print "Não saí!!!$/";
}

sub kill {
    my $self   = shift;
    my $signal = shift;
    my $sig;
    if ( $signal =~ /^\d+$/ ) {
        $sig = $signal;
    }
    elsif ( exists $self->{sig}->{$signal} ) {
        $sig = $self->{sig}->{$signal};
    }
    else {
        die "Signal \"$signal\" unknow$/";
    }
    kill $sig => $self->{pid};
}

sub main::get_tid {
    $main::_tid;
}

sub get_tid {
    my $self = shift;
    $self->{tid};
}

sub join {
    my $self = shift;
    $self->get_return( BLOCK => 1 );
}

sub get_return {
    my $self = shift;
    my %par  = @_;
    return @{ $self->{"return"} } if not exists $par{BLOCK} or not $par{BLOCK};

    #unless($filho) {
    until ( @{ $self->{"return"} } ) {
        usleep 50;
    }

    #}
    @{ $self->{"return"} };
}

42;
