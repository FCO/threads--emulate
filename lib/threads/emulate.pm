package threads::emulate;

use 5.008008;

use IO::Socket;
use IO::Select;

=head1 NAME

threads::emulate - Create and use emulated threads (and share vars easyer)

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

use threads::emulate::share;

#use threads::emulate::master;
use threads::emulate::master::Scalar;
use threads::emulate::master::Array;
use threads::emulate::master::Hash;

use File::Temp;

use strict;
use warnings;

#$threads::emulate::VERSION = 0.1;

our ( $sockpath, $obj, %vars, %threads );
my $thread_id = 0;

$main::_tid = 0;

our $pid;

=head1 SYNOPSIS

This module was made because I don't like to have to "declare"
every "sub-level" of a shared var using C<threads::shared>.
This is NOT real threads. We use UNIX sockets to emulate shared
variables.


    use threads::emulate;
    
    my $shared_var : Shared;
    
    $shared_var = [1..5];                      # Congratulations! Now you have a shared array_ref!
    $shared_var->[5] = {jan => 1, feb => 2};   # Now inside of the array_ref there's a hash_ref!
    $shared_var->[5]->{obj} = Any::Class->new; # End now there's a object!
    
    lock \$shared_var;                         # Yes... You have to use ref...
    
    async{
        lock \$shared_var;
        $shared_var->[0] .= "K";
    };
    
    $shared_var->[0] = "O";
    unlock \$shared_var;

    sleep 1;

    print $shared_var->[0], $/;                # prints "OK" (I hope... :) )

=head1 EXPORT

This module exports 3 functions: async, lock and unlock.

=head1 FUNCTIONS

#=head2 _create
#
#Internal use.
#
=cut

sub _create {
    my $self = shift;
    my %par  = @_;
    our $sockpath = (File::Temp::tempfile(OPEN => 0, SUFFIX => ".sock"))[1]; #"/tmp/" . __PACKAGE__ . ".sock";
    unlink $sockpath;
    threads::emulate::share->set_path($sockpath);
    unless ( exists $par{noFork} and $par{noFork} ) {
        $pid = fork();
        _master() unless $pid;
    }
}

#=head2 get_obj
#
#Internal use.
#
#=cut

sub get_obj {
    our $obj;
}

=head2 async

This func is exported by default. It receives only one parameter, a sub_ref.
It returns a thread::emulate::async object.

=cut

our @lock;
our @pids;
{
    my $tid;

    sub async (&) {
        my $sub   = shift;
        my $async = threads::emulate::async->new($sub);
        push @pids, $async->get_pid;
        $thread_id = $async->get_tid;
        $async->run;
        $thread_id = 0;
        $async;
    }
}

=head2 lock

This func is exported by default. It receives only one parameter, a reference for a shared var.

=cut

sub lock {
#print "lock(@_, $thread_id)$/";
    my $var = shift;
    my $ret = obj_exec( $var, "lock", $thread_id );
    push @lock, $var;
    return $ret;
}

=head2 unlock

This func is exported by default. It receives only one parameter, a reference for a shared var.

=cut

sub unlock {
#print "unlock(@_, $thread_id)$/";
    my $var = shift;
    my $ret = obj_exec( $var, "unlock", $thread_id );
    @lock = grep { $_ ne $var } @lock;
    $ret
}

#=head2 obj_exec
#
#Internal use.
#
#=cut

sub obj_exec {
    my $value  = shift;
    my $method = shift;
    my @pars   = @_;
    my $ret;
    if ( my $ref = ref $value ) {
        my $obj;
        if ( $ref eq "SCALAR" ) {
            $ret = $obj->$method(@pars) if $obj = tied $$value;
        }
        elsif ( $ref eq "ARRAY" ) {
            $ret = $obj->$method(@pars) if $obj = tied @$value;
        }
        elsif ( $ref eq "HASH" ) {
            $ret = $obj->$method(@pars) if $obj = tied %$value;
        }
        else {
            return;
        }
    }
    $ret;
}

#=head2 _master
#
#Internal use.
#
#=cut

