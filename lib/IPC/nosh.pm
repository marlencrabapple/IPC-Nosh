use Object::Pad ':experimental(:all)';

package IPC::nosh;

class IPC::nosh 0.01;

our $VERSION = "0.01";

use base 'Class::Exporter';
use vars '@EXPORT';

use utf8;
use v5.40;

use IPC::Run3;
use IO::Handle;
use IPC::nosh::Common;

@EXPORT = qw($run run);

field $cmd = __PACKAGE__;
field $in  : param = \undef;
field $out : param = [];
field $err : param = [];

field %handle = ( in => \$in, out => \$out, err => $err );

ADJUST {
    my class TieArrayStd {
        use v5.40;
        use Tie::Array;

        use vars '@ISA';
        @ISA = qw(Tie::StdArray);

        field $handle : param //= *STDOUT;
        field $mode   : param //= 'w';
        field $aref   : param = [];

        ADJUST {
            tie @$aref, 'Tie::StdArray';
            $handle = IO::Handle->new_from_fd( fileno($handle), $mode );
        }

        method PUSH (@LIST) {
            $self->writeh( $_, $handle ) for @LIST;
            SUPER->PUSH( $self, @LIST );
        }

        method TIEARRAY { SUPER->TIEARRAY( $self, @_ ) }

        method STORE ( $index, $value ) {

            $self->writeh( $value, $handle );
            SUPER->STORE( $index, $value );
        }
    };

    TieArrayStd->new( aref => $out );
    TieArrayStd->new( aref => $err, handle => *STDERR );
}

method $run ($cmd) {
    run3( $cmd, $in, $out, $err );
}

method run ( $cmd, %opt ) {
    ( $in, $out, $err ) //= %opt{qw/in out err/};

    # my $self = $class->new( in => $_in, out => $_out, err => $_err );
    $self->$run($cmd);
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

Copyright (C) Ian P Bradley.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Ian P Bradley E<lt>ian.bradley@studiocrabapple.comE<gt>

=cut

