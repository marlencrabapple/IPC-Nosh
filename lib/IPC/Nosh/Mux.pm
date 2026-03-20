use Object::Pad ':experimental(:all)';

package IPC::Nosh::Mux;

class IPC::Nosh::Mux;

use utf8;
use v5.40;

use vars '@ISA';

use List::Util qw'any none first';
use Const::Fast;
use Stream::Buffered;

use IPC::Nosh::Common;
use IPC::Nosh::Handle;

const our @EVENTLIST => qw'line eof';
const our %MUX_DEFAULT => (
    fd        => *STDOUT,
    mode      => ">",
    autochomp => undef,
    autoflush => undef
);

field $fileno    : reader(fd);    #//= *STDOUT;
field $mode      : param : reader //= $MUX_DEFAULT{mode};
field $autochomp : param : reader //= undef;
field $autoflush : param : reader //= undef;

field $buff : reader //= undef;

field $default_handle = IPC::Nosh::Handle->new(
    fd   => $MUX_DEFAULT{fd},
    mode => $MUX_DEFAULT{mode}
);

field $handle : reader = [];

field @array;

# name => [ coderef, ... ]
field $callback : accessor(on) //= {};

ADJUST : params (:$fn //= undef, :$fh //= undef, :$fd //= undef) {
    my @argref    = ( \$fn, \$fh, \$fd );
    my %handleopt = (
        mode      => $mode,
        autochomp => $autochomp,
        autoflush => $autoflush

    );

    foreach my $to_handle ( $fn, $fh, $fd ) {
        if ($fn) {
            push @$handle,
              IPC::Nosh::Handle->new(
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
                          IPC::Nosh::Handle->new( fh => $fh, %handleopt );
                    }
                }
            }

        }
        elsif ($fd) {
            push @$handle, IO::Nosh::Handle->new( fd => $fd, %handleopt );
        }
        else {
            $buff = Stream::Buffered->new();

            push @$handle,
              IPC::Nosh::Handle->new(
                fh => $buff->rewind,
                %handleopt
              );
        }
    }
};

ADJUST : params (:$on //= {}) {
    foreach my ( $e, $val ) (%$on) {
        if ( none { $e eq $_ } @IPC::Nosh::Mux::EVENTLIST ) {
            error "'$e' is not a valid key for '\$on'";
            next;
        }

        $$callback{$e} //= [];

        if ( $val isa ARRAY ) {
            push $$callback{$e}->@*, @$val;
        }
        elsif ( $val isa CODE ) {
            push $$callback{$e}->@*, $val;
        }
    }

};

ADJUST {
    if (
        none { $_ }
        map  { $$callback->@* }
        grep { $$callback{$_} isa ARRAY } keys %$callback,
        @$handle
      )
    {
        push @$handle, $default_handle;
    }

    #Q dmsg $callback, $handle;
}

method mux_default_args : common {
    %MUX_DEFAULT;
}

method on_line ( $line, $line_no = undef ) {
    $self->$_( $line, $line_no ) for $$callback{line}->@*;
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

    dmsg $self, \%opt;

    $self;
}

# TODO: reader methods

method lines ( $name, $lines, %opt ) {
    @array;
}

method lines_utf8 ( $name, $lines, %opt ) {
    $self->lines( $name, $lines, ( encode => 'UTF-8' ) );
}

