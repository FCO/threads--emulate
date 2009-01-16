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

sub connect {
    my $self     = shift;
    my $sockpath = shift;
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
    my $tid  = shift;
    $tid = 0 if $tid eq "main";
    my $resp = 0;
    $resp = $self->send( "LOCK:" . ( join ":", $self->get_id, $tid ) ), $/
      while not $resp
          and usleep 5;
}

sub unlock {
    my $self = shift;
    my $tid  = shift;
    $self->send( "UNLOCK:" . ( join ":", $self->get_id, $tid ) );
}

sub debug {
    shift;
    $debug = shift;
    threads::emulate::share::Scalar->debug($debug);
    threads::emulate::share::Array->debug($debug);
    threads::emulate::share::Hash->debug($debug);
}

no strict 'subs';
no warnings;

sub UNIVERSAL::shared : ATTR(SCALAR) {
    my $var = $_[2];
    easyshare_attr($var);
}

sub UNIVERSAL::shared : ATTR(ARRAY) {
    my $var = $_[2];
    easyshare_attr($var);
}

sub UNIVERSAL::shared : ATTR(HASH) {
    my $var = $_[2];
    easyshare_attr($var);
}

sub easyshare_attr {
    no strict 'subs';
    my $ref  = shift;
    my $id   = shift;
    my $type = ref $ref;
    return $ref unless $type;
    my $sockpath = "/tmp/threads::emulate.sock";
    my $count;
    until ( -S $sockpath ) {
        ++$count < 600 || die "...";
        usleep 50;
    }
    tie $$ref, threads::emulate::share::Scalar, $id, $$ref if $type eq "SCALAR";
    tie @$ref, threads::emulate::share::Array,  $id, @$ref if $type eq "ARRAY";
    tie %$ref, threads::emulate::share::Hash,   $id, %$ref if $type eq "HASH";
    if ( defined $type and $type !~ /SCALAR|ARRAY|HASH/ ) {
        my $unblessed = unbless($ref);
        $ref = easyshare_attr($unblessed);
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
    if ( $value =~ /^(fer(SCALAR|ARRAY|HASH)\(\d+\))$/ ) {
        $value = $vars{$1};
        unless ( ref $value ) {
            my $ref;
            $ref = \"" if $2 eq "SCALAR";
            $ref = []  if $2 eq "ARRAY";
            $ref = {}  if $2 eq "HASH";
            threads::emulate::share::easyshare_attr( $ref, $id );
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

sub send {
    my $self = shift;
    my $msg  = shift;
    {
        local $\ = "\r\n";
        my $sock = $self->{sock};
        print {$sock} $msg;
    }
    my $resp = $self->read;
    $resp;
}

sub read {
    my $self = shift;
    my $resp;
    {
        local $/ = "\r\n";
        my $sock = $self->{sock};
        chomp( $resp = scalar <$sock> );
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
    if ( my $ref = ref $value
        or $value =~ /^(?:fer(SCALAR|ARRAY|HASH)\(\d+\))$/ )
    {
        $type = $1;
        if ( $ref eq "SCALAR" or $type eq "SCALAR" ) {
            $ret = $obj->get_id if $obj = tied $$value;
        }
        elsif ( $ref eq "ARRAY" or $type eq "ARRAY" ) {
            $ret = $obj->get_id if $obj = tied @$value;
        }
        elsif ( $ref eq "HASH" or $type eq "HASH" ) {
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

42;
