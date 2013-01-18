package WGDev::Command::Import;
# ABSTRACT: Import assets from files
use strict;
use warnings;
use 5.008008;

use parent qw(WGDev::Command::Base);

sub process {
    my $self = shift;

    my $wgd_asset = $self->wgd->asset;
    my $version_tag;
    for my $asset_file ( $self->arguments ) {
        open my $fh, '<:encoding(UTF-8)', $asset_file or next;
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
            $parent = do { $wgd_asset->find( $asset_data->{parent} ) };
        }
        my $asset;
        my $mode;

        if ( do { $asset = $wgd_asset->by_id( $asset_data->{assetId} ) } ) {
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

=head1 SYNOPSIS

    wgd import <asset file> [<asset file> ...]

=head1 DESCRIPTION

Imports asset from files.

=head1 OPTIONS

=over 8

=item C<< <asset file> >>

File to import.

=back

=cut

