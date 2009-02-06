package WGDev::Command::Run;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.0.1';

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

sub process {
    my $self = shift;
    $self->wgd->set_environment;
    exec $self->arguments;
}

sub parse_params {
    my ( $self, @args ) = @_;
    @{ $self->{arguments} } = @args;
    return 1;
}

1;

__END__

=head1 NAME

WGDev::Command::Run - Run arbitrary shell command

=head1 SYNOPSIS

wgd run <command>

=head1 DESCRIPTION

Runs an arbitrary command, but sets the WEBGUI_CONFIG, WEBGUI_ROOT, and
PERL5LIB environment variables first.

=head1 OPTIONS

Has no options of its own.  All options are passed on to specified command.

=head1 AUTHOR

Graham Knop <graham@plainblack.com>

=head1 LICENSE

Copyright (c) Graham Knop.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

