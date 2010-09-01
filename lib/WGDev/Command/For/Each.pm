package WGDev::Command::For::Each;
use strict;
use warnings;
use 5.008008;

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{commands} = [];
    return $self;
}

sub needs_config {
    return;
}

sub needs_root {
    return 1;
}

sub config_options {
    return (
        shift->SUPER::config_options, qw(
            exec|e=s
            print|p:s
            print0|0:s
            wgd|c|w=s

            force|f
            ) );
}

sub option_exec {
    my $self = shift;
    my ($command) = @_;
    push @{ $self->{commands} },
        command_exec => [$command];
}

sub option_print {
    my $self = shift;
    my $format = shift;
    push @{ $self->{commands} },
        command_print => [
            format => $format,
        ];
}

sub option_print0 {
    my $self = shift;
    my $format = shift;
    push @{ $self->{commands} },
        command_print => [
            separator => "\0",
            format => $format,
        ];
}

sub option_wgd {
    my $self = shift;
    my ($command) = @_;
    push @{ $self->{commands} },
        command_wgd => [$command];
}

sub command_print {
    my $self = shift;
    my %options = @_;
    my $separator = $options{separator} || "\n";
    my $format = $options{format} || '%s';
    $format .= $separator;
    printf $format, $self->wgd->config_file;
    return 1;
}

sub command_exec {
    my $self = shift;
    my $command = shift;
    local %ENV = %ENV;
    $self->wgd->set_environment(localized => 1);
    system $command
        and WGDev::X::System->throw('Error running shell command.');
    return 1;
}

sub command_wgd {
    my $self = shift;
    my $command = shift;
    my $wgd = $self->wgd;
    require Text::ParseWords;

    my @command_line = (
        '-R' . $wgd->root,
        '-F' . $wgd->config_file,
        Text::ParseWords::shellwords($command),
    );

    return WGDev::Command->run(@command_line);
}

sub process {
    my $self = shift;

    my @commands = @{ $self->{commands} };
    my $force = $self->option('force');
    if (! @commands ) {
        @commands = (command_print => []);
    }

    my $root = $self->wgd->root;
    SITES: for my $config ( $self->wgd->list_site_configs ) {
        my $wgd = eval { WGDev->new( $root, $config ) };
        if ( $wgd ) {
            local $self->{wgd} = $wgd;
            COMMANDS: for (my $i = 0; $i <= $#commands; $i += 2) {
                my $command = $commands[$i];
                my @params = @{ $commands[$i + 1] };
                my $success = eval {
                    $self->$command(@params) || 1;
                };
                if ( $success ) {
                    # nothing
                }
                elsif ( $force ) {
                    warn $@;
                }
                else {
                    WGDev::X->inflate($@);
                }
            }
        }
        elsif ($force) {
            warn $@;
        }
        else {
            WGDev::X->inflate($@);
        }
    }

    return 1;
}

1;

__DATA__

=head1 NAME

WGDev::Command::For::Each - Run command for each available config file

=head1 SYNOPSIS

    wgd for-each [ --print0 | --exec=command ] [ -f ]

=head1 DESCRIPTION

Runs a command for each available WebGUI config file.  By default,
the names of the config files will be output.

=head1 OPTIONS

=over 8

=item C<-f> C<--force>

Continue processing config files if there is an error

=item C<-0> C<--print0[=format]>

Prints the config file name followed by an ASCII NUL character
instead of a carriage return.

An optional printf formatting string can be specified.

=item C<-p> C<--print[=format]>

Prints the config file name.  This is the default option if no other
options are specified.

An optional printf formatting string can be specified.


=item C<-e> C<--exec=>

Runs the given command using the shell for each config file.  The
WEBGUI_ROOT and WEBGUI_CONFIG environment variables will be set
while this command is run.

=item C<-w> C<-c> C<--wgd=>

Runs the given WGDev command for each config file.

=back

=head1 AUTHOR

Graham Knop <haarg@haarg.org>

=head1 LICENSE

Copyright (c) 2010, Graham Knop

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl 5.10.0. For more details, see the
full text of the licenses in the directory LICENSES.

=cut

