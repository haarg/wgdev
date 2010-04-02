package WGDev::X;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.0.1';

use Exception::Class (
    'WGDev::X'              => { description => 'A general WGDev error', },
    'WGDev::X::CommandLine' => {
        isa         => 'WGDev::X',
        description => 'An error with the command line.',
        fields      => ['usage'],
    },
    'WGDev::X::CommandLine::BadCommand' => {
        isa         => 'WGDev::X::CommandLine',
        description => 'An invalid command was requested.',
        fields      => ['command_name'],
    },
    'WGDev::X::BadCommand' => {
        isa         => 'WGDev::X',
        description => 'An invalid command was requested.',
        fields      => ['command_name'],
    },
    'WGDev::X::CommandLine::BadParams' => {
        isa         => 'WGDev::X::CommandLine',
        description => 'Invalid parameters were passed to a command.',
    },
    'WGDev::X::System' => {
        isa         => 'WGDev::X',
        description => 'System error',
        fields      => ['errno_string'],
    },
    'WGDev::X::IO' => {
        isa         => 'WGDev::X::System',
        description => 'IO error',
        fields      => ['path'],
    },
    'WGDev::X::IO::Read' => {
        isa         => 'WGDev::X::IO',
        description => 'Read error',
    },
    'WGDev::X::IO::Write' => {
        isa         => 'WGDev::X::IO',
        description => 'Write error',
    },
    'WGDev::X::NoWebGUIConfig' => {
        isa         => 'WGDev::X',
        description => 'No WebGUI config file available.',
    },
    'WGDev::X::NoWebGUIRoot' => {
        isa         => 'WGDev::X',
        description => 'No WebGUI root directory available.',
    },
    'WGDev::X::BadParameter' => {
        isa         => 'WGDev::X',
        description => 'Bad parameter provided.',
        fields      => [ 'parameter', 'value' ],
    },
    'WGDev::X::AssetNotFound' => {
        isa         => 'WGDev::X',
        description => 'Specified asset not found',
        fields      => ['asset']
    },
    'WGDev::X::BadAssetClass' => {
        isa         => 'WGDev::X',
        description => 'Bad asset class specified',
        fields      => ['class']
    },
);

BEGIN {
    if ( $ENV{WGDEV_DEBUG} ) {
        WGDev::X->Trace(1);
    }
    ##no critic (ProhibitMagicNumbers)
    if ( !eval { Exception::Class->VERSION(1.27) } ) {

        # work around bad behavior of Exception::Class < 1.27
        # where it defaults the message to $!
        *WGDev::X::new = sub {
            my $errno = qq{$!};
            my $class = shift;
            my $self  = $class->SUPER::new(@_);
            if ( $self->{message} eq $errno ) {
                $self->{message} = q{};
            }
            return $self;
        };
    }
}

##no critic (ProhibitQualifiedSubDeclarations)

sub WGDev::X::inflate {
    my $class = shift;
    my $proto = shift;
    if (@_ == 1 && ref $_[0] && $_[0]->can('throw')) {
        $_[0]->throw;
    }
    $class->throw(@_);
}

sub WGDev::X::full_message {
    my $self = shift;
    return $self->message || $self->description;
}

sub WGDev::X::CommandLine::full_message {
    my $self    = shift;
    my $message = $self->message;
    if ( defined $self->usage ) {
        if ($message) {
            $message =~ s/\n+\z/\n\n/msx;
        }
        $message .= $self->usage;
    }
    $message =~ s/\n+\z/\n\n/msx;
    return $message;
}

sub WGDev::X::CommandLine::BadCommand::full_message {
    my $self = shift;
    my $message
        = defined $self->command_name
        ? "Can't find command @{[ $self->command_name ]}!\n"
        : "No command specified!\n";
    if ( defined $self->usage ) {
        $message .= "\n" . $self->usage;
    }
    $message =~ s/\n+\z/\n\n/msx;
    $message
        .= "Try the running 'wgd commands' for a list of available commands.\n\n";
    return $message;
}

sub WGDev::X::System::new {
    my $class        = shift;
    my $errno_string = qq{$!};
    my $self         = $class->SUPER::new(@_);
    if ( !defined $self->errno_string ) {
        $self->{errno_string} = $errno_string;
    }
    return $self;
}

sub WGDev::X::System::full_message {
    my $self    = shift;
    my $message = $self->SUPER::full_message;
    $message .= ' - ' . $self->errno_string;
    return $message;
}

sub WGDev::X::IO::full_message {
    my $self = shift;
    my $message = $self->SUPER::message || $self->description;
    if ( $self->path ) {
        $message .= ' Path: ' . $self->path;
    }
    $message .= ' - ' . $self->errno_string;
    return $message;
}

1;

__DATA__

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

Copyright (c) 2009-2010, Graham Knop

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl 5.10.0. For more details, see the
full text of the licenses in the directory LICENSES.

=cut


