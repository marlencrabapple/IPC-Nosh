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
use IO::Handle::Common;
use Syntax::Keyword::Try;
use Syntax::Keyword::Dynamically;

const our @run_cb_global_allow => qw( success ipcfail error fail nonzero exit);

const our @run_cb_allow => (qw(in out err));
const our @run_arg_allow => ( @run_cb_allow, qw'autoflush autochomp' )
  ;    #, @run_cb_global_allow )

# name => [ coderef, ... ]
field $global_cb = {};

field $global_autochomp : param(autochomp) //= 0;
field $global_autoflush : param(autoflush) //= 0;

field $in_aref  = [];
field $out_aref = [];
field $err_aref = [];

field $cmd : param;
field $in;     #: param;
field $out;    #: param;
field $err;    #: param;

field $status : reader;
field $oserr  : reader;

field $tied = {};

field $run_arg_href = {};

ADJUST : params ( %arg) {

    dmsg $self, \%arg;

    $run_arg_href = \%arg;

    my %tieopt = (
        autochomp => $global_autochomp,
        autoflush => $global_autoflush,
    );

    $self->add_cb( \%arg, $global_cb,
        filter => \@IPC::Nosh::run_cb_global_allow );

    foreach my ( $name, $aref )
      ( 'in', $in_aref, 'out', $out_aref, 'err', $err_aref )
    {
        # my %handle_cb = map { [$name => { ( $_ isa ARRAY ? $_ : [$_] ) ) } }
        #   %arg{@IPC::Nosh::Mux::cb_handle_allow};

        my %on = ();    #( $arg{on} isa 'HASH' ? $arg{on}->%* : () );

        # $self->add_cb( \%arg, \%on, filter => \@IPC::Nosh::run_cb_allow );

        if ( ( $name eq 'in' ) && ( $arg{in} isa 'HASH' ) ) {
            @on{qw'line eof'} = $arg{in}->@{qw'line eof'};
        }
        else {
            dmsg \%arg, $arg{$name};
            $on{line} = $arg{$name};
        }

        $$tied{$name} = tie @$aref, 'IPC::Nosh::Mux', %tieopt, on => \%on;
    }

};

method add_cb( $in, $dest, %opt ) {
    $$dest{ $$_[0] } = $$_[1]
      for map { [ $_ => ( $$in{$_} isa ARRAY ? $_ : [ $$in{$_} ] ) ] }
      ( $opt{filter} && $opt{filter} isa ARRAY ? $opt{filter}->@* : keys %$in );
}

method $run ($cmd) {

    # my class IPCNoshRun {
    #     field $runner : param;
    #     field $tied   : param;

    #     method out {
    #         $$tied{out};
    #     }

    #     method in () {

    #     }

    #     method err () {

    #     }
    # };

    try {
        my $ipcfail = run3( $cmd, $in_aref, $out_aref, $err_aref );

        ( $status, $oserr ) = ( $?, $! );

        if ($ipcfail) {
            $_->( $self, ret => $ipcfail, cmd => $cmd, arg => $run_arg_href )
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
        %arg{@run_arg_allow}
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
            out => sub ($line) {
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

