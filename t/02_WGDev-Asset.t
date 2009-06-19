use strict;
use warnings;

use Test::More 'no_plan';
use Test::NoWarnings;
use Test::MockObject;

use File::Spec::Functions qw(catdir catfile catpath rel2abs splitpath);
use Cwd qw(realpath cwd);

use constant TEST_DIR => catpath( (splitpath(__FILE__))[0,1], '' );
use lib catdir(TEST_DIR, 'lib');

BEGIN {
    Test::MockObject->fake_module('WebGUI::Session');
    Test::MockObject->fake_module('WebGUI::Asset');
    Test::MockObject->fake_module('WebGUI::Asset::FakeAsset');
}

use WGDev::Asset ();

my $session = Test::MockObject->new;
$session->set_isa('WebGUI::Session');

my $wgda = WGDev::Asset->new($session);
isa_ok($wgda, 'WGDev::Asset');

