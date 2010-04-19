use strict;
use warnings;

use Test::More;
use Test::Exception;

use File::Spec::Functions qw(catdir catfile catpath rel2abs splitpath);
use Cwd qw(realpath cwd);

use constant TEST_DIR => catpath( ( splitpath(__FILE__) )[ 0, 1 ], '' );
use lib catdir( TEST_DIR, 'lib' );

use constant HAS_DONE_TESTING => Test::More->can('done_testing') ? 1 : undef;

# use done_testing if possible
if ( !HAS_DONE_TESTING ) {
    plan 'no_plan';
}

use WGDev::Help;

open my $fh, '<', catfile(TEST_DIR, 'lib', 'WGDev', 'PackageWithPod.pm') or die "$!";
while ( my $line = <$fh> ) {
    last
        if $line =~ /^__DATA__$/msx;
}
my $pod = do { local $/; <$fh> };
close $fh;
$pod =~ s/\A\s+//msx;
$pod =~ s/^=cut\s*\z//msx;

is WGDev::Help::package_pod('WGDev::PackageWithPod', [qw(NAME SYNOPSIS DESCRIPTION OPTIONS AUTHOR LICENSE)]), $pod,
    'can get pod from real file';

{
    my %fatpacked;

    $fatpacked{"WGDev/PackedPackage.pm"} = <<'WGDEV_PACKEDPACKAGE';
  package WGDev::PackedPackage;
  1;
  __DATA__
  
  =head1 NAME
  
  WGDev::PackedPackage - Abstract goes here
  
  =cut
WGDEV_PACKEDPACKAGE

    s/^  //mg for values %fatpacked;

    unshift @INC, sub {
        if (my $fat = $fatpacked{$_[1]}) {
            open my $fh, '<', \$fat;
            return $fh;
        }
        return
    };
}
is WGDev::Help::package_pod('WGDev::PackedPackage', 'NAME'), <<END_POD, 'can get pod from packed file';
=head1 NAME

WGDev::PackedPackage - Abstract goes here

END_POD

if (HAS_DONE_TESTING) {
    done_testing;
}

