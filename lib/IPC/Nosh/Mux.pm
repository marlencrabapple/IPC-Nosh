use Object::Pad ':experimental(:all)';

package IPC::Nosh::Mux;

class IPC::Nosh::Mux;

use utf8;
use v5.40;

use List::Util 'none';
use IO::Handle;
use Const::Fast;
use FileHandle;

use IPC::Nosh::Common;
use IPC::Nosh::Handle;

const our @EVENTLIST => qw'line eof';
const our %MUX_DEFAULT => (
    fd        => *STDOUT,
    mode      => 'w',
    autochomp => undef,
    autoflush => undef
);

field $fd        : param : reader = *STDOUT;
field $mode      : param : reader = 'w';
field $autochomp : param : reader = undef;
field $autoflush : param : reader = undef;

field $buff   : reader = undef;
field $handle : reader = [];
field @array;

# name => [ coderef, ... ]
field $callback : accessor(on) = {};

ADJUST : params (:$fn) { push @$handle, IPC::Nosh::Handle->new( fn => $fn ) };

ADJUST : params ( :$fh = [] ) {
    if ( $fh isa ARRAY && scalar @$fh ) {
        foreach my $fh (@$fh) {
            if ( $fh isa HASH ) {    # allowed keys: fh, fileno, ...
                ...;
            }
            elsif ( $fh isa GLOB ) {
                push @$handle, IPC::Nosh::Handle->new( fh => $fh );
            }
        }
    }
    else {
        $buff = Stream::Buffered->new();

        push $self->handle->@*,
          FileHandle->new( $buff->rewind, $$handle{mode} || $mode );
    }
};

ADJUST : params (:$on) {
    foreach my ( $e, $val ) (%$on) {
        if ( none { $e eq $_ } @IPC::Nosh::Mux::EVENTLIST ) {
            say STDERR "'$e' is not a valid key for '\$on'";
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

    $handle->autoflush if $autoflush;

    # dmsg $self
};

method mux_default_args : common {
    %MUX_DEFAULT;
}

method on_line ( $line, $line_no = undef ) {
    $self->$_( $line, $line_no ) for $$callback{line}->@*;
}

method PUSH (@list) {
    push @array, map {

        $handle->print($_);
        chomp $_ if $autochomp;

        # $_->( $self, $_ ) for $$callback{line}->@*;
        $self->on_line($_);
        $_
    } @list;

    use Data::Dumper;
    warn Dumper( [caller] );

    $self->FETCHSIZE;
}

method STORE( $index, $value ) {

    $handle->print($value);

    chomp $value if $autochomp;
    $array[$index] = $value;

    $self->on_line( $value, $index );
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
        map  { $_ => $opt{$_} }
        grep { $opt{$_} }
          qw(on fd sub scalarref mode handle autochomp autoflush)
    );

    # dmsg $self, \%opt;

    $self;
}
