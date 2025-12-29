use Object::Pad ':experimental(:all)';

package IPC::Nosh::Base;

class IPC::Nosh::Base;

use utf8;
use v5.40;

use Data::Dumper::Names;
use Devel::StackTrace::WithLexicals;
use PadWalker;
use IO::Handle;
use Syntax::Keyword::Defer;

use base 'Class::Exporter';
use vars qw'@EXPORT @EXPORT_OK';

@EXPORT = qw(dmsg info success err fatal);

field $debug = $ENV{DEBUG} // 0;
field %fhcache : reader(handle) = ();

method writeh( $line, $handle, %opt ) {
    if ( my $prev = $fhcache{$handle} ) {
        $handle = $prev unless $opt{newh};
    }
    else {
        $handle = $fhcache{$handle} = IO::Handle->new_from_fd( $handle, 'w' );
        binmode $handle, ":encoding(UTF-8)";
    }

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
    $self->outh("▶ $line");
}

method dmsg (@data) {
    my @caller = caller 0;
    local $Data::Dumper::Names::UpLevel = 2;

    my $out;
    $out .= Dumper(@_);
    $out .=
      $debug && $debug == 2
      ? join "\n", map { ( my $line = $_ ) =~ s/^\t/  /; "  $line" } split /\R/,
      Devel::StackTrace::WithLexicals->new(
        indent      => 1,
        skip_frames => 1
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
