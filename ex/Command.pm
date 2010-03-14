package WGDev::Command::Example;
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
    if ( $self->option('all') ) {
        print "Doing everything.\n";
    }
    else {
        print "Doing something.\n";
    }
    return 1;
}

1;

__END__

=head1 NAME

WGDev::Command::Example - Example WGDev Command

=head1 SYNOPSIS

    wgd example [-A]

=head1 DESCRIPTION

This is a sample command.

=head1 OPTIONS

=over 8

=item C<-A> C<--all>

Does everything.

=back

=head1 AUTHOR

Graham Knop <haarg@haarg.org>

=head1 LICENSE

Copyright (c) 2009-2010, Graham Knop

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl 5.10.0. For more details, see the
full text of the licenses in the directory LICENSES.

=cut

