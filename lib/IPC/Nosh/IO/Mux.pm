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
field $autochomp : param //= 1;
field $handle    : param = IO::Handle->new_from_fd( $fd, $mode );
field @array;
field $tied;

ADJUST {
    $handle->autoflush
}

method PUSH (@list) {
    push @array, map { $handle->print($_); chomp $_ if $autochomp; $_ } @list;
    $self->FETCHSIZE;
}

method STORE( $index, $value ) {
    $handle->print($value);
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
        grep { $opt{$_} } qw(fd mode handle autochomp)
    );

    dmsg( $self, $class, \%opt );
    $self;
}

# sub PUSH ($self, @list) {
#     #$self->{writeh}->( $_, $self->{handle} ) for @list;

#     # TODO: benchmark against calling SUPER->PUSH for each elem
#     Tie::StdArray::PUSH( $self,
#         map { $self->{handle}->print($_); chomp $_; $_ } @list );
# }

# sub STORE( $self,$index, $value ) {
#     #$self->{writeh}->teh( $value, $self->{handle} );
# $self->{handle}->print($value);

# # dmsg( $self, $index, $value );
# Tie::StdArray::STORE( $self, $index, map { chomp $_; $_ } $value );
# }

# sub TIEARRAY  ($class, %opt) {
# my $self = Tie::StdArray->TIEARRAY(%opt);(%
# $self->{fd} = $opt{fd} if $opt{fd};
# $self->{mode} = $opt{mode} if $opt{mode};
# dmsg($self);
# $self->{handle} = "asdf";#IO::Handle->new_from_fd($self->{fd}, $self->{mode} // 'w');
# }
