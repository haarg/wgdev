package WGDev::Command::Help;
# ABSTRACT: Displays perldoc help for WGDev command
use strict;
use warnings;
use 5.008008;

use WGDev::Command::Base ();
BEGIN { our @ISA = qw(WGDev::Command::Base) }

use WGDev::Command ();
use WGDev::X       ();

sub needs_root {
    return;
}

sub process {
    my $self = shift;
    my $wgd  = $self->wgd;

    my ($command) = $self->arguments;
    if ( !defined $command ) {
        print WGDev::Command->usage(1);
        return 1;
    }

    my $command_module;
    if ( $command eq 'wgd' ) {
        $command_module = 'WGDev::Command';
    }
    else {
        $command_module = WGDev::Command->get_command_module($command);
    }

    if ( !$command_module ) {
        WGDev::X::CommandLine::BadCommand->throw(
            usage        => $self->usage,
            command_name => $command,
        );
    }

    if ( $command_module->can('help') ) {
        return $command_module->help;
    }

    require WGDev::Help;
    if (
        eval {
            WGDev::Help::package_perldoc( $command_module,
                '!AUTHOR|LICENSE|METHODS|SUBROUTINES' );
            1;
        } )
    {
        return 1;
    }
    return;
}

1;

=head1 SYNOPSIS

    wgd help <command>

=head1 DESCRIPTION

Displays C<perldoc> page for WGDev command.

More or less equivalent to running

     wgd command --help

Except that the help message is displayed via Pod::Perldoc

=head1 OPTIONS

=over 8

=item C<< <command> >>

The sub-command to display help information about.

=back

=cut

