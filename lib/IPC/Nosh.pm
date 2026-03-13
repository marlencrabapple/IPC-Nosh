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
use Const::Fast;
use List::Util qw'mesh none';
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

field $callback : accessor(on) = {};

field $tie : reader;

ADJUST : params (
  : $autoflush         //= undef,
  : $autochomp         //= undef,
  : $stdin_passthrough //= undef,
  : $on = {},
  : $in = \undef,

  : $out = [],
  : $err = []
  ) {
    my %tiearg = (
        autoflush => $autoflush ? 1 : 0,
        autochomp => $autochomp ? 1 : 0
    );

    $self->adjhelper( $in, $out, $err, $on, \%tiearg, stdin_passthrough => $stdin_passthrough );

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
      if $opt{stdin_pt};

    $self->set_handle( $out, 'out', %$tieopt );

    $self->set_handle(
        $err, 'err',
        fd => *STDERR,
        %$tieopt
    );

    foreach my ( $k, $v )
      ( mesh [qw(inh outh errh)], [ $in, $out, $err ] )
    {
        if ( ref $v eq 'ARRAY' ) {

            # Used as backing storage or kept in synccbp
            # with replcaement more  suitable for job load
            # $self->set_handle( $out, 'out',
            # ( on => { %$callback{@::cbparamkey} }, %tiearg ) );
            #push $self->$destname->@*, $destref
            # $self->$k->@* = $v;
	    # ...
        }
        elsif ( ref $v eq 'CODE' ) {

            #push $callback->{}->@*, $destref

            push $callback->{ $k =~ s/$FH_SUFFIX_RE//r }{line}->@*, $v;
        }
        elsif ( ref $v eq 'GLOB' ) {

            # File handle is appended to by line with respects to existing
            # binmode
            ...;
        }
    }

    $tie;
}

method $initcb ( $cbhref, %opt ) {

    # $line: called with $line when child writes to STDOUT. this is the same as
    # passing a subroutine as $out
    # $error: called when child writes to STDERR
    # $exiterr, $nonzero: called when chlld exits with a nonzero status
    # $exit: called when the child process exits
    # $eof: called when a handle recieves EOF
    # $ipcfail: called after unrecoverable/unknown IPC errors
    # $success: called when child exits with 0

    foreach my ( $e, $val ) (%$cbhref) {
        if ( none { $e eq $_ } @EVENTLIST ) {
            err "'$e' is not a valid key for '\$on'";
            next;
        }

        if ( $val isa ARRAY ) {
            $$callback{$e} = $val;
        }
        elsif ( $val isa CODE ) {
            $$callback{$e} = [$val];
        }
    }

    $callback;
}

method adjhelper( $in, $out, $err, $on, $tieopt, %opt ) {
    $callback = $self->$initcb( $on, %opt );
    $$tieopt{on} = $callback;
    $self->$inithandles( $in, $out, $err, $tieopt, %opt ) 
}

method $run ( $cmd, %opt ) {
    foreach my ( $name, $ref ) ( %opt{qw(in out err)} ) {
        if ( $ref isa HASH ) {
            foreach my ( $opt, $val )
              ( $ref->%{qw(autochomp autoflush line mode fd)} )
            {
                dynamically $tie->{$ref}{$opt} = $val;
            }
        }
        elsif ( $ref isa ARRAY ) {
            $self->set_handle(
                $ref, $name,
                IPC::Nosh::Mux->mux_defaultopt,
                ( $opt{reuse_config} ? %$constructor : () )
            );
        }
        elsif ( $ref isa GLOB ) {
            ...;
        }
        elsif ( $ref isa CODE ) {

            # $ref->();
            ...;
        }

    }

    # Exec the command with tied handles and collect exit status
    my $ipcfail = run3( $cmd, $in, $out, $err );
    ( $status, $oserr ) = ( $?, $! );

    if ($ipcfail) {
        $_->( $self, ret => $ipcfail, args => [ $cmd, $in, $out, $err ] )
          for $$callback{ipcfail}->@*;
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

method run( $cmd, %opt ) {
    dynamically $constructor = {} unless $opt{reuse_config};

    dynamically $self =
      scalar keys %opt
      ? __PACKAGE__->new( %$constructor, %opt )
      : $self
      unless $opt{use_imported};

    $self->$run( $cmd, %opt )    #, %cli );
}

method tie_handle( $aref, %opt ) {
    my %tiearg = %opt;

    tie @$aref, 'IPC::Nosh::IO::Mux', %tiearg;
}

method set_handle ( $aref, $hid, %opt ) {
    return $self->$hid unless $aref || $aref == $out;

    # my $meth = "${tiekey}h";
    # $self->$meth($aref, %opt)
    $$tie{$hid} = $self->tie_handle( $aref, %opt );
}

method outh ( $aref //= $out, %opt ) {

    $self->set_handle( $aref, 'out', %opt );
}

method errh ( $aref //= $err, %opt ) {
    $self->set_handle( $aref, 'err', %opt );
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

