package WGDev::Command::Base::Verbosity;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.1.0';

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

sub new {    ##no critic (RequireArgUnpacking)
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    $self->{verbosity} = 1;
    return $self;
}

sub option_config {
    return qw(
        verbose|v+
        quiet|q+
    );
}

sub parse_params {    ##no critic (RequireArgUnpacking)
    my $self   = shift;
    my $result = $self->SUPER::parse_params(@_);
    $self->{verbosity} += ( $self->option('verbose') || 0 )
        - ( $self->option('quiet') || 0 );
    return $result;
}

sub verbosity {       ##no critic (RequireArgUnpacking)
    my $self = shift;
    if (@_) {
        return $self->{verbosity} = shift;
    }
    return $self->{verbosity};
}

sub report {
    my $self          = shift;
    my $message       = pop;
    my $verbose_limit = shift;
    if ( !defined $verbose_limit ) {
        $verbose_limit = 1;
    }
    return
        if $verbose_limit > $self->verbosity;
    print $message;
    return 1;
}

1;

__END__

=head1 NAME

WGDev::Command::Base::Verbosity - Super-class for implementing WGDev commands with verbosity levels

=head1 SYNOPSIS

    package WGDev::Command::Mine;
    use WGDev::Command::Base::Verbisity;
    @ISA = qw(WGDev::Command::Base::Verbosity);

    sub process {
        my $self = shift;
        $self->report("Running my command\n");
        return 1;
    }

=head1 DESCRIPTION

A super-class useful for implementing WGDev command modules.  Includes simple
methods to override for parameter parsing and provides help text via
Pod::Usage.

=head1 AUTHOR

Graham Knop <graham@plainblack.com>

=head1 LICENSE

Copyright (c) Graham Knop.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