sub _master {
    local $SIG{INT} = 'IGNORE';
    $SIG{INT} = sub { exit(0) };
    $thread_id = "master";
    my @cmds = qw/
      FETCH          STORE             FETCHSIZE STORESIZE
      EXTEND         EXISTS            DELETE    CLEAR
      PUSH           POP               SHIFT     UNSHIFT
      SPLICE         FIRSTKEY          NEXTKEY   SCALAR
      LOCK           UNLOCK            objtype   getobjtype
      objtypeonindex getobjtypeonindex
      /;

    my $commands = join "|", @cmds;

    my $id;
    local $| = 1;
    my $sock = IO::Socket::UNIX->new(
        Type   => SOCK_STREAM,
        Local  => $sockpath,
        Listen => 1,
        Reuse  => 1
    ) || die "ERRO(1): $!$/";
    $sock->autoflush(1);
    my $select = IO::Select->new($sock);
  SOCK: while ( my @socks = $select->can_read ) {
      FOR: for my $new_sock (@socks) {
            if ( $new_sock == $sock ) {
                $select->add( $sock->accept );
            }
            else {
                my $msg;
                {
                    $new_sock->autoflush(1);
                    local $/ = "\r\n";
                    $msg = scalar <$new_sock>;
                    chomp($msg) if defined $msg;
                    $msg =~ s/\r\n?$// if defined $msg;
                }
                last SOCK if defined $msg and $msg eq "EXIT";
                next unless defined $msg;
                my $msg_id = $1 if $msg =~ s/^(\d+)://;
                unless($msg_id) {
                   master_send( $new_sock, "ERROR");
                   next FOR;
                }
                if ( $msg =~ /^CREATE:(SCALAR|ARRAY|HASH)$/ ) {
                    my $idcomplete = "shared$1(" . ( $id++ ) . ")";
                    my $type =
                      "threads::emulate::master::" . ( ucfirst( lc $1 ) );
                    $vars{$idcomplete} = $type->new($idcomplete);
                    master_send( $new_sock, "$msg_id:$idcomplete" );
                    next FOR;
                }
                elsif ( $msg =~
                    /^($commands):(shared(?:SCALAR|ARRAY|HASH)\(\d+\)):?(.*)$/ms )
                {
                    my $resp = $vars{$2}->$1( split /:/, "$3:$/" );
                    my $send = "$msg_id:" . ($resp ? $resp : "");
                    master_send( $new_sock, $send );
                }
                else {
                    if (defined $msg and $msg) {
                        warn "WARN: $msg$/";
                        master_send( $new_sock, "$msg_id:$msg" );
                    }
                }
            }
        }
    }
    $_->close for $select->handles;
    exit(0);
}

#=head2 master_send
#
#Internal use.
#
#=cut

sub master_send {
    my $sock = shift;
    my $msg  = shift;
    local $\ = "\r\n";
    local $, = " ";
    if ( defined $msg ) {
        print {$sock} $msg;
    }
    else {
        print {$sock} "";
    }
}

use Time::HiRes qw/usleep/;

#=head2 import
#
#Internal use.
#
#=cut

sub import {
    my $class = shift;
    my $self = bless {}, $class;
    $self->_create;
    my $count;
    our $obj = $self;
    require threads::emulate::async;

    no strict 'refs';
    my $caller = scalar caller;
    *{$caller . "::async"} = \&async;
    *{$caller . "::lock"} = \&lock;
    *{$caller . "::unlock"} = \&unlock;
}

#=head2 send
#
#Internal use.
#
#=cut

sub send {
    my $self = shift;
    my $msg  = shift;
    my $sock = shift;
    {
        local $\ = "\r\n";
        #local $, = " ";
        $sock ||= $self->{sock};
        print {$sock} $msg;
    }
    my $resp = $self->read($sock);
    $resp;
}

#=head2 read
#
#Internal use.
#
#=cut

sub read {
    my $self = shift;
    my $sock = shift;
    my $resp;
    {
        local $/ = "\r\n";
        $sock ||= $self->{sock};
        $resp = scalar <$sock>;
        chomp( $resp ) if defined $resp;
    }
    $resp;
}

#=head2 _exit
#
#Internal use.
#
#=cut

sub _exit {
    my $self = shift;
    for(@pids) {
       kill 9 => $_ if /^\d+$/ and kill 0 => $_;
    }
    $self->{sock} =
      IO::Socket::UNIX->new( Type => SOCK_STREAM, Peer => $sockpath );
    $self->{sock}->autoflush(1);
    $self->send("EXIT");
    1;
}

#=head2 DESTROY
#
#DESTROY
#
#=cut

sub DESTROY {
    my $self = shift;
    $self->_exit if $thread_id eq "0";
    wait if $thread_id eq "0";
    unlink $sockpath if $thread_id eq "0";
}

=head1 AUTHOR

Fernando Correa de Oliveira, C<< <fco at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-threads-emulate at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=threads-emulate>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc threads::emulate


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=threads-emulate>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/threads-emulate>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/threads-emulate>

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
