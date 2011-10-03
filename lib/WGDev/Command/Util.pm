package WGDev::Command::Util;
# ABSTRACT: Run a utility script
use strict;
use warnings;
use 5.008008;

use parent qw(WGDev::Command::Base::Verbosity);

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

=head1 SYNOPSIS

    wgd util [-q] <command>

=head1 DESCRIPTION

Runs a utility script.  The script will be run from WebGUI's F<sbin>
directory, and will be passed a C<--configFile> option.

=head1 OPTIONS

Any options not handled by this command are passed to the utility script.

=over 8

=item C<-q> C<--quiet>

If specified, will silence all output from the utility script.

=back

=cut

