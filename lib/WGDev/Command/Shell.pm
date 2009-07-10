package WGDev::Command::Shell;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.0.1';

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

sub config_options {
    return qw(
        all|A
    );
}

sub process {
    my $self = shift;
    my $wgd  = $self->wgd;
    require WGDev::Command;
    require Term::ReadLine;
    require Text::ParseWords;

    my $term = new Term::ReadLine->new('WebGUI Developer Shell');
    my $add_history = $term->can('AddHistory');
    my $prompt = 'WGsh >';
    while ( defined (my $line = $term->readline($prompt)) ) {
        my $result;
        if ($line =~ /^\s*$/) {
            next;
        }
        if ($add_history) {
            $term->AddHistory($line);
        }
        if ($line =~ s/^!//) {
            $result = ! system $line;
        }
        else {
            my @line = Text::ParseWords::shellwords($line);
            my $command = shift @line;
            next
                if !defined $command || $command eq q{};
            eval {
                if ($command =~ /^(?:q|quit|exit)$/i) {
                    last;
                }
                if ($self->can('command_' . $command) {
                    my $method = 'command_' . $command;
                    $result = $self->$method(@line);
                }
                elsif ( my $command_module = WGDev::Command::get_command_module($command) ) {
                    $result = $command_module->run(@line);
                }
                else {
                    warn "Unable to find command $command!\n";
                }
            };
            if ($@) {
                warn $@;
            }
        }
    }
    return 1;
}

1;

__END__

=head1 NAME

WGDev::Command::Shell - WGDev Shell

=head1 SYNOPSIS

    wgd shell

=head1 DESCRIPTION

This is a sample command.

=head1 OPTIONS

=over 8

=back

=head1 AUTHOR

Graham Knop <graham@plainblack.com>

=head1 LICENSE

Copyright (c) Graham Knop.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

