package WGDev::Command::Base;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.0.1';

sub is_runnable {
    my $class = shift;
    return $class->can('process');
}

sub new {
    my ( $class, $wgd ) = @_;
    my $self = bless {
        wgd       => $wgd,
        options   => {},
        arguments => [],
    }, $class;
    return $self;
}

sub wgd { return $_[0]->{wgd} }

sub parse_params {
    my $self = shift;
    local @ARGV = @_;
    require Getopt::Long;
    Getopt::Long::Configure( 'default', $self->option_parse_config );
    my $result
        = Getopt::Long::GetOptions( $self->{options}, $self->option_config );
    @{ $self->{arguments} } = @ARGV;
    return $result;
}

sub parse_params_string {
    my $self         = shift;
    my $param_string = shift;
    require Text::ParseWords;
    return $self->parse_params( Text::ParseWords::shellwords($param_string) );
}

sub option_parse_config { return qw(gnu_getopt) }
sub option_config       { }

sub option {
    my $self = shift;
    my $option = shift || return;
    if (@_) {
        return $self->{options}{$option} = shift;
    }
    return $self->{options}{$option};
}

sub option_default {
    my $self = shift;
    my $option = shift || return;
    if ( !defined $self->option($option) ) {
        return $self->option( $option, @_ );
    }
    return;
}

sub arguments {
    return @{ $_[0]->{arguments} };
}

sub run {
    my $self = shift;
    my @params = ( @_ == 1 && ref $_[0] eq 'ARRAY' ) ? @{ +shift } : @_;
    local $| = 1;
    if ( !$self->parse_params(@params) ) {
        my $usage = $self->usage(0);
        warn $usage;    ##no critic (RequireCarping)
        exit 1;
    }
    my $result = $self->process ? 0 : 1;
    exit $result;
}

sub usage {
    my $class     = shift;
    my $verbosity = shift;
    if ( ref $class ) {
        $class = ref $class;
    }
    require WGDev::Help;
    my $usage = WGDev::Help::package_usage( $class, $verbosity );
    return $usage;
}

1;

__END__

=head1 NAME

WGDev::Command::Base - Super-class for implementing WGDev commands

=head1 SYNOPSIS

    package WGDev::Command::Mine;
    use WGDev::Command::Base;
    @ISA = qw(WGDev::Command::Base);

    sub process {
        my $self = shift;
        print "Running my command\n";
        return 1;
    }

=head1 DESCRIPTION

A super-class useful for implementing WGDev command modules.  Includes simple
methods to override for parameter parsing and provides help text via
Pod::Usage.

=head1 METHODS

=head2 is_runnable

Must return true for the command to be run by WGDev::Command.

=head1 AUTHOR

Graham Knop <graham@plainblack.com>

=head1 LICENSE

Copyright (c) Graham Knop.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

