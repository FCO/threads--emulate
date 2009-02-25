package threads::emulate::share;

use Attribute::Handlers;
use Time::HiRes qw/usleep/;
use threads::emulate::share::Scalar;
use threads::emulate::share::Array;
use threads::emulate::share::Hash;
use IO::Socket;

use strict;
use warnings;

our $debug = 0;

our %vars;

our $send_obj = 0;

our $PATH;

sub set_path {
   shift;
   $PATH = shift;
}

sub connect {
    my $self     = shift;
    my $sockpath = $PATH || shift;
    my $count;
    until ( $self->{sock} =
          IO::Socket::UNIX->new( Type => SOCK_STREAM, Peer => $sockpath ) )
    {
        ++$count < 60 || die scalar caller, " Erro(connect): $!$/";
        usleep 5;
    }
    $self->{sock}->autoflush(1);

}

sub lock {
    my $self = shift;
    my $tid = shift || $main::_tid;
    $self->{"times"}->{$tid} ||= 0;
    print " - trying to lock $tid ($self->{times})$/" if $debug >= 2;
    $tid = 0 if $tid eq "main";
    my $resp = 0;
    if($self->{"times"}->{$tid} == 0) {
        until($resp == 1) {
            my $temp = $self->send( "LOCK:" . ( join ":", $self->get_id(), $tid ) );
            $resp = $1 if defined $temp and $temp =~ /^(\d)$/;
            last if $resp;
            usleep 5;
        }
    }
    $self->{"times"}->{$tid}++;
    return $resp;
}

sub unlock {
    my $self = shift;
    my $tid = shift || $main::_tid;
    print " - trying to unlock $tid ($self->{times})$/" if $debug >= 2;
    $self->{"times"}->{$tid}--;
    my $resp = 0;
    if($self->{"times"}->{$tid} == 0) {
        #until($resp == 1) {
            usleep 500;
            my $temp = $self->send( "UNLOCK:" . ( join ":", $self->get_id, $tid ) );
            $resp = $1 if defined $temp and $temp =~ /^(\d)$/;
        #}
    }
    return $resp;
}

sub debug {
    shift;
    $debug = shift;
}

no strict 'subs';
no warnings 'syntax';

sub UNIVERSAL::Shared : ATTR(ANY) {
    my $var = $_[2];
    share($var);
}

sub share {
    no strict 'subs';
    my $ref  = shift;
    my $id   = shift;
    my $type = ref $ref;
    return $ref unless $type;
    my $sockpath = $PATH || "/tmp/threads::emulate.sock";
    my $count;
    until ( -S $sockpath ) {
        ++$count < 600 || die "...";
        usleep 50;
    }
    tie $$ref, threads::emulate::share::Scalar, $id, $$ref if $type eq "SCALAR";
    tie @$ref, threads::emulate::share::Array,  $id, @$ref if $type eq "ARRAY";
    tie %$ref, threads::emulate::share::Hash,   $id, %$ref if $type eq "HASH";
    if ( defined $type and $type !~ /^(?:SCALAR|ARRAY|HASH|CODE)$/ ) {
        my $unblessed = unbless($ref);
        $ref = share($unblessed);
        my $obj = get_obj($ref);
        $obj->obj_type($type) if $type;
    }
    $vars{ __PACKAGE__->value_or_id($ref) } = $ref;
    $ref;
}

