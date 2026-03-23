use Object::Pad ':experimental(:all)';

package IPC::Nosh;

class IPC::Nosh;

use v5.40;

our $VERSION = "0.01";

use parent 'Exporter';
use vars '@EXPORT';

@EXPORT = qw(run);

use Const::Fast;
use IPC::Run3;
use IPC::Nosh::Mux;
use IPC::Nosh::Common;
use Syntax::Keyword::Try;
use Syntax::Keyword::Dynamically;

# name => [ coderef, ... ]
field $global_cb = {};

field $global_autochomp : param(autochomp) //= 0;
field $global_autoflush : param(autoflush) //= 0;

field $in_aref  = [];
field $out_aref = [];
field $err_aref = [];

field $cmd : param;
field $in  : param;
field $out : param;
field $err : param;

field $status;
field $oserr;

field $tied = {};

ADJUST {

    my %tieopt = ( autochomp => $global_autochomp, autoflush => 1 );

    foreach my ( $name, $aref )
      ( 'in', $in_aref, 'out', $out_aref, 'err', $err_aref )
    {
        $$tied{$name} = tie @$aref, 'IPC::Nosh::Mux', %tieopt;
    }
}

method $run ($cmd) {

    try {
        my $ipcfail = run3( $cmd, $in_aref, $out_aref, $err_aref );

        #my $ipcfail = run3( $cmd, $$tied{in}, $$tied{out}, $$tied{err} );

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

    # dmsg $self;
    $self;
}

sub run ( $cmd, %arg ) {
    my $nosh = IPC::Nosh->new(
        cmd => $cmd,
        %arg{qw'in out err on autoflush autochomp'}
    );

    $nosh->$run($cmd);
}

method in {
    $$tied{in};
}

method out {
    $$tied{out};
}

method err {
    $$tied{err};
}

__END__

=encoding utf-8

=head1 NAME

IPC::Nosh - Flexible no-shell IPC interface with IO muxing

=head1 SYNOPSIS

    use IPC::Nosh;

    my $err;

    my $run = run(
        [qw(ls -ltra)],
        out       => path('ls-output.txt'),
        err       => \$err,
        autochomp => 1,
        on        => {
            line => sub ($line) {
                my ( $path, undef ) = split /\s/, $line;
                path($path)->absolute . "\n";
            }
        }
      );

    if ($run->status > 0) {
        fatal($err)
    }

=head1 DESCRIPTION

IPC::Nosh is ...

=head1 LICENSE

Copyright (C) Ian P Bradley.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Ian P Bradley E<lt>ian.bradley@studiocrabapple.comE<gt>

=cut

