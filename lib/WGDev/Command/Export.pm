package WGDev::Command::Export;
# ABSTRACT: Exports assets to files
use strict;
use warnings;
use 5.008008;

use parent qw(WGDev::Command::Base);

use WGDev::X ();

sub config_options {
    return qw(
        stdout
    );
}

sub process {
    my $self = shift;

    my $wgd_asset = $self->wgd->asset;
    for my $asset_spec ( $self->arguments ) {
        my $asset = do { $wgd_asset->find($asset_spec) }
            || do { $wgd_asset->validate_class($asset_spec) };
        if ( !$asset ) {
            warn $@;
            next;
        }
        my $asset_text = $self->wgd->asset->serialize($asset);
        if ( $self->option('stdout') ) {
            print $asset_text;
        }
        else {
            my $filename = $self->export_filename($asset);
            print "Writing $filename...\n";
            open my $fh, '>', $filename
                or WGDev::X::IO::Write->throw( path => $filename );
            print {$fh} $asset_text;
            close $fh
                or WGDev::X::IO::Write->throw( path => $filename );
        }
    }
    return 1;
}

sub export_filename {
    my $self        = shift;
    my $asset       = shift;
    my $class       = ref $asset || $asset;
    my $short_class = $class;
    $short_class =~ s/.*:://msx;
    my $extension = lc $short_class;
    $extension =~ tr/aeiouy//d;
    $extension =~ tr/a-z//s;
    my $filename;

    if ( ref $asset ) {
        $filename = ( split m{/}msx, $asset->get('url') )[-1];
    }
    else {
        $filename = 'new-' . lc $short_class;
    }
    $filename .= ".$extension";
    return $filename;
}

1;

=head1 SYNOPSIS

    wgd export [--stdout] <asset> [<asset> ...]

=head1 DESCRIPTION

Exports asset to files.

=head1 OPTIONS

=over 8

=item C<--stdout>

Exports to standard out instead of a file.  This only makes sense with a single asset specified.

=item C<< <asset> >>

Either an asset URL, ID, class name.  As many can be specified as desired.
Prepending with a slash will force it to be interpreted as a URL.  Asset
classes will generate skeletons of export files for the given class.

=back

=method C<export_filename ( $asset_or_class )>

Calculates the file name to export an asset as.  Accepts a parameter of the
asset object or an asset class name.  The file name will be the last portion
of the asset's URL, with an extension based on the asset's class name.  If
provided only a class name, the file name will also be based on the class
name.

=cut

