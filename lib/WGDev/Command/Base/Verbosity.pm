package WGDev::Command::Base::Verbosity;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.2.0';

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    $self->{verbosity} = 1;
    $self->{tab_level} = 0;
    return $self;
}

sub config_options {
    return qw(
        verbose|v
        quiet|q
    );
}

sub option_verbose {
    my $self = shift;
    $self->{verbosity}++;
    return;
}

sub option_quiet {
    my $self = shift;
    $self->{verbosity}--;
    return;
}

sub verbosity {
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
    my $tabs = "\t" x $self->tab_level;
    print $tabs . $message;
    return 1;
}

sub tab_level {
    my $self = shift;
    if (@_) {
        $self->{tab_level} += shift;
    }
    return $self->{tab_level};
}

1;

__END__

=head1 NAME

WGDev::Command::Base::Verbosity - Super-class for implementing WGDev commands with verbosity levels

=head1 SYNOPSIS

    package WGDev::Command::Mine;
    use WGDev::Command::Base::Verbosity;
    @ISA = qw(WGDev::Command::Base::Verbosity);

    sub process {
        my $self = shift;
        $self->report("Running my command\n");
        return 1;
    }

=head1 DESCRIPTION

A super-class useful for implementing WGDev command modules.  Parses the
C<--verbose> and C<--quiet> command line options.

=head1 METHODS

=head2 C<verbosity ( [ $verbosity ] )>

Sets or returns the verbosity.  This is modified when parsing parameters.  Defaults to 1.

=head2 C<report ( [ $verbosity, ] $message )>

Prints messages based on the current verbosity level.  If given two
parameters, the first must be the verbosity level to start printing the
message at.  The second parameter is the message to print.  Will also accept
a single parameter of a message to print starting at verbosity level 1.

=head1 AUTHOR

Graham Knop <haarg@haarg.org>

=head1 LICENSE

Copyright (c) 2009-2010, Graham Knop

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl 5.10.0. For more details, see the
full text of the licenses in the directory LICENSES.

=cut

