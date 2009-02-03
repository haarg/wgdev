package WGDev::Command::Package;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.2.0';

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

use Carp qw(croak);

sub option_config { qw(
    import|i=s@
    parent-id=s
    parent-url=s

    guid|assetId|asset-id|id=s@
    upgrade|u
    output-dir|out-dir=s
)}

sub process {
    my $self = shift;
    my $wgd = $self->wgd;
    require File::Copy;
    if ($self->arguments || $self->option('guid')) {
        my $package_dir = $self->option('output-dir') || '.';
        if ($self->option('upgrade')) {
            $package_dir = File::Spec->catdir($wgd->root, 'docs', 'upgrades', 'packages-' . $wgd->version->module);
            if (! -d $package_dir) {
                mkdir $package_dir;
            }
        }
        if (! -d $package_dir) {
            croak "$package_dir does not exist!\n";
        }
        my @assets;
        for my $url ($self->arguments) {
            my $asset = $wgd->asset->by_url($url);
            if ($asset) {
                push @assets, $asset
            }
            else {
                warn "Unable to find asset with url $url!\n";
            }
        }
        if ($self->option('guid')) {
            for my $asset_id (@{ $self->option('guid') }) {
                my $asset = $wgd->asset->by_id($asset_id);
                if ($asset) {
                    push @assets, $asset
                }
                else {
                    warn "Unable to find asset with id $asset_id!\n";
                }
            }
        }
        for my $asset (@assets) {
            my $storage = $asset->exportPackage;
            my $filename = $storage->getFiles->[0];
            my $filepath = $storage->getPath($filename);
            File::Copy::copy($filepath, File::Spec->catfile($package_dir, $filename));
            printf "Building package %26s for '%26s'.\n", $filename, $asset->get('title');
        }
    }
    if ($self->option('import')) {
        require WebGUI::Storage;
        my $parent
            = $self->option('parent-id')    ? $wgd->asset->by_id($self->option('parent-id'))
            : $self->option('parent-url')   ? $wgd->asset->by_url($self->option('parent-url'))
            : $wgd->asset->import_node
            ;
        if (! $parent) {
            warn "Unable to find parent node!\n";
            return 0;
        }
        my $versionTag = WebGUI::VersionTag->getWorking($wgd->session);
        $versionTag->set({name => 'WGDev package import'});
        for my $package (@{ $self->option('import')}) {
            my $storage = WebGUI::Storage->createTemp($wgd->session);
            $storage->addFileFromFilesystem($package);
            my $asset = $parent->importPackage($storage);
            print "Imported '$package' to " . $asset->get('url') . "\n";
        }
        $versionTag->commit;
    }
    return 1;
}

1;

__END__

=head1 NAME

WGDev::Command::Package - Export assets for upgrade

=head1 SYNOPSIS

    wgd package [--output-dir=<dir>] [--upgrade] [<asset url> ...] [--guid=<asset id> ...]
    wgd package [--parent-id=<asset id>] [--parent-url=<asset url>] [--import=<package file>]

=head1 DESCRIPTION

Exports assets as packages to the current version's upgrade location.

=head1 OPTIONS

=over 8

=item B<--import -i>

Package file (or files) to import.  Will be imported to the import node if no
other parent is specified.

=item B<--parent-id>

Specify the parent to import packages to as an asset ID.

=item B<--parent-url>

Specify the parent to import packages to as an asset URL.

=item B<--guid --assetId --asset-id --id>

Specify assets to export by their asset ID.

=item B<--upgrade -u>

If specified, packages will be exported to the directory for the upgrade to
the current local version.

=item B<--output-dir --out-dir>

Specify a directory to output the package files to.  If neither --upgrade or
--output-dir is specified, packages will be output to the current directory.

=item B<E<lt>asset urlE<gt>>

Any other parameters will be assumed to be asset URLs to export as packages.

=back

=head1 AUTHOR

Graham Knop <graham@plainblack.com>

=head1 LICENSE

Copyright (c) Graham Knop.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

