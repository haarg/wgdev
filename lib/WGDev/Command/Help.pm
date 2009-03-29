package WGDev::Command::Help;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.1.0';

use WGDev::Command::Base ();
BEGIN { our @ISA = qw(WGDev::Command::Base) }
use WGDev::Command ();

sub process {
    my $self = shift;
    my $wgd  = $self->wgd;

    my ($command) = $self->arguments or $self->error_with_list;

    my $command_module = WGDev::Command::get_command_module($command);

    if ( !$command_module ) {
        warn "Unknown command: $command\n";
        $self->error_with_list;
    }

    require WGDev::Help;
    if ( eval { WGDev::Help::package_perldoc($command_module); 1 } ) {
        return 1;
    }
    return;
}

sub error_with_list {
    my $self    = shift;
    my $message = $self->usage;

    $message .= "Try any of the following:\n";
    for my $command ( WGDev::Command->command_list ) {
        $message .= "\twgd help $command\n";
    }
    $message .= "\n";
    ##no critic (RequireCarping)
    die $message;
}

1;

__END__

=head1 NAME

WGDev::Command::Help - Displays C<perldoc> help for WGDev command

=head1 SYNOPSIS

    wgd help <command>

=head1 DESCRIPTION

Displays C<perldoc> page for WGDev command.

More or less equivalent to running

     wgd command --help

Except that the help message is displayed via Pod::Perldoc

=head1 OPTIONS

=over 8

=item C<E<lt>commandE<gt>>

The sub-command to display help information about.

=back

=head1 AUTHOR

Patrick Donelan <pat@patspam.com>

=head1 LICENSE

Copyright (c) Patrick Donelan.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

