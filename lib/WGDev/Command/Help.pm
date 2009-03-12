package WGDev::Command::Help;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.1.0';

use WGDev::Command::Base;
use Pod::Perldoc;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

sub process {
    my $self = shift;
    my $wgd  = $self->wgd;
    
    my ($command) = $self->arguments or $self->die();
    
    my $command_module = WGDev::Command::_find_cmd_module($command);
    
    if (!$command_module) {
        warn "Unknown command: $command";
        $self->die();
    }
    
    local @ARGV = ($command_module);
    Pod::Perldoc->run();
    
    return 1;
}

sub die {
    my $self = shift;
    my $message = $self->usage();

    $message .= "Try any of the following:\n";
    for my $command ( WGDev::Command->command_list ) {
        $message .= "\twgd help $command\n";
    }
    $message .= "\n";
    warn $message;
    exit 1;
}

1;

__END__

=head1 NAME

WGDev::Command::Help - Displays perldoc help for WGDev command

=head1 SYNOPSIS

    wgd help command

=head1 DESCRIPTION

Displays perldoc page for WGDev command.

More or less equivalent to running

     wgd command --help

Except that the help message is displayed via Pod::Perldoc

=head1 AUTHOR

Patrick Donelan <pat@patspam.com>

=head1 LICENSE

Copyright (c) Patrick Donelan.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

