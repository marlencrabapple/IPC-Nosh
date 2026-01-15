#!/usr/bin/env perl

use Object::Pad ':experimental(:all)';

package nosh;

class nosh;

use utf8;
use v5.40;

use lib 'lib';

use Getopt::Long
qw(GetOptionsFromArray :config no_ignore_case auto_abbrev passthrough long_prefix_pattern=--?);

use IPC::Nosh;
use IPC::Nosh::IO;

field $argv : param;
field $debug;
# field $stdin;
field $autoflush : mutator;
field $autochomp : mutator;
field $verbose = 1;
field @barearg;
field $cmd : mutator;

ADJUST { #{ # :params (:$autochomp, :$autoflush) {
    my %clidest = (cmd => []);

    GetOptionsFromArray(
        $argv, \%clidest, 'cmd=s{1,}',
        'verbose+',
        'version',
        'help|?',      'debug+',      #'stdin'
          'autoflush', 'autochomp',
        '<>' => sub ($barearg) {
            push $clidest{cmd}->@*, ( split /\s/, $barearg );
            fatal("--cmd and positional arguments cannot both have values")
                unless scalar $clidest{cmd}->@* > 0
        }
    );

    foreach my ( $k, $v ) (%clidest) {
        $self->$k = $v if $v;
    }

    @$cmd = map { split /\s+/ } @$cmd;

    # dmsg( $autoflush, $autochomp )
}

method nosh ( $asdf = undef, %fdsa ) {
    # dmsg($self);
    run(
        $cmd,

        autoflush => $autoflush,
        autochomp => $autochomp,

        # stdin     => $stdin
      )
}

method cli : common ($argv = \@ARGV) {
    my $self = $class->new( argv => $argv );
    # dmsg($self, $self->autoflush, $self->autochomp);
    $self->nosh;
}

package main;

use utf8;
use v5.40;

nosh->cli( \@ARGV )
