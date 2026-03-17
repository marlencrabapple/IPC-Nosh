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

# name => [ coderef, ... ]
field $global_cb : = {};

field $global_autochomp : param(autochomp) = 0;
field $global_autoflush : param(autoflush) = 0;

field $cmd : param;

field $in  : reader = undef;
field $out : reader = [];
field $err : reader = [];

field $status;
field $oserr;

field $tied = {};

ADJUST : params (:$in, :$out, :$err) {
    foreach my ( $k, $v ) ( in => $in, out => $out, err => $err ) {
        if (
            my $mux = $self->mux_io(
                $k, $v,
                autochomp => $global_autochomp,
                autoflush => $global_autoflush
            )
          )
        {
            $$tied{$k} = $mux;
        }
    }
};

ADJUST : params (:$on) {
    const my @cballow =>
      qw'line error exiterr nonzero exit eof ipcfail success';

    @$global_cb{@cballow} =
      map { $$on{$_} isa ARRAY ? $$on{$_}->@* : [ $$on{$_} // () ] }
      @$global_cb{@cballow};
};

method mux_io( $name, $io, %arg ) {
    my $tied;

    my %tieopt = %arg{qw'handle autochomp autoflush on'};
    push $tieopt{on}->@*, $global_cb{line} if $global_cb{line};

    if ( $io isa 'HASH' ) {

        # %tieopt = $$io{qw'tieopt'}
        # my $on = $$io{on};

    }
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
        my $meta = Object::Pad::MOP::Class->for_caller;
        $meta->get_field($name)->value($io);
    }

    dmsg $tied;
    $tied;
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

    dmsg $self;

    $self;
}

sub run ( $cmd, %arg ) {
    my $nosh = IPC::Nosh->new(
        cmd => $cmd,
        %arg{qw'in out err on autoflush autochomp'}
    );

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

