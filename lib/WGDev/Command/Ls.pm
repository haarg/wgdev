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
        recursive|r
        excludeClass=s@
        includeOnlyClass=s@
        limit=n
        isa=s
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
    my $relatives = $self->option('recursive') ? 'descendants' : 'children';
    my @parents     = $self->arguments;
    my $show_header = @parents > 1;
    my $excludeClasses = $self->option('excludeClass');
    my $includeOnlyClasses = $self->option('includeOnlyClass');
    my $limit = $self->option('limit');
    my $isa = $self->option('isa');
    while ( my $parent = shift @parents ) {
        my $asset;
        if ( !eval { $asset = $wgd->asset->find($parent) } ) {
            warn "wgd edit: $parent: No such asset\n";
            next;
        }
        if ($show_header) {
            print "$parent:\n";
        }
        my $children = $asset->getLineage(
            [$relatives],
            {   returnObjects => 1,
                $excludeClasses     ? ( excludeClasses     => $excludeClasses )     : (),
                $includeOnlyClasses ? ( includeOnlyClasses => $includeOnlyClasses ) : (),
                defined $limit      ? ( limit              => $limit )              : (),
                $isa                ? ( isa                => $isa )                : (),
            }
        );
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

    wgd ls [-l] [--format=<format>] [-r] <asset> [<asset> ...]

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

=item C<--recursive=> C<-r>

Recursively list all descendants (by default we only list children).

=item C<--includeOnlyClass=>

Specify one or more times to limit the results to a certain set of asset classes.

=item C<--excludeClass=>

Specify one or more times to filter out certain asset class(es) from the results.

=item C<--limit=>

The maximum amount of entries to return

=item C<--isa=>

A classname where you can look for classes of a similar base class. For example, if you're looking for Donations, Subscriptions, Products and other subclasses of WebGUI::Asset::Sku, then set isa to 'WebGUI::Asset::Sku'.

=back

=head1 AUTHOR

Graham Knop <graham@plainblack.com>

=head1 LICENSE

Copyright (c) Graham Knop.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

