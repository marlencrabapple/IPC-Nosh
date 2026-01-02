use Object::Pad ':experimental(:all)';

package IPC::Nosh;

class IPC::Nosh;

our $VERSION = "0.01";

use base 'Class::Exporter';
use vars qw'@EXPORT @EXPORT_OK';

use utf8;
use v5.40;

use IPC::Run3;
use IO::Handle;

use IPC::Nosh::IO::Mux;
use IPC::Nosh::IO;

@EXPORT_OK = qw($run run);

field $in = \undef;
field $out : param = [];
field $err : param = [];
field %tie;

ADJUST {
    $tie{out} = tie @$out, 'IPC::Nosh::IO::Mux';
    $tie{err} = tie @$err, 'IPC::Nosh::IO::Mux', fd => *STDERR;
}

method $run ($cmd) {
    run3( $cmd, $in, $out, $err );
    dmsg( $self, $cmd, $in, $out, $err );
}

method run ( $cmd, %opt ) {
    $self->$run($cmd);
}

__END__

=encoding utf-8

=head1 NAME

IPC::Cmd - It's new $module

=head1 SYNOPSIS

    use IPC::Cmd;

=head1 DESCRIPTION

IPC::Cmd is ...

=head1 LICENSE

Copyright(C) Ian P Bradley .

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=head1 AUTHOR

Ian P Bradley E<lt>ian.bradley@studiocrabapple.comE<gt>

=cut

