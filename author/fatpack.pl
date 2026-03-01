#!/usr/bin/env perl

use utf8;
use v5.40;

use lib 'lib';

use Cwd 'abs_path';
use File::chdir;
use Path::Tiny;
use Getopt::Long qw(GetOptionsFromArray :config no_ignore_case auto_abbrev);

use IPC::Nosh;
use IPC::Nosh::IO;

our $modroot  = path(abs_path);
our @input    = ( path("$modroot/script") );
our $outdir   = path("./bin");
our $outfn    = "%s";
our $locallib = path("$modroot/local");
our $verbose  = 1;
our $debug    = $verbose;

our $patharg = sub ( $arg, %opt ) {
    $arg = path($arg)->assert(
        sub {
            $opt{assert} && $opt{assert} isa CODE ? $opt{assert}->(@_) : 1;
        }
    ) unless $arg isa Path::Tiny;

    if ( my $dest = $opt{dest} ) {
        if ( my $type = ref $dest ) {
            if ( $type eq 'ARRAY' ) {
                push @$dest, $arg;
            }
            elsif ( $type eq 'SCALAR' ) {
                $$dest = $arg;
            }
        }
        else {
            fatal '$dest must be a SCALAR, ARRAY, or CODE reference!';
            dmsg( $arg, $dest );
        }
    }
};

our %clidest = (
    modroot => \$modroot,
    input   => sub {
        $patharg->( shift, assert => sub { shift->exists } );
    },
    outdir   => \$outdir,
    outfn    => \$outfn,
    locallib => \$locallib,
    verbose  => \$verbose,
    debug    => \$debug
);

GetOptions(
    \%clidest,
    'input|file|infile|infname|script=s{,}',
    'outdir|fatpack-out=s',
'outfn|out-fname|outfilename|out-filename|fnfmt|fmtfn|fmt-filename|fmt-outputfn=s',
    'modroot|module-root|module-dir=s',
    'locallib=s{,}',
    'verbose+',
    'debug',
    '<>' => sub ($in) { push @input, $patharg->($in) }
);

dmsg(
    my $cliopt = {
        map {
            my $ref = ref $clidest{$_};
            ( $_ => ( $ref eq "SCALAR" ? $clidest{$_}->$* : $clidest{$_} ) )
        } ( keys %clidest )
    }
);

sub fatpack {
    $CWD = $modroot;
    run( [qw(carton install)], out => [] );

    #run( [qw(carton vendor)] );
    #run( [qw(carmel)] );

    $ENV{PERL5LIB} = "$locallib:$modroot/lib";

    $outdir->mkdir unless -d $outdir;

    foreach my $in ( map { $_->is_dir ? ( $_->children ) : $_ } @input ) {

        #fatpack($in->children) if $in->is_dir;
        my @fatlines;
        my $fatstr = "";
        my @cmd    = ( qw(fatpack pack), $in );

        binmode STDERR, ":encoding(UTF-8)";
        info( "Running " . join " ", @cmd );

        run( \@cmd, out => \@fatlines, autoflush => 1, autochomp => 1 );

        $fatstr = join "\n", @fatlines;

        my $fatout = sprintf(
            ( $outfn || '%s.fat' ),
            ( s/^(.+)(?:\.pl)?$/$1/rg =~ $in->basename )
        );

        dmsg $in, $outfn, $fatout;

        if ( my ($ext) = $in->basename =~ /\.(pl)$/i ) {
            $fatout .= ".$ext";
        }

        path("$outdir/$fatout")->spew_utf8($fatstr);

        success("Written to $fatout");
    }
}

fatpack()

