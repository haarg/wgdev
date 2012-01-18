package WGDev::Command::Trash;
# ABSTRACT: Trash assets by URL/assetId
use strict;
use warnings;
use WGDev::Command::Ls;
use 5.008008;

use parent qw(WGDev::Command::Base);

use WGDev ();

sub config_options {
    return qw(
        purge
        restore
        list
    );
}

sub process {
    my $self = shift;
    my $wgd  = $self->wgd;
    if ($self->option('list')) {
        return $self->list_trash;
    }
    else {
        return $self->trash;
    }
}

sub trash {
    my $self = shift;
    my $wgd  = $self->wgd;
    my $error;
    my $method  = $self->option('purge')   ? 'purge'
                : $self->option('restore') ? 'restore'
                : 'trash';
    my @asset_specs = $self->arguments;
    ASSET:
    while ( my $asset_spec = shift @asset_specs ) {
        my $asset;
        if ( !eval { $asset = $wgd->asset->find($asset_spec) } ) {
            warn "wgd trash: $asset_spec: No such asset\n";
            $error++;
            next ASSET;
        }
        my $success = $asset->$method;
        if ($method ne 'restore' && ! $success) {
            warn "wgd trash: unable to $method $asset_spec\n";
            ++$error;
        }
    }

    return (! $error);
}

sub list_trash {
    my $self = shift;
    my $wgd  = $self->wgd;
    my $root = $wgd->asset->root;
    my $trashed_assets = $root->getAssetsInTrash();
    my $ls = WGDev::Command::Ls->new($wgd);
    my $format = '%assetId% %url:-35% %title%';
    ASSET:
    foreach my $asset ( @{ $trashed_assets } ) {
        next ASSET unless $asset;
        my $output = $ls->format_output( $format, $asset );
        print $output . "\n";
    }

    return 1;
}

1;

=head1 SYNOPSIS

    wgd trash [--purge] [--restore] <asset> [<asset> ...]
    wgd trash [--list]

=head1 DESCRIPTION

Methods for working with assets in the trash.

=head1 OPTIONS

=over 8

=item C<--purge>

Purges the assets from the system instead of putting it into the trash.

=item C<--restore>

Restores the assets that have been trashed to the regular, published state.

=item C<--list>

Lists all assets in the trash.

=item C<< <asset> >>

Either an asset URL or an ID.  As many can be specified as desired.
Prepending with a slash will force it to be interpreted as a URL.

=back

=cut

1;
