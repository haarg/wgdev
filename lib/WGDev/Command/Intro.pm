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
root directory and site config file.

=head1 AUTHOR

Graham Knop <graham@plainblack.com>

=head1 LICENSE

Copyright (c) Graham Knop.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

