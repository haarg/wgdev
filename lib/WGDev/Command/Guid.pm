package WGDev::Command::Guid;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.1.0';

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

sub option_config {
    return qw(
        number|n=i
        dashes!
    );
}

sub process {
    my $self = shift;
    my $wgd  = $self->wgd;

    my $session = $wgd->session();

    my $number = $self->option('number') || 1;
    $self->set_option_default( dashes => 1 );

    for ( 1 .. $number ) {
        my $guid = $session->id->generate();
        if ( !$self->option('dashes') && $guid =~ /[-_]/msx ) {
            redo;
        }
        print "$guid\n";
    }
    return 1;
}

1;

__END__

=head1 NAME

WGDev::Command::Guid - Generates GUIDs via WebGUI's C<$session->id->generate> API

=head1 SYNOPSIS

    wgd guid [-n <number of GUIDs to generate>] [--no-dashes]

=head1 DESCRIPTION

Generates GUIDs via WebGUI's C<$session->id->generate> API. Optionally
excludes GUIDs with dashes (for easy double-click copy/pasting).

=head1 OPTIONS

=over 8

=item C<--number> C<-n>

Number of GUIDs to generate. Defaults to 1.

=item C<--dashes>

Whether or not to filter GUIDs containing dashes (for easy double-click copy/pasting)

=back

=head1 AUTHOR

Patrick Donelan <pat@patspam.com>

=head1 LICENSE

Copyright (c) Patrick Donelan.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

