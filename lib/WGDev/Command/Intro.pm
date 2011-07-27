package WGDev::Command::Intro;
# ABSTRACT: Introduction to WGDev
use strict;
use warnings;
use 5.008008;

use parent qw(WGDev::Command::Base);

sub needs_root {
    return;
}

sub process {
    my $self = shift;
    return $self->help;
}

1;

=head1 SYNOPSIS

    wgd edit default_article
    wgd package home
    wgd reset --build
    wgd reset --dev
    wgd db

=head1 DESCRIPTION

WGDev provides a variety of commands useful for WebGUI developers.

=head1 GETTING STARTED

The first step in using WGDev is getting it to find your WebGUI
root directory and site config file.  For this, you can either use
the C<WEBGUI_ROOT> and C<WEBGUI_CONFIG>/C<WEBGUI_SITENAME> environment
variables, setting the C<command.webgui_root> and
C<command.webgui_config>/C<command.webgui_sitename> options via the
L<config command|WGDev::Command::Config>, using command line
parameters (see C<wgd help>), or (for the root path) relying on
auto-detection.

Auto-detection works by searching upward from the current directory
for a valid WebGUI directory.  The config file cannot be detected
and must be specified.

The WebGUI config file can be specified relative to the current
directory, relative to WebGUI's etc directory, or as an absolute
path.

Once you have the root and config file set or otherwise specified,
you can use any of the WGDev commands.

=head1 GETTING HELP

A summary of a command's options is available by running the command
with the C<--help> option.  Full documentation is available using
the C<wgd help> command.  A full list of available commands is
available by running C<wgd commands>.

=head1 SPECIFYING ASSETS

When specifying assets as parameters to commands, either an asset
URL or an asset ID can be specified.  Some commands will also accept
a class name, treating it as an new asset of that type.

=head1 COMMON COMMANDS

=head2 C<< wgd edit <asset> >>

Edits the specified asset in your prefered text editor.  When you
exit the editor, the asset on the WebGUI site will be updated with
the new data.  Multiple assets can be specified.

=head2 C<< wgd package <asset> >>

The package command will generate a package for asset specified.
Additionally, the --import option allows you to import package
files, and --upgrade will export a package and put it into the correct
package directory for the next WebGUI release.  Multiple assets can
be specified.

=head2 C<wgd reset --dev>

Resets a site to its defaults and sets it up for development.  The
site started is disabled, leaving the admin login with the default
password of C<123qwe>.  Additionally, all of the default example
content is cleared from the site giving you a blank slate to work
from.

=head2 C<wgd reset --build>

Resets a site it its defaults and prepares it to generate a site
creation script.  The site starter is enabled, and old version tags
and revisions of content are cleaned up.

=head2 C<wgd db>

Starts the C<mysql> client in the site's database, using the login
information from the site config file.

=head2 C<< wgd export <asset> >>

Exports assets to files. You can export to standard out by using
the C<--stdout> option.  Multiple assets can be specified.

=cut

