#!/usr/bin/env perl
package dist;

use v5.40;
no warnings 'experimental::re_strict';
use re 'strict';

use Path::Tiny;
use TOML::Tiny qw'from_toml to_toml';
use CPAN::Mini::Inject;
use IPC::Nosh;
use IO::Handle::Common;
use Getopt::Long
  qw(GetOptionsFromArray :config no_ignore_case auto_abbrev passthrough bundling long_prefix_pattern=--?);

my $verbose            = $ENV{VERBOSE};
my $debug              = $ENV{DEBUG};
my $author_config_file = path("minil.toml");
my $author_config      = from_toml( $author_config_file->slurp_utf8 );
my $package            = ( $$author_config{name} =~ s/-/::/gr );
my $archive;
my $version;

my $trial = grep { $_ eq '--trial' } @ARGV;
$trial //= $$author_config{release_status} ne 'stable' ? 1 : 0;

my $has_suffix;

my $dist_suffix;
$dist_suffix = 'TRIAL' if $trial;

dmsg $author_config, $package, $trial, $dist_suffix;

sub make_dist( $dist, %opt ) {
    my ( $archive, $version, $has_suffix );
    my $test = 0;

    my $run = run(
        [ qw'minil dist', @ARGV ],
        out => sub ( $line, @ ) {
            $test++;
            my $archive_re = qr /^Wrote (($dist)-(.+?)(?:-(TRIAL))?\.tar\.gz)$/;

            dmsg $line, $dist, $archive_re, $test;    #\@arg;

            if ($verbose) {
                my $say = $debug ? __LINE__ . ": $line" : $line;
                say $say;
            }

            # TODO: Add functionality to remove callback when no longer needed
            ( $archive, undef, $version, $has_suffix ) =
              ( $line =~ $archive_re )
              unless $archive && $version;
        },
        err       => sub ( $line, @ ) { say STDERR $line if $verbose },
        autochomp => 1
    );

    dmsg $archive, $version, $has_suffix, $test;

    say join "\n", $run->err->lines_utf8 if $verbose;

    fatal( ( join " ", $run->cmd->@* )
        . " exited with non-zero status: "
          . $run->status )
      if $run->status != 0;

    fatal "Could not parse archive name from '"
      . ( join " ", $run->cmd->@* )
      . "' output."
      unless $archive && $version;

    ( $archive, $version, $has_suffix );
}

sub rename_archive ( $src, $dst ) {
    $archive->move($dst);
}

sub upload_to_cpanm {
    ...;
}

sub dist {

    ( $archive, $version, $has_suffix ) =
      make_dist( $$author_config{name}, trial => $trial );

    dmsg( $archive, $version, $has_suffix );

    $archive = path($archive);

    if (
        my $moved =
          $has_suffix || !$dist_suffix
        ? $archive
        : rename_archive(
            $archive,
            $archive->basename(qr/\.tar\.gz$/) . "-$dist_suffix.tar.gz"
        )
      )
    {
        success "Wrote $moved";
        exit 0;
    }
    else {
        fatal "Something went wrong. ($?)";
        dmsg $archive, $moved;
    }
}

dist()
