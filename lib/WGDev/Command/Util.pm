package WGDev::Command::Util;
use strict;
use warnings;

our $VERSION = '0.0.1';
use File::Spec;

sub run {
    my $class = shift;
    my $wgd = shift;
    my $util = shift;
    my $util_file = $wgd->root . '/sbin/' . $util;
    die "no utility script $util_file!\n"
        unless -e $util_file;

    chdir $wgd->root . '/sbin/';
    exec {$^X} $^X, $util_file, '--configFile=' . $wgd->config_file_relative, @_;
}

1;

