#!/usr/bin/env perl

use Object::Pad ':experimental(:all)';

package nosh;

class nosh;

use utf8;
use v5.40;

use lib 'lib';

use Getopt::Long
  qw(GetOptionsFromArray :config no_ignore_case auto_abbrev passthrough long_prefix_pattern=--?);

use List::Util 'all';
use IPC::Nosh;
use IPC::Nosh::IO;

field $argv : param;
field $debug;

# field $stdin;
field $autoflush : mutator;
field $autochomp : mutator;
field $verbose = 1;
field @barearg;
field $cmd : mutator = [];

ADJUST {    #{ # :params (:$autochomp, :$autoflush) {
    my %clidest = ( cmd => $cmd );

    dmsg $cmd;

    GetOptionsFromArray(
        $argv, \%clidest, 'cmd=s{1,}',
        'verbose+',
        'version',
        'help|?', 'debug+',    #'stdin'
        'autoflush',
        'autochomp',
        '<>' => sub ($barearg) {

            push @$cmd, map { split /\s+/, $_ } $barearg;
        }
    );

    foreach my ( $k, $v ) (%clidest) {
        $self->$k = $v if $v;
    }

    # dmsg( $autoflush, $autochomp )
}

method nosh ( $asdf = undef, %fdsa ) {

    # dmsg($self);
    dmsg $self;
    my $run = run(
        $cmd,

        autoflush => $autoflush,
        autochomp => $autochomp,

        # stdin     => $stdin
    );
    dmsg $self, $run;
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
