use Object::Pad ':experimental(:all)';

package IPC::Nosh::IO::Mux;
class IPC::Nosh::IO::Mux;

use utf8;
use v5.40;

use IO::Handle;
use IPC::Nosh::IO;

use vars qw'@ISA @EXPORT';

field $fd        : param //= *STDOUT;
field $mode      : param //= 'w';
field $autochomp : param //= undef;
field $handle : param : reader = IO::Handle->new_from_fd( $fd, $mode );
field @array;
field $tied;

field $callback : param(on) = {};

ADJUST :params (:$autoflush //= undef) {
    # dmsg( $self, $autoflush, $handle );
    $handle->autoflush if $autoflush
}

# method line ($line) {
#     $_->( $self, $line ) for $$callback{line}->@*;
# }

# method error ($line) {
#     $_->( $self, $line ) for $$callback{error}->@*;
# }


method autoflush {
    $handle->autoflush( shift // 1 )
}

method PUSH (@list) {
    push @array, map { $handle->print($_); chomp $_ if $autochomp; $_ } @list;
    $self->FETCHSIZE;
}

method STORE( $index, $value ) {
    $handle->print($value);
    # $_->( $self, $value ) for $$callback{line}->@*;
    chomp $value if $autochomp;
    $array[$index] = $value;
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
    shift @array
}

method UNSHIFT (@list) {
    unshift @array, @list;
    $self->FETCHSIZE;
}

method DELETE ($index) {
    $self->STORE($index, undef)
}

method TIEARRAY : common ( %opt ) {
    my $self = $class->new(
        map  { $_ => $opt{$_} }
        grep { $opt{$_} } qw(fd sub scalarref mode handle autochomp autoflush)
    );

    # dmsg( $self, $class, \%opt );
    $self;
}
