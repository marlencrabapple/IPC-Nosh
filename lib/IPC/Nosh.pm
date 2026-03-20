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

field $cmd : param;

field $in  //= { mode => 'r', fd => [ \undef ] };
field $out //= { mode => 'w', fd => [] };
field $err //= { mode => 'w', fd => [] };

field $status;
field $oserr;

field $tied : accessor = {};

ADJUST : params (:$in, :$out, :$err, :$on) {
    foreach my ( $k, $v ) ( in => $in, out => $out, err => $err ) {
        $$tied{$k} = $self->mux_io(
            $k, $v,
            autochomp => $global_autochomp,
            autoflush => $global_autoflush,
        );

    }

    const my @cballow =>
      qw'line error exiterr nonzero exit eof ipcfail success';

    @$global_cb{@cballow} =
      map { $$on{$_} isa ARRAY ? $$on{$_}->@* : [ $$on{$_} // () ] }
      grep { defined $_ } @$global_cb{@cballow};
};

method in {
    $$tied{in};
}

method out {
    $$tied{out};
}

method err {
    $$tied{err};
}

method mux_io( $name, $io, %arg ) {

    # my %tied;
    my $tied;

    my %tieopt = %arg{qw'handle autochomp autoflush on'};

    #push $tieopt{on}->@*, $$global_cb{line} if $$global_cb{line};

    if ( $io isa HASH ) {

        # %tieopt = $$io{qw'tieopt'}
        # my $on = $$io{on};
        ...;
    }
    if ( $io isa ARRAY ) {
        $tied = tie @$io, 'IPC::Nosh::Mux', %tieopt;

    }
    elsif ( $io isa CODE ) {
        my @array;
        $tied = tie @array, 'IPC::Nosh::Mux', %tieopt, on => { line => $io };

    }
    elsif ( $io isa GLOB ) {
        my @array;
        $tied = tie @array, 'IPC::Nosh::Mux', %tieopt, fh => $io;

    }
    elsif ( $io isa SCALAR && $$io ) {
        my @array;
        $tied = tie @array, 'IPC::Nosh::Mux', %tieopt, fn => $$io;

    }

    # $tied{mux} = $$tied{$name} = \%tied;
    dmsg( $tied, $tied2 );
    $tied;
}

method $run ($cmd) {
    try {
        my $ipcfail = run3( $cmd, $$tied{in}, $$tied{out}, $$tied{err} );

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

