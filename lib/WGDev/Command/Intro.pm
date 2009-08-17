package WGDev::Command::Intro;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.0.1';

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

sub needs_root {
    return;
}

sub process {
    my $self = shift;
    return $self->help;
}

1;

__END__

=head1 NAME

WGDev::Command::Intro - Introduction to WGDev

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
the WEBGUI_ROOT and WEBGUI_CONFIG environment variables, setting
the command.webgui_root and command.webgui_config options, using
command line paramters, or relying on auto-detection.

Auto-detection works by searching upward from the current directory
for a valid WebGUI directory, and if there is only one site config
file, using it.

With the root and config set or otherwise specified, you can use
any of the WGDev commands.

=head1 GETTING HELP

A summary of a command's options is available by using the --help
option.  Full documentation is available using the help command.

=head1 COMMON COMMANDS

=head2 C<< wgd edit <url> >>

Edits the specified asset in your prefered text editor.  When you
exit the editor, the asset on the WebGUI site will be updated with
the new data.

=head2 C<< wgd package <url> >>

The package command will generate a package for asset specified.
Additionally, the --import option allows you to import package
files.

=head2 C< wgd reset --dev >

Resets a site to its defaults and sets it up for development.  The
site started is disabled, leaving the admin login with the default
password of 123qwe.  Additionally, all of the default example content
is cleared from the site giving you a blank slate to work from.

=head2 C< wgd reset --build >

Resets a site it its defaults and prepares it to generate a site
creation script.  The site starter is enabled, and old version tags
and revisions of content are cleaned up.

=head2 C< wgd db >

Starts the C<mysql> client in the site's database, using the login
information from the site config file.

=head1 AUTHOR

Graham Knop <graham@plainblack.com>

=head1 LICENSE

Copyright (c) Graham Knop.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

