package WGDev::Command::Edit;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.1.0';

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

use constant STAT_MTIME => 9;

sub option_config {
    return qw(
        command=s
    );
}

sub process {
    my $self = shift;
    my $wgd  = $self->wgd;

    my @files;
    for my $asset_spec ( $self->arguments ) {
        my $asset = $wgd->asset->find($asset_spec) || do {
            warn "$asset_spec is not a valid asset!\n";
            next;
        };
        my $file_data = $self->write_temp($asset);
        if ( !$file_data ) {
            next;
        }
        push @files, $file_data;
    }
    if ( !@files ) {
        die "No assets to edit!\n";
    }

    my $command = $self->option('command') || $ENV{EDITOR} || 'vi';
    ##no critic (ProhibitParensWithBuiltins)
    system join( q{ }, $command, map { $_->{filename} } @files );

    my $version_tag;
    for my $file (@files) {
        if ( ( stat $file->{filename} )[STAT_MTIME] <= $file->{mtime} ) {
            warn 'Skipping '
                . $file->{asset}->get('url')
                . ", not changed.\n";
            unlink $file->{filename};
            next;
        }
        $version_tag ||= do {
            require WebGUI::VersionTag;
            my $vt = WebGUI::VersionTag->getWorking( $wgd->session );
            $vt->set( { name => 'WGDev Asset Editor' } );
            $vt;
        };
        open my $fh, '<:utf8', $file->{filename} or next;
        my $asset_text = do { local $/ = undef; <$fh> };
        close $fh or next;
        unlink $file->{filename};
        my $asset_data = $wgd->asset->deserialize($asset_text);
        $file->{asset}->addRevision($asset_data);
    }

    if ($version_tag) {
        $version_tag->commit;
    }
    return 1;
}

sub write_temp {
    my $self  = shift;
    my $asset = shift;

    require File::Temp;

    my ( $fh, $filename ) = File::Temp::tempfile();
    binmode $fh, ':utf8';
    print {$fh} $self->wgd->asset->serialize($asset);
    close $fh or return;
    return {
        asset    => $asset,
        filename => $filename,
        mtime    => ( stat $filename )[STAT_MTIME],
    };
}

1;

__END__

=head1 NAME

WGDev::Command::Edit - Edits assets by URL

=head1 SYNOPSIS

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

