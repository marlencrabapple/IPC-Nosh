use Object::Pad ':experimental(:all)';

package IPC::Nosh;

class IPC::Nosh;

our $VERSION = "0.01";

use parent 'Exporter';
use vars qw'@EXPORT @EXPORT_OK';

# use base 'Class::Exporter';
#use vars qw'@EXPORT @EXPORT_OK';

use utf8;
use v5.40;

use IPC::Run3;
use IO::Handle;
use Const::Fast;
use List::Util qw'mesh none';
use Syntax::Keyword::Try;
use Syntax::Keyword::Dynamically;

use IPC::Nosh::IO::Mux;
use IPC::Nosh::IO;

@EXPORT = 'run';

const our @EVENTLIST => qw'line error exiterr nonzero exit eof ipcfail success';
const our $FH_SUFFIX_RE => qr/h$/;

field $constructor;

field $same_instance : param(use_imported) = 0;
field $debug //= $ENV{DEBUG};

field $in  : reader = \undef;
field $out : reader = [];
field $err : reader = [];

field $status : reader;
field $oserr  : reader;

field $handle_aref;
field $handle_fh;
field $handle_coderef;

field $callback : accessor(on) = { ipcfail => [] };

field $tie : reader = {};

ADJUST : params (
  : $autoflush         //= undef,
  : $autochomp         //= undef,
  : $stdin_passthrough //= undef,
  : $on = {},
  : $in = $self->in,

  : $out = $self->out,
  : $err = $self->err
  ) {

    push $$callback{ipcfail}->@*, delete $$on{ipcfail} if $$on{ipcfail};

    my %tiearg = (
        on        => $on,
        autoflush => $autoflush ? 1 : 0,
        autochomp => $autochomp ? 1 : 0
    );

    $self->adjhelper( $in, $out, $err, $on, \%tiearg,
        stdin_passthrough => $stdin_passthrough );

    $constructor = {
        stdin_passthrough => $stdin_passthrough,
        autochomp         => $autochomp,
        autoflush         => $autoflush,
        in                => $self->in,
        out               => $self->out,
        err               => $self->err
    };

  };

method $inithandles ( $in, $out, $err, $tieopt, %opt ) {
    $in = undef
      if $opt{stdin_passthrough};

    foreach my ( $k, $v ) ( mesh [qw(inh outh errh)], [ $in, $out, $err ] ) {

        if ( $v isa ARRAY ) {

            # Used as backing storage or kept in synccbp
            # with replcaement more  suitable for job load
            $$tie{$k} = $self->tie_handle( $v, %$tieopt );
        }
        elsif ( $v isa CODE ) {
            push $v->callback->{ ( $k =~ s/$FH_SUFFIX_RE//r ) }{line}->@*, $v;
        }
        elsif ( $v isa GLOB ) {

            # File handle is appended to by line with respects to existing
            # binmode
            $$tie{$k} = $self->tie_handle( $v, %$tieopt, fh => $v );
        }

    }

    $tie;
}

method adjhelper( $in, $out, $err, $on, $tieopt, %opt ) {

    $self->$inithandles( $in, $out, $err, $tieopt, %opt );
}

method $run ( $cmd, %opt ) {

    # Exec the command with tied handles and collect exit status
    try {
        my $ipcfail = run3( $cmd, $in, $out, $err );

        ( $status, $oserr ) = ( $?, $! );

        if ($ipcfail) {

            $_->( $self, ret => $ipcfail, args => [ $cmd, $in, $out, $err ] )
              for $$callback{ipcfail}->@*;
        }

    }
    catch ($e) {

        fatal($e);
    }

    # Success
    if ( $status == 0 ) {
        $_->($status) for $$callback{success}->@*;
    }
    else {    # Failure (TODO: look into why some exit codes are over 255)
        $_->(
            $self,
            exit => { status => $status, os_errno => $oserr },
            args => [ $cmd, $in, $out, $err ]
        ) for $$callback{ipcfail}->@*;
    }

    $self;
}

method runcmd( $cmd, %opt ) {
    $self->$run( $cmd, %opt );
}

method tie_handle : common ( $aref, %opt ) {
    tie @$aref, 'IPC::Nosh::IO::Mux', %opt;
    dmsg $aref, \%opt, $tied;
}

sub run ( $cmd, %opt ) {
    my $self = IPC::Nosh->new(%opt);
    $self->runcmd( $cmd, %opt );
}

__END__

=encoding utf-8

=head1 NAME

IPC::Nosh - no-shell system commands and subprocess interaction

=head1 SYNOPSIS

    use IPC::Nosh; # run() is exported by default
    my $run = run(\@cmd, %options)

=head1 DESCRIPTION

IPC::Nosh is a easy to use tool to multiplex data to and from external commands.

=head1 LICENSE

Copyright(C) Ian P Bradley .

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=head1 AUTHOR

Ian P Bradley E<lt>ian@pennyfoss.orgE<gt>

=cut

