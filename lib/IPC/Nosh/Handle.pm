use Object::Pad ':experimental(:all)';

package IPC::Nosh::Handle;

class IPC::Nosh::Handle;

use utf8;
use v5.40;

use List::Util 'none';
use IO::Handle;
use Const::Fast;
use FileHandle;

use IPC::Nosh::Common;

field $fileno;
field $handle;
field $path;
field $mode : param = 'w';

ADJUST : params ( :$fn ) {
    $path = path($fn)->open($mode);
};

ADJUST : params ( :$fh ) {
    $handle = $fh;
    $fileno = fileno($fh)
};

ADJUST : params ( :$fd ) {
    $handle = FileHandle->new_from_fd($fd);
    $fileno = $fd
};

# sub AUTOLOAD {
#     my ( $self, @args ) = @_;
#     our $AUTOLOAD;

#     fatal "Unable to call method '$AUTOLOAD' on $handle"
#       unless $handle->can($AUTOLOAD);

#     $handle->$AUTOLOAD;
# }
