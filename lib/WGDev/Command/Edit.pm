package WGDev::Command::Edit;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.1.0';

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

sub option_config {qw(
    command=s
)}

sub process {
    my $self = shift;
    my $wgd = $self->wgd;

    require WebGUI::Asset;
    require File::Temp;

    my @files;
    for my $asset_spec ( $self->arguments ) {
        my $asset;
        if (! ($asset_spec =~ m{/}msx)) {
            $asset = $wgd->asset->by_id($asset_spec);
        }
        if (! $asset) {
            $asset = $wgd->asset->by_url($asset_spec);
        }
        if (! $asset) {
            warn "$asset_spec is not a valid asset!\n";
            next;
        }
        my $file_data = $self->write_temp($asset);
        if (! $file_data) {
            next;
        }
        push @files, $file_data;
    }
    unless (@files) {
        die "No assets to edit!\n";
    }

    my $command = $self->option('command') || $ENV{EDITOR} || 'vi';
    system($command . ' ' . join(' ', map { $_->{filename} } @files));

    my $versionTag;
    for my $file (@files) {
        if ((stat($file->{filename}))[9] <= $file->{mtime}) {
            warn "Skipping " . $file->{asset}->get('url') . ", not changed.\n";
            unlink $file->{filename};
            next;
        }
        $versionTag ||= do {
            my $vt = WebGUI::VersionTag->getWorking($wgd->session);
            $vt->set({name=>"WGDev Asset Editor"});
            $vt;
        };
        open my $fh, '<:utf8', $file->{filename} || next;
        my $asset_text = do { local $/; <$fh> };
        close $fh;
        unlink $file->{filename};
        my $asset_data = $wgd->asset->deserialize($asset_text);
        $file->{asset}->addRevision($asset_data);
    }

    if ($versionTag) {
        $versionTag->commit;
    }
    return 1;
}

sub write_temp {
    my $self = shift;
    my $asset = shift;

    my ($fh, $filename) = File::Temp::tempfile();
    binmode $fh, ':utf8';
    print {$fh} $self->wgd->asset->serialize($asset);
    close $fh or return;
    return {
        asset       => $asset,
        filename    => $filename,
        mtime       => (stat($filename))[9],
    };
}

1;

__END__

=head1 NAME

WGDev::Command::Edit - Edits assets by URL

=head1

wgd edit [--command=<command>] <asset> [<asset> ...]

=head1 DESCRIPTION

Exports asset to temporary files, then opens them in your prefered editor.
If modifications are made, the assets are updated.

=head1 OPTIONS

=over 8

=item B<--command>

Command to be executed.  If not specified, uses the EDITOR environment
variable.  If that is not specified, uses vi.

=item B<E<lt>assetE<gt>>

Either a URL or an asset ID of an asset.  As many can be specified as desired.
Prepending with a slash will force it to be interpreted as a URL.

=back

=head1 AUTHOR

Graham Knop <graham@plainblack.com>

=head1 LICENSE

Copyright (c) Graham Knop.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

