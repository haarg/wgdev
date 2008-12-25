package WGDev::Command::Package;
use strict;
use warnings;

our $VERSION = '0.1.0';

use WGDev::Command::Base;
our @ISA = qw(WGDev::Command::Base);

sub option_config {qw(
    command=s
)}

sub process {
    my $self = shift;
    my $wgd = $self->wgd;
    require File::Copy;
    my $package_dir = File::Spec->catdir($wgd->root, 'docs', 'upgrades', 'packages-' . $wgd->version->module);
    if (! -d $package_dir) {
        mkdir $package_dir;
    }
    for my $url (@_) {
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

=head1 DESCRIPTION

Exports assets as packages to the current version's upgrade location.

arguments:
    <asset urls>    list of asset urls

=cut

