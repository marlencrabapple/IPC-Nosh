use Object::Pad ':experimental(:all)';

package IPC::Nosh;

class IPC::Nosh;

our $VERSION = "0.01";

use parent 'Exporter';
use vars qw'@EXPORT @EXPORT_OK';

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

# field $same_instance : param(use_imported) = 0;
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

field $tie : reader : param = {};

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

  };

method $inithandles ( $in, $out, $err, $tieopt, %opt ) {
    $in = undef
      if $opt{stdin_passthrough};

    dmsg \%opt;

    foreach my ( $k, $v ) ( mesh [qw(inh outh errh)], [ $in, $out, $err ] ) {
        dmsg $k, $v, ref $v;

        if ( $v isa ARRAY ) {
            tie @$v, 'IPC::Nosh::IO::Mux', %$tieopt;
        }

        # elsif ( $v isa CODE ) {
        #     push $v->callback->{ ( $k =~ s/$FH_SUFFIX_RE//r ) }{line}->@*, $v;
        # }
        elsif ( $v isa GLOB ) {
            tie @$v, 'IPC::Nosh::IO::Mux', %$tieopt, fh => $v;

        }
        elsif ( !defined ref $v || !defined $v ) {

            # tie @$v, 'IPC::Nosh::IO::Mux', %$tieopt;
            # $$tie{$k} = tied @$v;

            #   IPC::Nosh->tie_handle( ( $k =~ s/h$//r ), %$tieopt );
        }

        $$tie{$k} = tied @$v;

        dmsg $$tie{$k}, ref $$tie{$k};
    }

    # dmsg $self->tie, $tie;
}

method adjhelper( $in, $out, $err, $on, $tieopt, %opt ) {

    $self->$inithandles( $in, $out, $err, $tieopt, %opt );

    #dmsg $self->tie;
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

method runcmd($cmd) {
    $self->$run($cmd);
}

sub run ( $cmd, %opt ) {
    my $self = IPC::Nosh->new(%opt);
    my $run  = $self->runcmd($cmd)     # %opt{qw'in out err'} );
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

