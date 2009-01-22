package threads::emulate::async;
use Time::HiRes qw/usleep/;
use Config;

=head1 NAME

threads::emulate::async - Create emulated thread (part of threads::emulate)

=head1 VERSION

Version 0.01

=cut

our $tid;
our %hash : Shared;
our %sub;

use strict;
use warnings;

=head1 SYNOPSIS

This module is part of hreads::emulate

    async {
        print "New thread...$/" for 1 .. 10
    }
    print "Old thread...$/" for 1 .. 10

=head1 FUNCTIONS

=head2 new

If you use the new() method, the thread will not run until you call
the run() method of the object. Diferent from using the async() function.
The async() function create the object, run the sub in a thread and return
the obj.

=cut

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

=head2 run

Run the new thread

=cut

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

=head2 kill

Sends a signal for the thread

=cut

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

=head2 get_pid

Gets the pid of the thread

=cut

sub get_pid {
   my $self = shift;
   $self->{pid}
}

#sub get_tid {
#    $main::_tid || 0;
#}

=head2 get_tid

Gets the thread id of the thread

=cut

sub get_tid {
    my $self = shift;
    $self->{tid};
}

=head2 join

Wait for the thread finish and return the return of the function

=cut

sub join {
    my $self = shift;
    $self->get_return( BLOCK => 1 );
}

=head2 get_return

If the thread is finished return the return of the sub, else return undef

=cut


sub get_return {
    my $self = shift;
    my %par  = @_;
    if(not exists $par{BLOCK} or not $par{BLOCK}) {
        return if not ref $self->{"return"} or not exists $self->{"return"}->[0];
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

=head1 AUTHOR

Fernando Correa de Oliveira, C<< <fco at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-threads-emulate-async at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=threads-emulate-async>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc threads::emulate::async


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=threads-emulate-async>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/threads-emulate-async>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/threads-emulate-async>

=item * Search CPAN

L<http://search.cpan.org/dist/threads-emulate/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2009 Fernando Correa de Oliveira, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

42;
