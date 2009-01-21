package threads::emulate::async;
use Time::HiRes qw/usleep/;
use Config;
our $tid;
our %hash : Shared;
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
    $self->{returned} = [];
    @threads::emulate::lock = ();
    threads::emulate::lock($self->{returned});
    no strict 'refs';
    my @ret = $sub{ $self->{tid} }->(@pars) if @pars;
    @ret = $sub{ $self->{tid} }->() unless @pars;
    use strict;
    $self->{"return"} = [@ret]
      if @ret or ref $self->{"return"} eq "ARRAY";
    threads::emulate::unlock($self->{returned});
    threads::emulate::unlock($_) for @threads::emulate::lock;
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
    kill $1 => $self->{pid} if $sig =~ /^(\d+)$/ and $sig >= 0;
}

sub get_pid {
   my $self = shift;
   $self->{pid}
}

#sub get_tid {
#    $main::_tid || 0;
#}

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
    if(not exists $par{BLOCK} or not $par{BLOCK}) {
        return unless ref $self->{"return"};
        return @{ $self->{"return"} } if wantarray;
        return $self->{"return"}->[0] unless wantarray;
    }
    # until ( exists $self->{returned} and $self->{returned} ) {
    #     usleep 50;
    # }
    threads::emulate::lock($self->{returned});
    no strict 'refs';
    if(wantarray) {
        threads::emulate::unlock($self->{returned});
        return @{ $self->{"return"} } if ref $self->{"return"};
    }else{
        threads::emulate::unlock($self->{returned});
        return $self->{"return"}->[0] if ref $self->{"return"};
    }
    use strict;
}

42;
