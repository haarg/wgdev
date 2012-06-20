package WGDev::Command::Batchedit;
# ABSTRACT: Edits assets by URL or asset ID with a pattern and a string
#           so it can be used in a shell script / batch file
use strict;
use warnings;
use 5.008008;

use parent qw(WGDev::Command::Base);

use WGDev ();

sub config_options {
    return qw(
        command=s
        tree=s@
        class=s@
        pattern=s
        string=s
    );
}

sub process {
    my $self = shift;
    my $wgd  = $self->wgd;

    my @assets_to_edit = $self->get_assets_data;

    if ( !@assets_to_edit ) {
        WGDev::X->throw('No assets to edit!');
    }

    # get pattern to match
    my $pattern = $self->{options}->{pattern};

    # get replacement string
    my $string  = $self->{options}->{string};

    my $output_format = "%-8s: %-30s (%22s) %s\n";

    my $version_tag;
    for my $asset_to_edit (@assets_to_edit) {
        my $asset_text = $asset_to_edit->{text};
        my $old_asset_text = $asset_text;
        $asset_text =~ s/$pattern/$string/xmsg;
        if ( $asset_text eq $old_asset_text ) {
            printf $output_format,
                'Skipping', ( $asset_to_edit->{url} || $asset_to_edit->{title} ),
                ( $asset_to_edit->{asset_id} || q{} ), $asset_to_edit->{title};
            next;
        }
        $version_tag ||= do {
            require WebGUI::VersionTag;
            my $vt = WebGUI::VersionTag->getWorking( $wgd->session );
            $vt->set( { name => 'WGDev Asset Editor' } );
            $vt;
        };
        my $asset_data = $wgd->asset->deserialize($asset_text);
        my $asset;
        my $parent;
        if ( $asset_data->{parent} ) {
            $parent = do { $wgd->asset->find( $asset_data->{parent} ) };
        }
        if ( $asset_to_edit->{asset_id} ) {
            $asset = $wgd->asset->by_id( $asset_to_edit->{asset_id}, undef,
                $asset_to_edit->{revision} );
            $asset = $asset->addRevision(
                $asset_data,
                undef,
                {
                    skipAutoCommitWorkflows => 1,
                    skipNotification        => 1,
                } );
            if ($parent) {
                $asset->setParent($parent);
            }
        }
        else {
            $parent ||= $wgd->asset->import_node;
            my $asset_id = $asset_data->{assetId};
            $asset = $parent->addChild(
                $asset_data,
                $asset_id,
                undef,
                {
                    skipAutoCommitWorkflows => 1,
                    skipNotification        => 1,
                } );
        }
        printf $output_format, ( $asset_to_edit->{asset_id} ? 'Updating' : 'Adding' ),
            $asset->get('url'), $asset->getId, $asset->get('title');
    }

    if ($version_tag) {
        $version_tag->commit;
    }
    return 1;
}

sub get_assets_data {
    my $self = shift;
    my $wgd  = $self->wgd;
    my @assets_data;
    for my $asset_spec ( $self->arguments ) {
        my $asset_data = do { $self->get_asset_data($asset_spec) };
        if ( !$asset_data ) {
            warn $@;
            next;
        }
        push @assets_data, $asset_data;
    }
    if ( !$self->option('tree') ) {
        return @assets_data;
    }
    for my $parent_spec ( @{ $self->option('tree') } ) {
        my $parent = $wgd->asset->find($parent_spec) || do {
            warn "$parent_spec is not a valid asset!\n";
            next;
        };
        my $options = {};
        if ( $self->option('class') ) {
            my @classes = @{ $self->option('class') };
            for (@classes) {
                s/^(?:(?:WebGUI::Asset)?::)?/WebGUI::Asset::/msx;
            }
            $options->{includeOnlyClasses} = \@classes;
        }
        my $assets
            = $parent->getLineage( [qw(self descendants)], $options );
        for my $asset_id ( @{$assets} ) {
            my $asset_data = $self->get_asset_data($asset_id);
            if ( !$asset_data ) {
                next;
            }
            push @assets_data, $asset_data;
        }
    }
    return @assets_data;
}

sub get_asset_data {
    my $self  = shift;
    my $asset = shift;

    my $wgd_asset = $self->wgd->asset;
    if ( !ref $asset ) {
        $asset = do { $wgd_asset->find($asset) };
        if ( !$asset ) {
            die $@;
        }
    }

    my $asset_text = $self->wgd->asset->serialize($asset);
    my $short_class = ref $asset || $asset;
    $short_class =~ s/^WebGUI::Asset:://msx;

    return {
        text     => $asset_text,
        class    => ref $asset || $asset,
        asset_id => $asset->getId,
        url      => $asset->get('url'),
        title    => $asset->get('title'),
    };
}

1;

=head1 SYNOPSIS

    wgd batchedit --pattern=<pattern> --string=<string> <asset> [<asset> ...]
    wgd batchedit --tree=<asset> --pattern=<pattern> --string=<string> [--tree=<asset> ...] [--class=<class> ...]

=head1 DESCRIPTION

Edits assets in-place by replacing all matching 'pattern's with 'string'.
If modifications are made, the assets are updated.

=head1 OPTIONS

=over 8

=item C<--pattern=>

Pattern to match against for replacing.

=item C<--string=>

Replacement string for the matched pattern.

=item C<< <asset> >>

Either an asset URL or ID.  As many as desired can be specified.
Prepending with a slash will force it to be interpreted as a URL.

=item C<--tree=>

Will open specified asset and all descendants in editor.  Can be specified
multiple times.

=item C<--class=>

Only used with --tree option.  Limits exported assets to specified classes.
Can be specified as a full (C<WebGUI::Asset::Template>) or abbreviated
(C<Template>) class name.

=back

=method C<get_assets_data>

Creates and returns an array of hash references with information about
the assets and exported files. Also follows the C<--tree> option.

=method C<get_asset_data ( $asset_or_class )>

Accepts an asset, returning a hash reference of information about the
asset.

=cut

