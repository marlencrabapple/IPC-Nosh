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
use Syntax::Keyword::Dynamically;

use IPC::Nosh::IO::Mux;
use IPC::Nosh::IO;

@EXPORT_OK = qw($run);
@EXPORT    = 'run';

field $debug //= $ENV{DEBUG};

field $in  : param = \undef;
field $out : param = [];
field $err : param = [];

field %tie : reader;

ADJUST :params (:$autoflush //= undef, :$autochomp //= undef, :$stdin_passthrough //= undef) {
    $in = undef if $stdin_passthrough;
    
    my %tiearg = (
        autoflush => $autoflush ? 1 : 0
        , autochomp => $autochomp ? 1 : 0);

    dmsg($autoflush, $autochomp, $stdin_passthrough, \%tiearg );

    $self->set_handle($out, 'out', %tiearg);
    $self->set_handle($err, 'err', fd => *STDERR, %tiearg);
}

method $run ($cmd, %opt) {
    run3( $cmd, $in, $out, $err );
    dmsg( $self, \%opt );
    $self
}

method run ( $cmd, %opt ) {
    if($debug && $opt{dynamically} ){
...
    }
    elsif($debug && $opt{accessor}) {
        # foreach my ($k, $v) (%opt{qw(out err)} {
        #     $self->set_handle()
        # }) 
        $self->outh(delete $opt{out}, %opt);
        $self->errh(delete $opt{err}, %opt);
    }
    else {
        dynamically $self = scalar keys %opt ? __PACKAGE__->new(%opt) : $self;
        $self->$run( $cmd, %opt )    #, %cli );
    }
}

method tie_handle($aref, %opt) {
        my %tiearg = (%opt{qw(in out err autoflush autochomp binmode fd)});
        dmsg(\%tiearg);
        tie @$aref, 'IPC::Nosh::IO::Mux', %tiearg;
}

method set_handle ($aref, $hkey, %opt) {
        return $self->$hkey unless $aref || $aref == $out;
        # my $meth = "${tiekey}h";
        # $self->$meth($aref, %opt)
        $tie{$hkey} = $self->tie_handle( $aref, %opt );
}

method outh ( $aref //= $out, %opt ) {

    $self->set_handle($aref, 'out', %opt)
}

method errh ( $aref //= $err, %opt ) {
    $self->set_handle( $aref, 'err', %opt )
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

