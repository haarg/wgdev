package WGDev::X;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.0.1';

use Exception::Class (
    'WGDev::X' => {
        description => 'A general WGDev error',
    },
    'WGDev::X::CommandLine' => {
        description => 'An error with the command line.',
        fields => ['usage'],
    },
);

sub WGDev::X::CommandLine::full_message {
    my $self = shift;
    my $message = $self->message;
    if (defined $self->usage) {
        if ($message) {
            $message .= "\n"
        }
        $message .= $self->usage;
    }
    return $message;
}

1;

__END__

=head1 NAME

WGDev::X - WGDev Exceptions

=head1 SYNOPSIS

    use WGDev::X;
    WGDev::X->throw();

=head1 DESCRIPTION

Exceptions for WGDev

=head1 AUTHOR

Graham Knop <haarg@haarg.org>

=head1 LICENSE

Copyright (c) Graham Knop

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut


