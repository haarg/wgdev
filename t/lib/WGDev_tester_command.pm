package WGDev::Command::_tester;
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

our $have_run;
our $option_all;

sub process {
    my $self = shift;
    my $wgd  = $self->wgd;
    $have_run = 1;
    if ( $self->option('all') ) {
        $option_all = 1;
    }
    return 1;
}

sub extra_method {
    return "extra method";
}

1;

__END__

=head1 NAME

WGDev::Command::_tester - Tester Command

=head1 SYNOPSIS

    wgd _tester

=head1 DESCRIPTION

This is a command for the test suite which has a filename that doesn't
match its package.

=head1 METHODS

=head2 C<extra_method>

Documentation for the extra method.

=head1 AUTHOR

Graham Knop <haarg@haarg.org>

=head1 LICENSE

Copyright (c) 2009-2010, Graham Knop

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl 5.10.0. For more details, see the
full text of the licenses in the directory LICENSES.

=cut

