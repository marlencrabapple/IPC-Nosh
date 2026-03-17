use Object::Pad ':experimental(:all)';

package IPC::Nosh;

class IPC::Nosh;

use v5.40;

our $VERSION = "0.01";

use parent 'Exporter';
use vars '@EXPORT';

@EXPORT = qw(run);

use IO::Handle;
use IPC::Nosh::Mux;
use IPC::Nosh::Common;

# name => [ coderef, ... ]
field $global_cb : param(on);

field $global_autochomp : param(autochomp);
field $global_autoflush : param(autoflush);

field $cmd : param;
field $in  : param = undef;
field $out : param = IO::Handle->new_from_fd(*STDOUT)->('w');
field $err : param = IO::Handle->new_from_fd(*STDERR)->('w');

field $status;
field $oserr;

method mux_io( $name, $io, %arg ) {
    my $tied;
    my %tieopt = %arg{qw'autochomp autoflush on'};

    if ( $io isa ARRAY ) {
        $self->name = $io;
        $tied       = tie @$io, 'IPC::Nosh::Mux', %tieopt;
    }
    elsif ( $io isa CODE ) {
        $tied = tie $self->$name->@*, 'IPC::Nosh::Mux', %tieopt,
          on => { line => $io };
    }
    elsif ( $io isa GLOB ) {
        $tied = tie $self->name, 'IPC::Nosh::Mux', %tieopt, fh => $io;
    }
    elsif ( $io isa SCALAR && !$$io ) {
        $self->name = $$io;
    }
}

method $run ($cmd) {
    try {
        my $ipcfail = run3( $cmd, $in, $out, $err );

        ( $status, $oserr ) = ( $?, $! );

        if ($ipcfail) {
            $_->( $self, ret => $ipcfail, args => [ $cmd, $in, $out, $err ] )
              for $$global_cb{ipcfail}->@*;
        }
    }
    catch ($e) {
        fatal($e);
    }

    # Success
    if ( $status == 0 ) {
        $_->($status) for $global_cb->{success}->@*;
    }
    else {    # Failure (TODO: look into why some exit codes are over 255)
        $_->(
            $self,
            exit => { status => $status, os_errno => $oserr },
            args => [ $cmd, $in, $out, $err ]
        ) for $$global_cb{ipcfail}->@*;
    }

    $self;
}

sub run ( $cmd, %arg ) {
    my $nosh =
      IPC::Nosh->new( $cmd, @arg{qw'in out err on autoflush autochomp'} );

    $nosh->$run($cmd);
}

__END__

=encoding utf-8

=head1 NAME

IPC::Nosh - It's new $module

=head1 SYNOPSIS

    use IPC::Nosh;

=head1 DESCRIPTION

IPC::Nosh is ...

=head1 LICENSE

Copyright (C) Ian P Bradley.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Ian P Bradley E<lt>ian.bradley@studiocrabapple.comE<gt>

=cut

