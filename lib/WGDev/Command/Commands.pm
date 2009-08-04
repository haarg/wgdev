package WGDev::Command::Commands;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.0.1';

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

use WGDev::Command;
use WGDev::Help;

sub needs_root {
    return;
}

sub process {
    my $self = shift;
    return $self->help;
}

sub help {
    my $class = shift;
    print "Sub-commands available:\n";
    my %abstracts = $class->command_abstracts;
    for my $command ( sort keys %abstracts ) {
        my $command_abstract = $abstracts{$command} || '(external command)';
        printf "    %-15s - %s\n", $command, $command_abstract;
    }
    return 1;
}

sub command_abstracts {
    my $class = shift;
    my %abstracts = map { $_ => undef } WGDev::Command->command_list;
    require Pod::PlainText;
    my $parser = Pod::PlainText->new( indent => 0, width => 1000 );
    $parser->select('NAME');
    for my $command ( keys %abstracts ) {
        my $command_module = eval { WGDev::Command::get_command_module($command) };
        next
            if !$command_module;
        my $pod           = WGDev::Help::package_pod($command_module);
        my $formatted_pod = q{};
        open my $pod_in, '<', \$pod
            or die "Can't open file handle to scalar : $!";
        open my $pod_out, '>', \$formatted_pod
            or die "Can't open file handle to scalar : $!";
        $parser->parse_from_filehandle( $pod_in, $pod_out );
        close $pod_in  or die "Can't open file handle to scalar : $!";
        close $pod_out or die "Can't open file handle to scalar : $!";
        if ( $formatted_pod =~ /^ [:\w]+ \s* - \s* (.+?) \s* $/msx ) {
            $abstracts{$command} = $1;
        }
    }
    return %abstracts;
}

1;

__END__

=head1 NAME

WGDev::Command::Commands - List WGDev sub-commands

=head1 SYNOPSIS

    wgd commands

=head1 DESCRIPTION

Provides an overview of the available WGDev commands.

=head1 OPTIONS

None

=head1 METHODS

=head2 C<command_abstracts>

A class method which returns a hash with keys of the available
commands and values of the module abstract extracted from POD.

=head1 AUTHOR

Graham Knop <graham@plainblack.com>

=head1 LICENSE

Copyright (c) Graham Knop.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

