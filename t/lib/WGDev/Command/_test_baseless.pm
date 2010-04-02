package WGDev::Command::_test_baseless;
use strict;
use warnings;
use 5.008008;

our $VERSION = '9.8.7';

sub is_runnable {
    return 1;
}

sub run {
    exit;
}

1;

__DATA__

=head1 NAME

WGDev::Command::_test_baseless - WGDev command that doesn't use WGDev::Command::Base

=head1 SYNOPSIS

    wgd _test_baseless

=head1 DESCRIPTION

WGDev Command not subclassing WGDev::Command::Base

=head1 OPTIONS

None

=head1 AUTHOR

Graham Knop <haarg@haarg.org>

=head1 LICENSE

Copyright (c) 2009-2010, Graham Knop

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl 5.10.0. For more details, see the
full text of the licenses in the directory LICENSES.

=cut

