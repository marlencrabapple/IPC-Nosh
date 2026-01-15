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
use List::Util 'mesh';
use Syntax::Keyword::Dynamically;

use IPC::Nosh::IO::Mux;
use IPC::Nosh::IO;

# @EXPORT_OK = qw($run);
@EXPORT = 'run';

const our @cbparamkey =>
  qw'line error exiterr nonzero exit eof ipcfail success';
const our $fh_suffix_re => qr/h$/;

field $constructor;

field $same_instance : param(use_imported) = 0;
field $debug //= $ENV{DEBUG};

field $in  : param = \undef;
field $out : param = [];
field $err : param = [];

field $handle_aref;
field $handle_fh;
field $handle_coderef;

field $callback = {};

field %tie : reader;

ADJUST : params (
    : $autoflush         //= undef,
    : $autochomp         //= undef,
    : $stdin_passthrough //= undef,
    : $on = {}
  )
{
    $in = undef
      if $stdin_passthrough;

    @$callback{@::cbparamkey} =
      map { $$on{$_} isa ARRAY ? $$on{$_}->@* : [ $$on{$_} // () ] }
      @$on{@::cbparamkey};

    my %tiearg = (
        autoflush => $autoflush ? 1 : 0,
        autochomp => $autochomp ? 1 : 0
    );

    $tiearg{on} = %$callback{@::cbparamkey};

    # $line: called with $line when child writes to STDOUT. this is the same as
    # passing a subroutine as $out
    # $error: called when child writes to STDERR
    # $exiterr, $nonzero: called when chlld exits with a nonzero status
    # $exit: called when the child process exits
    # $eof: called when a handle recieves EOF
    # $ipcfail: called after unrecoverable/unknown IPC errors
    # $success: called when child exits with 0

    $self->set_handle( $out, 'out', %tiearg );
    $self->set_handle(
        $err, 'err',
        fd => *STDERR,
        %tiearg
    );

    $constructor = {
        stdin_passthrough => $stdin_passthrough,
        autochomp         => $autochomp,
        autoflush         => $autoflush,
        in                => $in,
        out               => $out,
        err               => $err
    };

    foreach my ( $k, $v ) ( mesh [qw(inh outh errh)], [ $in, $out, $err ] ) {
        if ( ref $v eq 'ARRAY' ) {

            # Used as backing storage or kept in sync
            # with replcaement more  suitable for job load
            # $self->set_handle( $out, 'out',
            # ( on => { %$callback{@::cbparamkey} }, %tiearg ) );
            #push $self->$destname->@*, $destref
            # $self->$k->@* = $v;
        }
        elsif ( ref $v eq 'CODE' ) {

            #push $callback->{}->@*, $destref
            push $callback->{ $k =~ s/h$//r }{line}->@*, $v;
        }
        elsif ( ref $v eq 'GLOB' ) {

            # File handle is appended to by line with respects to existing
            # binmode
            ...;
        }
    }
}

method $run ( $cmd, %opt ) {
    foreach my ( $name, $ref ) ( %opt{qw(in out err)} ) {
        if ( $ref isa HASH ) {
            foreach my ( $opt, $val )
              ( $ref->%{qw(autochomp autoflush line mode fd)} )
            {
                dynamically $tie{$ref}->$opt = $val;
            }
        }
        elsif ( $ref isa ARRAY ) {
            $self->set_handle(
                $ref, $name,
                IPC::Nosh::Mux->mux_default,
                ( $opt{reuse_config} ? %$constructor : () )
            );
        }
        elsif ( $ref isa GLOB ) {
            ...;
        }

    }

    my $ipcfail = run3( $cmd, $in, $out, $err );
    my ( $status, $oserr ) = ( $?, $! );

    if ($ipcfail) {
        $_->( $self, ret => $ipcfail, args => [ $cmd, $in, $out, $err ] )
          for $$callback{ipcfail}->@*;
    }

    if ( $status == 0 ) {
        $_->($status) for $$callback{success}->@*;
    }
    else {
        $_->(
            $self,
            exit => { status => $status, os_errno => $oserr },
            args => [ $cmd, $in, $out, $err ]
        ) for $$callback{ipcfail}->@*;
    }

    $self
}

method run ( $cmd, %opt ) {
    dynamically $constructor = {} unless $opt{reuse_config};

    dynamically $self = scalar keys %opt
      ? __PACKAGE__->new(%$constructor, %opt)
      : $self unless $opt{use_imported};
      
    $self->$run( $cmd, %opt )    #, %cli );
}

method tie_handle( $aref, %opt ) {
    my %tiearg = %opt;
    dmsg( $aref, \%opt, \%tiearg );
    tie @$aref, 'IPC::Nosh::IO::Mux', %tiearg;
}

method set_handle ( $aref, $hid, %opt ) {
    return $self->$hid unless $aref || $aref == $out;

    # my $meth = "${tiekey}h";
    # $self->$meth($aref, %opt)
    $tie{$hid} = $self->tie_handle( $aref, %opt );
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

