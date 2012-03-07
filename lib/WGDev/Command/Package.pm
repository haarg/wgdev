package WGDev::Command::Package;
# ABSTRACT: Export assets for upgrade
use strict;
use warnings;
use 5.008008;

use parent qw(WGDev::Command::Base);

use File::Spec ();
use WGDev::X   ();

sub config_options {
    return qw(
        import|i=s@
        parent=s
        overwrite
        listids
        class=s

        upgrade|u
        to=s
    );
}

sub process {
    my $self = shift;
    my $wgd  = $self->wgd;
    require File::Copy;
    if ( $self->arguments ) {
        if ($self->option('listids')) {
            $self->list_ids;
            return 1;
        }
        my $package_dir = $self->option('to') || q{.};
        if ( $self->option('upgrade') ) {
            my $version = $wgd->version->module;
            my $wg8 = $version =~ /^8[.]/msx;
            if ($wg8) {
                require WebGUI::Paths;
                my $old_version = $wgd->version->db_script;
                $package_dir = File::Spec->catdir( WebGUI::Paths->upgrades,
                    $old_version . q{-} . $version );
            }
            else {
                $package_dir = File::Spec->catdir( $wgd->root, 'docs', 'upgrades',
                    'packages-' . $wgd->version->module );
            }
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
        my $import_options = {};
        if ($self->option('overwrite')) {
            $import_options->{'overwriteLatest'} = 1;
        }
        for my $package ( @{ $self->option('import') } ) {
            my $storage = WebGUI::Storage->createTemp( $wgd->session );
            $storage->addFileFromFilesystem($package);
            my $asset = $parent->importPackage($storage, $import_options);
            if ( ! ref $asset ) {
                # importPackage returns a string for errors (ugh)
                WGDev::X::BadPackage->throw(
                    package => $package,
                    message => $asset,
                );
            }
            elsif ( ! eval { $asset->isa('WebGUI::Asset') } ) {
                # not an asset or an error?  this shouldn't ever happen.
                WGDev::X::BadPackage->throw(
                    package => $package,
                    message => 'Strange result from package import: '
                        . ref($asset),
                );
            }
            print "Imported '$package' to " . $asset->get('url') . "\n";
        }
        $version_tag->commit;
    }
    return 1;
}

sub list_ids {
    my $self         = shift;
    my $class        = $self->option('class');
    foreach my $package_file ( $self->arguments ) {
        my @asset_ids    = $self->get_ids_from_package($package_file, $class);
        print $package_file."\n";
        print join '', map { "\t$_\n" } @asset_ids;
    }
    return 1;
}

sub get_ids_from_package {
    my $self         = shift;
    my $wgd          = $self->wgd;
    my $package_file = shift || $self->option('listids');  ##complete path
    my $class        = shift;
    require Archive::Any;
    require File::Temp;
    require JSON;
    my @asset_ids = ();
    my $tmp_dir = File::Temp->newdir();
    my $wgpkg = Archive::Any->new($package_file);
    $wgpkg->extract($tmp_dir->dirname);
    FILE: foreach my $filename ($wgpkg->files) {
        next FILE unless $filename =~ /\.json$/;
        my $abs_filename = File::Spec->catdir( $tmp_dir->dirname, $filename);
        open my $asset_file, '<', $abs_filename or
            WebGUI::X::IO->throw(
                error => 'File does not exist',
                path  => $abs_filename,
            );
        local $/;
        my $asset_json = <$asset_file>;
        close $asset_file;
        my $asset_data = JSON::from_json($asset_json)->{properties}; 
        my $asset_id   = $asset_data->{assetId};
        next FILE if $class && $class ne $asset_data->{className};
        push @asset_ids, $asset_id;
    }
    return @asset_ids;
}


1;

=head1 SYNOPSIS

    wgd package [--to=<dir>] [--upgrade] [<asset> ...]
    wgd package [--parent=<asset>] [--import=<package file>]
    wgd package [--listids] [--class=WebGUI::Asset::Template]

=head1 DESCRIPTION

Exports or imports assets as packages, optionally placing them in the current
upgrade path.

=head1 OPTIONS

Assets specified as standalone arguments are exported as packages.

=over 8

=item C<-i> C<--import=>

Package file (or files) to import.  Will be imported to the import node if no
other parent is specified.

=item C<--overwrite>

Forces the assets in this package to be the latest version on the
site.  This option only works in conjunction with C<--import> and
requires WebGUI 7.8.1 or higher.

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

=item C<--listids=/path/to/package.wgpkg>

List all of the assetIds in a single package.

=item C<--class=WebGUI::Asset::Template>

When used with <--listids>, restricts the list of assets to only those of
the named class.  Since the package data is textual and there is no actual
object, this does not support inheritance.


=back

=cut

