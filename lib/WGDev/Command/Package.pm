package WGDev::Command::Package;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.3.0';

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

use File::Spec ();
use WGDev::X   ();

sub config_options {
    return qw(
        import|i=s@
        parent=s

        upgrade|u
        to=s
    );
}

sub process {
    my $self = shift;
    my $wgd  = $self->wgd;
    require File::Copy;
    if ( $self->arguments ) {
        my $package_dir = $self->option('to') || q{.};
        if ( $self->option('upgrade') ) {
            $package_dir = File::Spec->catdir( $wgd->root, 'docs', 'upgrades',
                'packages-' . $wgd->version->module );
            if ( !-d $package_dir ) {
                mkdir $package_dir;
            }
        }
        if ( !-d $package_dir ) {
            WGDev::X::IO->throw(
                error => 'Directory does not exist',
                path  => $package_dir
            );
        }
        for my $asset_spec ( $self->arguments ) {
            my $asset = eval { $wgd->asset->find($asset_spec) } || do {
                warn "Unable to find asset $asset_spec!\n";
                next;
            };

            my $storage  = $asset->exportPackage;
            my $filename = $storage->getFiles->[0];
            my $filepath = $storage->getPath($filename);
            File::Copy::copy( $filepath,
                File::Spec->catfile( $package_dir, $filename ) );
            printf "Building package %27s for %27s.\n", $filename,
                $asset->get('title');
        }
    }
    if ( $self->option('import') ) {
        my $parent
            = $self->option('parent')
            ? eval { $wgd->asset->find( $self->option('parent') ) }
            : $wgd->asset->import_node;
        if ( !$parent ) {
            warn "Unable to find parent node!\n";
            return 0;
        }
        require WebGUI::Storage;
        require WebGUI::VersionTag;

        my $version_tag = WebGUI::VersionTag->getWorking( $wgd->session );
        $version_tag->set( { name => 'WGDev package import' } );
        for my $package ( @{ $self->option('import') } ) {
            my $storage = WebGUI::Storage->createTemp( $wgd->session );
            $storage->addFileFromFilesystem($package);
            my $asset = $parent->importPackage($storage);
            print "Imported '$package' to " . $asset->get('url') . "\n";
        }
        $version_tag->commit;
    }
    return 1;
}

1;

__DATA__

=head1 NAME

WGDev::Command::Package - Export assets for upgrade

=head1 SYNOPSIS

    wgd package [--to=<dir>] [--upgrade] [<asset> ...]
    wgd package [--parent=<asset>] [--import=<package file>]

=head1 DESCRIPTION

Exports or imports assets as packages, optionally placing them in the current
upgrade path.

=head1 OPTIONS

Assets specified as standalone arguments are exported as packages.

=over 8

=item C<-i> C<--import=>

Package file (or files) to import.  Will be imported to the import node if no
other parent is specified.

=item C<--parent=>

Specify the parent asset to import packages into.

=item C<-u> C<--upgrade>

If specified, packages will be exported to the directory for the upgrade to
the current local version.

=item C<--to=>

Specify a directory to output the package files to.  If neither C<--upgrade>
or C<--to> is specified, packages will be output to the current directory.

=item C<< <asset> >>

Either an asset ID or an asset URL to specify an asset.

=back

=head1 AUTHOR

Graham Knop <haarg@haarg.org>

=head1 LICENSE

Copyright (c) 2009-2010, Graham Knop

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl 5.10.0. For more details, see the
full text of the licenses in the directory LICENSES.

=cut

