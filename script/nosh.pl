#!/usr/bin/env perl

use Object::Pad ':experimental(:all)';

package nosh;

class nosh;

use utf8;
use v5.40;

use lib 'lib';

use Getopt::Long
qw(GetOptionsFromArray :config no_ignore_case auto_abbrev passthrough long_prefix_pattern=--?);

use IPC::Nosh 'run';
use IPC::Nosh::IO;

field $argv : param;
field $debug;
field $stdin;
field $autoflush : param = undef;
field $autochomp : param = undef;
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
        'stdin', 'autoflush', 'autochomp',
        '<>' => sub ($barearg) {
            push @cmd, $barearg;
            fatal("--cmd and positional arguments cannot both have values")
              unless scalar @cmd > 0
        }
    );

    @cmd = map { split /\s+/ } @cmd;

    dmsg($self)
}

method nosh ( $asdf = undef, %fdsa ) {
    # my %arg = ()
    # $arg{in} = $stdin
    run( \@cmd, autoflush => $autoflush, autochomp => $autochomp, $stdin ? ( in => undef ) : ())
} 

method cli : common ($argv = \@ARGV, %opt) {
    my $self = $class->new( argv => $argv, %opt );
    $self->nosh;
}

package main;

use utf8;
use v5.40;

nosh->cli( \@ARGV )
