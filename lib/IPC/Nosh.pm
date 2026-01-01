use Object::Pad ':experimental(:all)';

package IPC::Nosh;

class IPC::Nosh : isa(IPC::Nosh::IO);

our $VERSION = "0.01";

use base 'Class::Exporter';
use vars '@EXPORT';

use utf8;
use v5.40;

use IPC::Run3;
use IO::Handle;

use IPC::Nosh::IO::Mux;
use IPC::Nosh::IO;

@EXPORT = qw($run run);

# field $cmd = __PACKAGE__;

# field $in  : param : mutator = \undef;
# field $out : param : mutator = [];
# field $err : param : mutator = [];
# field %tie;

field $in = \undef;
field @out;
field @err;
field %tie;

# field %handle = ( in => \$in, out => \$out, err => $err );

ADJUST {
    # our $host = $self;

}

method $run ($cmd) {
    my class IOMux {
    #     use v5.40;
    #     use Tie::Array;

    #     use vars '@ISA';
    #     @ISA = qw(Tie::StdArray);

    #     field $index : param = 0;

    #     #field $aref : param;
    #     field $handle : param //= *STDOUT;
    #     field $mode   : param //= 'w';

    #     ADJUST {
    #         #tie @$aref, 'Tie::StdArray';
    #         $handle = IO::Handle->new_from_fd( fileno($handle), $mode );

    #         # $self->TIEARRAY(@_);
    #         $host->dmsg($self);
    #     }

    #     method PUSH (@LIST) {
    #         writeh( $_, $handle ) for @LIST;

    #         # TODO: benchmark against calling SUPER->PUSH for each elem
    #         Tie::StdArray->PUSH( $self, map { chomp $_; $_ } @LIST );
    #     }

    #     method TIEARRAY : common (%opt) { $class->new(%opt) }

    #     method STORE ( $index, $value ) {
    #         writeh( $value, $handle );
    #         Tie::StdArray->STORE( $index, map { chomp $_; $_ } $value );
    #     }
use v5.40;
use utf8;

use Tie::Array;
use IPC::Nosh::IO;

use vars qw'@ISA @EXPORT @EXPORT_OK';
@ISA = qw'Tie::StdArray';

method PUSH ( @LIST ) {
    $self->{writeh}->( $_, $self->{handle} ) for @LIST;

    # TODO: benchmark against calling SUPER->PUSH for each elem
    Tie::StdArray->PUSH( $self, map { chomp $_; $_ } @LIST );
}

method STORE( $index, $value ) {
    $self->{writeh}->teh( $value, $self->{handle} );
    Tie::StdArray->STORE( $index, map { chomp $_; $_ } $value );
}

method TIEARRAY : common ( @list ) {
    my $self = Tie::StdArray->TIEARRAY(@list);
    dmsg( $self, $class, \@list );


    # $$self{handle} = $opt{handle} // *STDOUT;
    # $$self{mode}   = $opt{mode}   // 'w';

$self
}


    };


    $tie{out} = tie @out, 'IPC::Nosh::IO::Mux';
    $tie{err} = tie @err, 'IPC::Nosh::IO::Mux', handle => *STDERR;

    run3( $cmd, $in, \@out, \@err );
    dmsg($self)
}

method run ( $cmd, %opt ) {

    # ( $in, $out, $err ) //= ( %opt[qw/in out err/] );

    # foreach my ($k)
    #   ( grep { $opt{$_} && ref $opt{$_} } keys %opt{qw/in out err/} )
    # {
    #     $self->$k = $opt{$k};
    # }

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

Copyright(C) Ian P Bradley .

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=head1 AUTHOR

Ian P Bradley E<lt>ian.bradley@studiocrabapple.comE<gt>

=cut

