package WGDev::X;
# ABSTRACT: WGDev Exceptions
use strict;
use warnings;
use 5.008008;

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
        fields      => ['asset'],
    },
    'WGDev::X::BadAssetClass' => {
        isa         => 'WGDev::X',
        description => 'Bad asset class specified',
        fields      => ['class'],
    },
    'WGDev::X::UserNotFound' => {
        isa         => 'WGDev::X',
        description => 'Specified user not found',
        fields      => ['userId'],
    },
    'WGDev::X::Module' => {
        isa         => 'WGDev::X',
        description => 'Error loading module',
        fields      => ['module', 'using_module'],
    },
    'WGDev::X::Module::Find' => {
        isa         => 'WGDev::X::Module',
        description => q{Can't find module},
    },
    'WGDev::X::Module::Parse' => {
        isa         => 'WGDev::X::Module',
        description => q{Error compiling module},
    },
    'WGDev::X::BadPackage' => {
        isa         => 'WGDev::X',
        description => q{Error importing a package},
        fields      => ['message', 'package'],
    },
);

BEGIN {
    if ( $ENV{WGDEV_DEBUG} ) {
        WGDev::X->Trace(1);
    }
}

##no critic (ProhibitQualifiedSubDeclarations)

sub _format_file_as_module {
    my $file = shift;
    if ($file =~ s/[.]pm$//msx) {
        $file =~ s{/}{::}msxg;
    }
    return $file;
}

sub WGDev::X::inflate {
    my $class = shift;
    if (@_ == 1 && ref $_[0] && $_[0]->can('throw')) {
        $_[0]->throw;
    }
    if (@_ == 1 && !ref $_[0]) {
        my $e = shift;
        ##no critic (ProhibitComplexRegexes);
        if ($e =~ m{
            \ACan't[ ]locate[ ](.*?)[ ]in[ ][@]INC[ ]
            .*[ ]at[ ](.*?)[ ]line[ ]\d+[.]
        }msx) {
            my $module = $1;
            my $using_module = $2;
            $module = _format_file_as_module($module);
            $using_module = _format_file_as_module($using_module);
            WGDev::X::Module::Find->throw(message => $e, module => $module, using_module => $using_module);
        }
        elsif ( $e =~ s{
            (at[ ](.*?)[.]pm[ ]line[ ]\d+[.])
            \s+Compilation[ ]failed[ ]in[ ]require[ ]at[ ]
            (.*?)[ ]line[ ]\d+[.].*?\z
        }{$1}msx ) {
            my $module = $2;
            my $using_module = $3;
            $module = _format_file_as_module($module);
            $using_module = _format_file_as_module($using_module);
            WGDev::X::Module::Parse->throw(message => $e, module => $module, using_module => $using_module);
        }
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
            $message =~ s/[\n\r]*\z/\n\n/msx;
        }
        $message .= $self->usage;
    }
    $message =~ s/[\n\r]*\z/\n\n/msx;
    return $message;
}

sub WGDev::X::BadParameter::full_message {
    my $self = shift;
    my $message = $self->SUPER::message || $self->description;
    if ( $self->parameter ) {
        $message .= q{ } . $self->parameter;
    }
    if ( $self->value ) {
        $message .= q{: } . $self->value;
    }
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
    $message =~ s/[\n\r]*\z/\n\n/msx;
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

sub WGDev::X::AssetNotFound::full_message {
    my $self = shift;
    my $message = $self->SUPER::full_message;
    if ( $self->asset ) {
        $message .= ' - ' . $self->asset;
    }
    return $message;
}

sub WGDev::X::UserNotFound::full_message {
    my $self = shift;
    my $message = $self->SUPER::full_message;
    if ( $self->userId ) {
        $message .= ' FATAL ERROR: User not found - ' . $self->userId;
    }
    return $message;
}

sub WGDev::X::Module::full_message {
    my $self = shift;
    my $message = $self->description . q{ } . $self->module
        . q{ for } . $self->using_module . ":\n" . $self->SUPER::message;
    $message =~ s/[\n\r]*\z/\n\n/msx;
    return $message;
}

sub WGDev::X::Module::Find::full_message {
    my $self = shift;
    my $message = $self->description . q{ } . $self->module
        . q{ for } . $self->using_module;
    $message =~ s/[\n\r]*\z/\n\n/msx;
    return $message;
}

1;

=head1 SYNOPSIS

    use WGDev::X;
    WGDev::X->throw();

=head1 DESCRIPTION

Exceptions for WGDev

=cut