sub unbless {
    my $obj   = shift;
    my $class = ref $obj;
    my $type  = $1 if $obj =~ /^$class=(HASH|ARRAY|SCALAR)\(/;
    my $ret;
    my $data;
    if ( $type eq "HASH" ) {
        $ret = { %{$obj} };
    }
    elsif ( $type eq "ARRAY" ) {
        $ret = [ @{$obj} ];
    }
    elsif ( $type eq "SCALAR" ) {
        $ret = \${$$obj};
    }
    $ret;
}

sub get_obj {
    my $self = shift;
    my $value = shift || $self;
    if ( ref $value ) {
        my $ref;
        $ref = tied $$value if ref $value eq "SCALAR";
        $ref = tied @$value if ref $value eq "ARRAY";
        $ref = tied %$value if ref $value eq "HASH";
        $value = $ref;
    }
    $value;
}

sub get_ref_or_value {
    my $self  = shift;
    my $id    = shift;
    my $value = $id;
#print "value: $value$/";
    if ( $value =~ /^(shared(SCALAR|ARRAY|HASH)\(\d+\))$/ ) {
        $value = $vars{$1};
        unless ( ref $value ) {
            my $ref;
            $ref = \"" if $2 eq "SCALAR";
            $ref = []  if $2 eq "ARRAY";
            $ref = {}  if $2 eq "HASH";
            threads::emulate::share::share( $ref, $id );
            $value = $ref;
        }
    }
    if ( ref $value ) {
        my $obj   = get_obj($value);
        my $class = get_obj_type($obj);
        $value = bless $value, $class if $class;
    }
    $value;
}

{
   my $msg_id = 1;
   sub send {
      my $self = shift;
      my $msg = join "", @_;
      my $reply;
      my $reply_id;
      $msg_id = $msg_id < 9999 ? $msg_id + 1 : 1;

      until(defined $reply_id and $reply_id == $msg_id) {
         $self->write("$msg_id:$msg");
         $reply = $self->read;
         next if $reply eq "ERROR";
         $reply_id = $1 if $reply =~ s/^(\d+)://;
         next unless defined $reply_id and $reply_id =~ /^\d+$/;
      }
      $reply
   }
}

sub write {
    my $self = shift;
    my $msg  = shift;
    {
        local $\ = "\r\n";
        #$, = " ";
        my $sock = $self->{sock};
        #print {$sock} unpack "C*", $msg;
        print {$sock} $msg;
    }
}

sub read {
    my $self = shift;
    my $resp;
    {
        local $/ = "\r\n";
        my $sock = $self->{sock};
        $resp = scalar <$sock>;
        chomp( $resp ) if defined $resp;
        $resp =~ s/\r\n?$// if defined $resp;
    }
    $resp;
}

sub set_id {
    my $self = shift;
    $self->{id} = shift;
}

sub get_id {
    my $self = shift;
    $self->{id};
}

sub value_or_id {
    my $self  = shift;
    my $value = shift;
    my $ret;
    my $obj;
    my $type;
    if ( defined $value and (my $ref = ref $value
        or $value =~ /^(?:shared(SCALAR|ARRAY|HASH)\(\d+\))$/) )
    {
        $type = $1;
        if ( defined $ref and $ref eq "SCALAR" or defined $type and $type eq "SCALAR" ) {
            $ret = $obj->get_id if $obj = tied $$value;
        }
        elsif ( defined $ref and $ref eq "ARRAY" or defined $type and $type eq "ARRAY" ) {
            $ret = $obj->get_id if $obj = tied @$value;
        }
        elsif ( defined $ref and $ref eq "HASH" or defined $type and $type eq "HASH" ) {
            $ret = $obj->get_id if $obj = tied %$value;
        }
    }
    else {
        $ret = $value;
    }

    #$obj->obj_type(ref $obj) if $type;
    $ret;
}

sub obj_type {
    my $self = shift;
    my $type = shift;
    $self->send( "objtype:" . $self->get_id . ":$type" ) if $self;
}

sub get_obj_type {
    my $self = shift;
    $self->send( "getobjtype:" . $self->get_id ) if $self;
}

sub obj_type_on_index {
    my $self  = shift;
    my $index = shift;
    my $type  = shift;
    $self->send( "objtypeonindex:" . $self->get_id . ":$index:$type" ) if $self;
}

sub get_obj_type_on_index {
    my $self  = shift;
    my $index = shift;
    $self->send( "getobjtypeonindex:" . $self->get_id . ":$index" ) if $self;
}

42;
