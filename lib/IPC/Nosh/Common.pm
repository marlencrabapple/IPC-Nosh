use Object::Pad ':experimental(:all)';

package IPC::Nosh::Common;

class IPC::Nosh::Common;

use utf8;
use v5.40;

use Const::Fast;
use Data::Dumper::Names;
use Devel::StackTrace::WithLexicals;
use PadWalker;
use IO::Handle;
use base 'Class::Exporter';
use vars qw'@EXPORT @EXPORT_OK';

@EXPORT = qw(dmsg info success err fatal msg);

field $debug = $ENV{DEBUG} // 0;
field %fhcache : reader(handle) = ();

field $ddn_uplvl    : param : accessor = 3;
field $trace_indent : param : accessor = $ENV{DEBUG_INDENT}     // 1;
field $skip_frames  : param : accessor = $ENV{DEBUG_SKIPFRAMES} // 1;

method writeh( $line, $handle, %opt ) {
    if ( $line isa 'ARRAY' ) {
        $handle->print("$_\n") for $line->@*;
    }
    elsif ( !ref $line ) {
        $handle->print("$line\n");
    }
}

method outh ($line) {
    $self->writeh( $line, *STDOUT );
}

method errh ($line) {
    $self->writeh( $line, *STDERR );
}

method info ($line) {
    $self->errh("▶ $line");
}

const our $ltrimtab_re => qr/^\t/;
const our $lb_re       => qr/\R/;

method dmsg {
    return unless $debug // $ENV{DEBUG};
    my @caller = caller 1;

    local $Data::Dumper::Names::UpLevel = $ddn_uplvl;
    local $Data::Dumper::Pad            = "  ";
    local $Data::Dumper::Indent         = 1;

    my $out;
    $out .= Dumper(@_);
    $out .=
      $debug && $debug == 2
      ? join "\n",
      map { ( my $line = $_ ) =~ s/$ltrimtab_re/  /; "  $line" } split $lb_re,
      Devel::StackTrace::WithLexicals->new(
        indent      => $trace_indent // 1,
        skip_frames => $skip_frames  // 1
      )->as_string
      : "at $caller[1]:$caller[2]\n";

    $self->errh($out);
    $out;
}

method err ($line) {
    $self->errh("❌️ $line");
}

method fatal ( $line, $status = $? // 255, %opt ) {
    $self->err($line);
    exit $status;
}

method success ($line) {
    $self->outh("⭕️ $line");
}

method msg ($line) {
    $self->outh($line);
}
