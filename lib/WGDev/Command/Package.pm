package WGDev::Command::Package;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.1.0';

use WGDev::Command::Base;
our @ISA = qw(WGDev::Command::Base);

sub process {
    my $self = shift;
    my $wgd = $self->wgd;
    require File::Copy;
    my $package_dir = File::Spec->catdir($wgd->root, 'docs', 'upgrades', 'packages-' . $wgd->version->module);
    if (! -d $package_dir) {
        mkdir $package_dir;
    }
    for my $url ($self->arguments) {
        my $asset = $wgd->asset->by_url($url);
        my $storage = $asset->exportPackage;
        my $filename = $storage->getFiles->[0];
        my $filepath = $storage->getPath($filename);
        File::Copy::copy($filepath, File::Spec->catfile($package_dir, $filename));
        print "Built package $filename.\n";
    }
    return 1;
}

1;

__END__

=head1 NAME

WGDev::Command::Package - Export assets for upgrade

=head1 SYNOPSIS

wgd package <asset url> [<asset url> ...]

=head1 DESCRIPTION

Exports assets as packages to the current version's upgrade location.

=head1 OPTIONS

=over 8

=item B<E<lt>asset urlE<gt>>

URL of asset to export as package.  As many as desired can be specified.

=head1 AUTHOR

Graham Knop <graham@plainblack.com>

=head1 LICENSE

Copyright (c) Graham Knop.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

