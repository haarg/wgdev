package WGDev::Command::Run;
use strict;
use warnings;

our $VERSION = '0.0.1';
use File::Spec;

sub run {
    my $class = shift;
    my $wgd = shift;
    exec @_;
}

sub usage {
    my $class = shift;
    return __PACKAGE__ . "\n" . <<'END_HELP';

Runs parameters as a command.  Does nothing extra but providing the WEBGUI_ROOT and WEBGUI_CONFIG environment variables.

arguments:
    none        All arguments are forwarded to the command run

END_HELP
}

1;

