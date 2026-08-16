use Object::Pad ':experimental(:all)';

package IPC::Nosh::Mux;

class IPC::Nosh::Mux;

use utf8;
use v5.40;

use Encode     qw'encode decode';
use List::Util qw'any none first all';
use Const::Fast;
use Stream::Buffered;
use IO::Handle::Common;
use IO::Handle::Common::Handle;

const our @CB_GLOBAL_ALLOW => qw'line eof';

const our %MUX_DEFAULT => (
    fd        => *STDOUT,
    mode      => ">",
    autochomp => undef,
    autoflush => undef
);

field @array;

field $charset   : param = 'UTF-8';
field $fileno    : reader(fd) //= *STDOUT;
field $mode      : param : reader //= $MUX_DEFAULT{mode};
field $autochomp : param : reader //= undef;
field $autoflush : param : reader //= undef;

field $buff : reader //= undef;

field $default_handle = IO::Handle::Common::Handle->new(
    fd   => $MUX_DEFAULT{fd},
    mode => $MUX_DEFAULT{mode}
);

field $handle : reader = [];
field $callback : accessor(on) //= {};

ADJUST : params (:$fn //= undef, :$fh //= undef, :$fd //= undef) {
    my @argref    = ( \$fn, \$fh, \$fd );
    my %handleopt = (
        mode      => $mode,
        autochomp => $autochomp,
        autoflush => $autoflush,
        encoding  => 'UTF-8'
    );

    foreach my $to_handle ( $fn, $fh, $fd ) {
        if ($fn) {
            push @$handle,
              IO::Handle::Common::Handle->new(
                fn => $fn,
                %handleopt
              );
        }
        elsif ($fh) {
            if ( $fh isa ARRAY && scalar @$fh ) {
                foreach my $fh (@$fh) {
                    if ( $fh isa HASH )
                    {    # allowed keys autochomp, autoflush, ...
                        ...;
                    }
                    elsif ( $fh isa GLOB ) {
                        push @$handle,
                          IO::Handle::Common::Handle->new(
                            fh => $fh,
                            %handleopt
                          );
                    }
                }
            }

        }
        elsif ($fd) {
            push @$handle,
              IO::Handle::Common::Handle->new( fd => $fd, %handleopt );
        }
        else {
            $buff = Stream::Buffered->new();

            push @$handle,
              IO::Handle::Common::Handle->new(
                fh => $buff->rewind,
                %handleopt
              );
        }
    }
};

ADJUST : params (:$on //= {}) {

    # dmsg $on;

    foreach my ( $e, $val ) (%$on) {
        if ( none { $e eq $_ } @IPC::Nosh::Mux::CB_GLOBAL_ALLOW ) {
            error "'$e' is not a valid key for '\$on'";
            next;
        }

        $$callback{$e} //= [];

        if ( ( ref $val eq 'ARRAY' ) && ( all { ref $_ eq 'CODE' } @$val ) ) {
            push $$callback{$e}->@*, @$val;
        }
        elsif ( ref $val eq 'CODE' ) {
            push $$callback{$e}->@*, $val;
        }
        elsif ($val) {

            fatal "'$e' must be a CODE or an ARRAY of CODE";
        }
    }

};

ADJUST {
    if (
        none { $_ }
        map  { $$callback{$_}->@* }
        grep { ref $$callback{$_} && ref $$callback{$_} eq 'ARRAY' }
        keys %$callback,
        @$handle
      )
    {
        # dmsg $self;
        push @$handle, $default_handle;
    }

}

method mux_default_args : common {
    %MUX_DEFAULT;
}

method on_line ( $line, $line_no = undef ) {

    # TODO: Check sub signature for number of args and pass only those
    $_->( $line, $line_no, $self ) for $$callback{line}->@*;
}

method PUSH (@list) {
    push @array, map {
        my $line = $_;
        chomp $line if $autochomp;

        $_->say($line) for @$handle;
        $self->on_line($line);
        $line
    } @list;

    $self->FETCHSIZE;
}

method STORE( $index, $value ) {
    chomp $value if $autochomp;

    $_->say($value) for @$handle;

    $array[$index] = $value;
    $self->on_line( $value, $index );

    $index > $self->FETCHSIZE ? undef : $index;
}

method STORESIZE ($count) {
    if ( $count > $self->FETCHSIZE .. $count ) {
        foreach ( $count = $self->FETCHSIZE .. $count ) {
            $self->STORE( $count, '' );
        }
    }
    elsif ( $count < $self->FETCHSIZE ) {
        foreach ( 0 .. $self->FETCHSIZE - $count - 2 ) {
            pop @array;
        }
    }
}

method EXTEND ($count) {

}

method FETCH ($index) {
    $array[$index];
}

method FETCHSIZE {
    scalar @array;
}

method CLEAR {
    @array = ();
}

method POP {
    pop @array;
}

method SHIFT {
    shift @array;
}

method UNSHIFT (@list) {
    unshift @array, @list;
    $self->FETCHSIZE;
}

method DELETE ($index) {
    $self->STORE( $index, undef );
}

method TIEARRAY : common ( %opt ) {
    my $self = $class->new(
        map  { ( $_ => $opt{$_} ) }
        grep { $opt{$_} } qw(on fd sub mode fh fn autochomp autoflush)
    );

    $self;
}

method lines (%opt) {
    map {
        $opt{encode} && $opt{encode} ne $charset
          ? encode( $_, $opt{encode} )
          : $_
    } @array;
}

method lines_utf8 (%opt) {
    $self->lines( encode => 'UTF-8' );
}

method joined (%opt) {
    join( $autochomp ? "" : "\n" ), $self->lines(%opt);
}

method joined_utf8 (%opt) {
    $self->joined(%opt);
}
