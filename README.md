# NAME

IPC::Nosh - Flexible no-shell IPC interface with IO muxing

# SYNOPSIS

    use IPC::Nosh;

    my $err;

    my $run = run(
        [qw(ls -ltra)],
        out       => path('ls-output.txt'),
        err       => \$err,
        autochomp => 1,
        on        => {
            line => sub ($line) {
                my ( $path, undef ) = split /\s/, $line;
                path($path)->absolute . "\n";
            }
        }
      );

    if ($run->status > 0) {
        fatal($err)
    }

# DESCRIPTION

IPC::Nosh is ...

# LICENSE

Copyright (C) Ian P Bradley.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Ian P Bradley <ian.bradley@studiocrabapple.com>
