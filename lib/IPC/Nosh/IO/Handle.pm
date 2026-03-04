use Object::Pad ':experimental(:all)';

package IPC::Nosh::IO::Handle;

class IPC::Nosh::IO::Handle : isa(IO::Handle);

use utf8;
use v5.40;

field $autochomp : param;
