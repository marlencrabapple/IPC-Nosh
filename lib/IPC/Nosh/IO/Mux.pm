use Object::Pad ':experimental(:all)';

package IPC::Nosh::IO::Mux;

class IPC::Nosh::IO::Mux;

use utf8;
use v5.40;

use IO::Handle;
use Const::Fast;
use IPC::Nosh::IO;

use vars qw'@ISA @EXPORT';

const our %mux_default => (
    fd        => *STDOUT,
    mode      => 'w',
    autochomp => undef,
    autoflush => undef
);

field $fd        : param //= *STDOUT;
field $mode      : param //= 'w';
field $autochomp : param //= undef;
field $autoflush : param //= undef;
field $mux_defaultopt : reader = \%mux_default;

field $handle : param : reader = IO::Handle->new_from_fd( $fd, $mode );
field @array;
field $tied;

field $callback : param(on) = {};

ADJUST {
    $handle->autoflush if $autoflush;
    dmsg $self;
}

method on_line ( $line, $line_no = undef ) {
    $self->$_( $line, $line_no ) for $$callback{line}->@*;
}

method PUSH (@list) {
    push @array, map {
        $handle->print($_);
        chomp $_ if $autochomp;

        #$_->( $self, $_ ) for $$callback{line}->@*;
        $self->on_line($_);
        $_
    } @list;

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

    $self;
}
