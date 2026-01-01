use Object::Pad ':experimental(:all)';

package IPC::Nosh::IO::Mux;

class IPC::Nosh::IO::Mux;

use v5.40;
use utf8;

use Tie::Array;
use IPC::Nosh::IO;

use vars qw'@ISA @EXPORT @EXPORT_OK';
@ISA = qw'Tie::StdArray';

field $fd   = *STDOUT;
field $mode = 'w';
field $handle { IO::Handle->new_from_fd( $fd, 'w' ) }
field $aref = [];

ADJUSTPARAMS($params) {

    dmsg( $params, $fd, $mode )
}

method PUSH (@list) {

    #$self->{writeh}->( $_, $self->{handle} ) for @list;
    # TODO: benchmark against calling SUPER->PUSH for each elem
    Tie::StdArray->PUSH( $self, map { chomp $_; $_ } @list );
}

method STORE( $index, $value ) {

    #$self->{writeh}->teh( $value, $self->{handle} );
    Tie::StdArray->STORE( $index, map { chomp $_; $_ } $value );
}

method TIEARRAY : common ( @list ) {
    my $self = $class->new(@list);    #Tie::StdArray->TIEARRAY(@list);
    dmsg( $self, $class, \@list );
    $self;
}
