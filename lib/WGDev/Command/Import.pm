package WGDev::Command::Import;
use strict;
use warnings;
use 5.008008;

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

sub process {
    my $self = shift;

    my $wgd_asset = $self->wgd->asset;
    my $version_tag;
    for my $asset_file ( $self->arguments ) {
        open my $fh, '<:utf8', $asset_file or next;
        my $asset_text = do { local $/; <$fh> };
        close $fh or next;
        $version_tag ||= do {
            require WebGUI::VersionTag;
            my $vt = WebGUI::VersionTag->getWorking( $self->wgd->session );
            $vt->set( { name => 'WGDev Asset Import' } );
            $vt;
        };
        my $asset_data = $wgd_asset->deserialize($asset_text);
        my $parent;
        if ( $asset_data->{parent} ) {
            $parent = eval { $wgd_asset->find( $asset_data->{parent} ) };
        }
        my $asset;
        my $mode;

        if ( eval { $asset = $wgd_asset->by_id( $asset_data->{assetId} ) } ) {
            $mode = 'Updating';
            $asset->addRevision( $asset_data, undef,
                { skipAutoCommitWorkflows => 1, skipNotification => 1 } );
            if ( $asset_data->{parent} ) {
                if ($parent) {
                    $asset->setParent($parent);
                }
            }
        }
        else {
            $mode = 'Adding';
            $parent ||= $wgd_asset->import_node;
            $asset = $parent->addChild( $asset_data, $asset_data->{assetId},
                undef,
                { skipAutoCommitWorkflows => 1, skipNotification => 1 } );
        }
        printf "%8s: %-30s (%22s) %s\n", $mode,
            $asset->get('url'), $asset->getId, $asset->get('title');
    }
    if ($version_tag) {
        $version_tag->commit;
    }
    return 1;
}

1;

__DATA__

=head1 NAME

WGDev::Command::Import - Import assets from files

=head1 SYNOPSIS

    wgd import <asset file> [<asset file> ...]

=head1 DESCRIPTION

Imports asset from files.

=head1 OPTIONS

=over 8

=item C<< <asset file> >>

File to import.

=back

=head1 AUTHOR

Graham Knop <haarg@haarg.org>

=head1 LICENSE

Copyright (c) 2009-2010, Graham Knop

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl 5.10.0. For more details, see the
full text of the licenses in the directory LICENSES.

=cut

