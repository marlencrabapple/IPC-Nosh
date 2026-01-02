#!/usr/bin/env perl

use Object::Pad ':experimental(:all)';

package nosh;

class nosh;

use utf8;
use v5.40;

use lib 'lib';

use Getopt::Long
qw(GetOptionsFromArray :config no_ignore_case auto_abbrev long_prefix_pattern=--?);

use IPC::Nosh 'run';
use IPC::Nosh::IO;

field $argv : param;
field $debug = 0;
field $verbose = 1;
field @barearg;
field @cmd;

ADJUST {
    GetOptionsFromArray(
        $argv,
        'cmd=s{1,}', \@cmd,
        'verbose+',
        'version',
        'help|?', 'debug+',
        '<>' => sub ($barearg) {
            push @barearg, $barearg;
        }
    );

    @cmd = map { split /\s+/ } @cmd;

    dmsg($self)
}

method nosh ( $asdf = undef, %fdsa ) {
    run( \@cmd );
}

method cli : common ($argv = \@ARGV, %opt) {
    my $self = $class->new( argv => $argv, %opt );
    $self->nosh;
}

package main;

use utf8;
use v5.40;

nosh->cli( \@ARGV )
