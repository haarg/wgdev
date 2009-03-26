package WGDev::Command::Edit;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.1.0';

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

sub option_config {
    return qw(
        command=s
        tree=s@
        class=s@
    );
}

sub process {
    my $self = shift;
    my $wgd  = $self->wgd;

    my @files = $self->export_asset_data;

    if ( !@files ) {
        die "No assets to edit!\n";
    }

    ## no critic (ProhibitParensWithBuiltins)
    my $command = $self->option('command') || $ENV{EDITOR} || 'vi';
    system join( q{ }, $command, map { $_->{filename} } @files );

    my $output_format = "%-8s: %-30s (%22s) %s\n";

    my $version_tag;
    for my $file (@files) {
        open my $fh, '<:utf8', $file->{filename} or next;
        my $asset_text = do { local $/ = undef; <$fh> };
        close $fh or next;
        unlink $file->{filename};
        if ( $asset_text eq $file->{text} ) {
            printf $output_format,
                'Skipping', ( $file->{url} || $file->{title} ),
                ( $file->{asset_id} || q{} ), $file->{title};
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
            $parent = eval { $wgd->asset->find( $asset_data->{parent} ) };
        }
        if ( $file->{asset_id} ) {
            $asset = $wgd->asset->by_id( $file->{asset_id}, undef,
                $file->{revision} );
            $asset = $asset->addRevision($asset_data);
            if ($parent) {
                $asset->setParent($parent);
            }
        }
        else {
            $parent ||= $wgd->asset->import_node;
            my $asset_id = $asset_data->{assetId};
            $asset = $parent->addChild( $asset_data, $asset_id );
        }
        printf $output_format, ( $file->{asset_id} ? 'Updating' : 'Adding' ),
            $asset->get('url'), $asset->getId, $asset->get('title');
    }

    if ($version_tag) {
        $version_tag->commit;
    }
    return 1;
}

sub export_asset_data {
    my $self = shift;
    my $wgd  = $self->wgd;
    my @files;
    for my $asset_spec ( $self->arguments ) {
        my $file_data = eval { $self->write_temp($asset_spec) };
        if ( !$file_data ) {
            warn "$asset_spec is not a valid asset!\n";
            next;
        }
        push @files, $file_data;
    }
    if ( $self->option('tree') ) {
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
                my $file_data = $self->write_temp($asset_id);
                if ( !$file_data ) {
                    next;
                }
                push @files, $file_data;
            }
        }
    }
    return @files;
}

sub write_temp {
    my $self  = shift;
    my $asset = shift;
    require File::Temp;

    my $wgd_asset = $self->wgd->asset;
    if ( !ref $asset ) {
        $asset = eval { $wgd_asset->find($asset) }
            || eval { $wgd_asset->validate_class($asset) };
        if ( !$asset ) {
            die $@;    ##no critic (RequireCarping)
        }
    }

    my $short_class = ref $asset || $asset;
    $short_class =~ s/^WebGUI::Asset:://msx;

    my ( $fh, $filename ) = File::Temp::tempfile();
    binmode $fh, ':utf8';
    my $asset_text = $self->wgd->asset->serialize($asset);
    print {$fh} $asset_text;
    close $fh or return;
    return {
        filename => $filename,
        text     => $asset_text,
        class    => ref $asset || $asset,
        ref $asset
        ? (
            asset_id => $asset->getId,
            url      => $asset->get('url'),
            title    => $asset->get('title'),
            )
        : ( title => 'New ' . $short_class, ),
    };
}

1;

__END__

=head1 NAME

WGDev::Command::Edit - Edits assets by URL

=head1 SYNOPSIS

    wgd edit [--command=<command>] <asset> [<asset> ...]
    wgd edit --tree=<asset> [--tree=<asset> ...] [--class=<class> ...]

=head1 DESCRIPTION

Exports asset to temporary files, then opens them in your prefered editor.
If modifications are made, the assets are updated.

=head1 OPTIONS

=over 8

=item C<--command>

Command to be executed.  If not specified, uses the EDITOR environment
variable.  If that is not specified, uses C<vi>.

=item C<E<lt>assetE<gt>>

Either an asset URL, ID, or class name.  As many can be specified as desired.
Prepending with a slash will force it to be interpreted as a URL.  Class names
specified will be opened with a skeleton for the asset type.

=item C<--tree>

Will open specified asset and all descendants in editor.  Can be specified
multiple times.

=item C<--class>

Only used with --tree option.  Limits exported assets to specified classes.
Can be specified as a full (C<WebGUI::Asset::Template>) or abbreviated
(C<Template>) class name.

=back

=head1 AUTHOR

Graham Knop <graham@plainblack.com>

=head1 LICENSE

Copyright (c) Graham Knop.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

