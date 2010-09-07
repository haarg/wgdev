package WGDev::Command::Export::Branch;
# ABSTRACT: Export a branch of assets
use strict;
use warnings;
use 5.008008;

use WGDev::Command::Base::Verbosity;
BEGIN { our @ISA = qw(WGDev::Command::Base::Verbosity) }

use File::Spec ();
use Cwd        ();
use constant LINEAGE_LEVEL_LENGTH => 6;

sub config_options {
    return (
        shift->SUPER::config_options, qw(
            to
            hier!
            ) );
}

sub parse_params {
    my $self   = shift;
    my $result = $self->SUPER::parse_params(@_);
    $self->set_option_default( 'hier', 1 );
    return $result;
}

sub process {
    my $self = shift;
    require File::Path;

    my $wgd_asset = $self->wgd->asset;

    my $base_dir = $self->option('to') || Cwd::cwd;
    my $heir = $self->option('hier');

    for my $asset_spec ( $self->arguments ) {
        my $base_asset = eval { $wgd_asset->find($asset_spec) };
        if ( !$base_asset ) {
            warn $@;
            next;
        }
        $self->report( 'Exporting "' . $base_asset->get('title') . "...\n" );
        if ( $self->verbosity ) {
            $self->tab_level(1);
        }
        my $iter
            = $base_asset->getLineageIterator( [ 'self', 'descendants' ] );
        my $base_depth
            = length( $base_asset->get('lineage') ) / LINEAGE_LEVEL_LENGTH;
        while ( my $asset = $iter->() ) {
            my @url_segments;
            if ($heir) {
                my $parent = $asset;
                my $depth
                    = length( $asset->get('lineage') ) / LINEAGE_LEVEL_LENGTH;
                while (1) {
                    my $url_part = $parent->get('url');
                    $url_part =~ s{.*/}{}msx;
                    unshift @url_segments, $url_part;
                    last
                        if --$depth < $base_depth;
                    $parent = $parent->getParent;
                }
            }
            else {
                @url_segments = split m{/}msx, $asset->get('url');
            }
            my $extension = $wgd_asset->export_extension($asset);
            my $filename  = ( pop @url_segments ) . ".$extension";
            $self->report( 0,
                File::Spec->catfile( @url_segments, $filename ) . "\n" );
            my $dir = File::Spec->catdir( $base_dir, @url_segments );
            my $full_path = File::Spec->catfile( $dir, $filename );
            File::Path::mkpath($dir);
            my $asset_text = $wgd_asset->serialize($asset);
            open my $fh, '>', $full_path
                or WGDev::X::IO::Write->throw( path => $full_path );
            print {$fh} $asset_text;
            close $fh
                or WGDev::X::IO::Write->throw( path => $full_path );
        }
        if ( $self->verbosity ) {
            $self->tab_level(-1);
        }
        $self->report("Done.\n");
    }
    return 1;
}

1;

=head1 SYNOPSIS

    wgd export-branch [--no-hier] [--to=<output dir>] <asset> [<asset> ...]

=head1 DESCRIPTION

Exports a branch of assets as serialized files.

=head1 OPTIONS

=over 8

=item C<--[no-]hier>

Exports assets in a directories based on their hierarchy in the
asset tree.  If not enabled, the serialized assets' location is
based directly on their URLs. Enabled by default.

=item C<-t> C<--to=>

Output directory to place the exported files in.  If not specified,
files are placed in the current directory.

=back

=cut

