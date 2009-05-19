package WGDev::Command::Ls;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.1.0';

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

sub config_options {
    return qw(
        format|f=s
        long|l
    );
}

sub process {
    my $self   = shift;
    my $wgd    = $self->wgd;
    my $format = $self->option('format');
    if ( $self->option('long') ) {
        $format = '%assetId% %url:-35% %title%';
    }
    elsif ( !$format ) {
        $format = '%url%';
    }
    my @parents     = $self->arguments;
    my $show_header = @parents > 1;
    while ( my $parent = shift @parents ) {
        my $asset;
        if ( !eval { $asset = $wgd->asset->find($parent) } ) {
            warn "wgd edit: $parent: No such asset\n";
            next;
        }
        if ($show_header) {
            print "$parent:\n";
        }
        my $children
            = $asset->getLineage( ['children'], { returnObjects => 1 } );
        for my $child ( @{$children} ) {
            my $output = $format;
            $output =~ s{% (?: (\w+) (?: :(-?\d+) )? )? %}{
                my $replace;
                if ($1) {
                    $replace = $child->get($1);
                    if ($2) {
                        $replace = sprintf("%$2s", $replace);
                    }
                }
                else {
                    $replace = '%';
                }
                $replace;
            }msxeg;
            print $output . "\n";
        }
        if (@parents) {
            print "\n";
        }
    }
    return 1;
}

1;

__END__

=head1 NAME

WGDev::Command::Ls - List WebGUI assets

=head1 SYNOPSIS

    wgd ls [-l] [--format=<format>] <asset> [<asset> ...]

=head1 DESCRIPTION

Lists children of WebGUI assets

=head1 OPTIONS

=over 8

=item C<--long> C<-l>

Use long list format, which includes asset ID, URL, and title.

=item C<--format=> C<-f>

Use arbitrary formatting.  Format looks like C<%url:30%>, where 'C<url>' is
the field to display, and 30 is the length to left pad/cut to.  Negative
lengths can be specified for right padding.  Percent signs can be included by
using C<%%>.

=back

=head1 AUTHOR

Graham Knop <graham@plainblack.com>

=head1 LICENSE

Copyright (c) Graham Knop.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

