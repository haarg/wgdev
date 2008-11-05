package WGDev::Command::Package;
use strict;
use warnings;

our $VERSION = '0.1.0';

use Getopt::Long ();

sub run {
    my $class = shift;
    my $wgd = shift;
    require File::Copy;
    Getopt::Long::Configure(qw(default gnu_getopt));
    Getopt::Long::GetOptionsFromArray(\@_,
    );
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
}

1;

