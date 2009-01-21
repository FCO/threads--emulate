package threads::emulate::master;
use threads::emulate::master::Scalar;
use threads::emulate::master::Array;
use threads::emulate::master::Hash;

use strict;
use warnings;

sub _master {
    local $SIG{INT} = 'IGNORE';
    $SIG{INT} = sub { exit(0) };
    $thread_id = "master";
    my @cmds = qw/
      FETCH  STORE    FETCHSIZE STORESIZE
      EXTEND EXISTS   DELETE    CLEAR
      PUSH   POP      SHIFT     UNSHIFT
      SPLICE FIRSTKEY NEXTKEY   SCALAR
      LOCK   UNLOCK   objtype   getobjtype
      /;

    my $commands = join "|", @cmds;

    my $id;
    local $| = 1;
    my $sock = IO::Socket::UNIX->new(
        Type   => SOCK_STREAM,
        Local  => $sockpath,
        Listen => 1,
        Reuse  => 1,
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
                    local $/ = "\r\n";
                    $msg = scalar <$new_sock>;
                }
                $msg =~ s/\r\n$// if defined $msg;
                last SOCK if defined $msg and $msg eq "EXIT";
                next unless defined $msg;
                if ( $msg =~ /^CREATE:(SCALAR|ARRAY|HASH)$/ ) {
                    my $idcomplete = "fer$1(" . ( $id++ ) . ")";
                    my $type =
                      "threads::emulate::master::" . ( ucfirst( lc $1 ) );
                    $vars{$idcomplete} = $type->new($idcomplete);
                    master_send( $new_sock, $idcomplete );
                    next FOR;
                }
                elsif ( $msg =~
                    /^($commands):(fer(?:SCALAR|ARRAY|HASH)\(\d+\)):?(.*)$/ )
                {
                    my $resp = $vars{$2}->$1( split /:/, $3 );
                    master_send( $new_sock, $resp );
                }
            }
        }
    }
    $_->close for $select->handles;
    print "SAINDO!$/";
    exit(0);
}

sub master_send {
    my $sock = shift;
    my $msg  = shift;
    local $\ = "\r\n";
    if ( defined $msg ) {
        print {$sock} $msg;
    }
    else {
        print {$sock} "";
    }
}

42;
