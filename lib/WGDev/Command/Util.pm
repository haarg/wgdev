package WGDev::Command::Util;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.1.0';

use WGDev::Command::Base::Verbosity;
BEGIN { our @ISA = qw(WGDev::Command::Base::Verbosity) }

use File::Spec ();

sub config_parse_options { return qw(gnu_getopt pass_through) }

sub process {
    my $self = shift;
    my $wgd  = $self->wgd;

    $wgd->set_environment;

    my @args    = $self->arguments;
    my $command = shift @args;

    unshift @args, '--configFile=' . $wgd->config_file_relative;

    my $sbin_path = File::Spec->catdir( $wgd->root, 'sbin' );

    if ( -e $command ) {
        $command = File::Spec->rel2abs($command);
    }
    elsif ( -e File::Spec->rel2abs( $command, $sbin_path ) ) {
        $command = File::Spec->rel2abs( $command, $sbin_path );
    }
    else {
        WGDev::X->throw("Unable to find $command.");
    }

    if ( !-x $command ) {
        unshift @args, $command;

        # $^X is the name of the current perl executable
        $command = $^X;
    }

    my $pid = fork;
    if ( !$pid ) {
        if ( $self->verbosity < 1 ) {
            ##no critic (RequireCheckedOpen)
            open STDIN,  '<', File::Spec->devnull;
            open STDOUT, '>', File::Spec->devnull;
            open STDERR, '>', File::Spec->devnull;
        }
        chdir $sbin_path;
        exec {$command} $command, @args;
    }
    waitpid $pid, 0;

    # $? is the child's exit value
    return $? ? 0 : 1;
}

1;

__DATA__

=head1 NAME

WGDev::Command::Util - Run a utility script

=head1 SYNOPSIS

    wgd util [-q] <command>

=head1 DESCRIPTION

Runs a utility script.  The script will be run from WebGUI's sbin
directory, and will be passed a --configFile option.

=head1 OPTIONS

Any options not handled by this command are passed to the utility script.

=over 8

=item C<-q> C<--quiet>

If specified, will silence all output from the utility script.

=back

=head1 AUTHOR

Graham Knop <haarg@haarg.org>

=head1 LICENSE

Copyright (c) 2009-2010, Graham Knop

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl 5.10.0. For more details, see the
full text of the licenses in the directory LICENSES.

=cut

