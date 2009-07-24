package WGDev::Command::Export::Branch;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.0.1';

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

sub config_options {
    return qw(
        output-dir|O=s
    );
}

sub process {
    my $self = shift;
    my $wgd  = $self->wgd;
    return 1;
}

1;

__END__

=head1 NAME

WGDev::Command::Export::Branch - Export an entire branch of assets to text files

=head1 SYNOPSIS

    wgd export-branch

=head1 DESCRIPTION

Export and entire branch of asset to text files.

=head1 OPTIONS

=over 8

=item C<--output-dir> C<-O>

The directory to output files to.

=back

=head1 AUTHOR

Graham Knop <graham@plainblack.com>

=head1 LICENSE

Copyright (c) Graham Knop.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

