package WGDev::Command::Guid;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.2.0';

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

sub config_options {
    return qw(
        number|n=i
        dashes!
        toHex
    );
}

sub process {
    my $self = shift;
    my $wgd  = $self->wgd;

    my $session = $wgd->session();
    my $id      = $session->id;

    if ( $self->option('toHex') ) {
        foreach my $guid ( $self->arguments ) {
            printf "%s : %s\n", $guid, $id->toHex($guid);
        }
        return;
    }

    my $number = $self->option('number') || 1;
    $self->set_option_default( dashes => 1 );

    for ( 1 .. $number ) {
        my $guid = $id->generate();
        if ( !$self->option('dashes') && $guid =~ /[-_]/msx ) {
            redo;
        }
        print "$guid\n";
    }
    return 1;
}

1;

__DATA__

=head1 NAME

WGDev::Command::Guid - Generates GUIDs via WebGUI's C<< $session->id->generate >> API

=head1 SYNOPSIS

    wgd guid [-n <quantity>] [--no-dashes]

=head1 DESCRIPTION

Generates GUIDs via WebGUI's C<$session->id->generate> API. Optionally
excludes GUIDs with dashes (for easy double-click copy/pasting).

=head1 OPTIONS

=over 8

=item C<-n> C<--number>

Number of GUIDs to generate. Defaults to 1.

=item C<--[no-]dashes>

Whether or not to filter GUIDs containing dashes (for easy double-click copy/pasting)

=back

=head1 AUTHOR

Patrick Donelan <pat@patspam.com>

=head1 LICENSE

Copyright (c) Patrick Donelan.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

