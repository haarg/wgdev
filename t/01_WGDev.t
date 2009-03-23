use strict;
use warnings;

use Test::More tests => 7;
use Test::Exception;

use WGDev;
use File::Spec;

my $wgd = WGDev->new;

isa_ok $wgd, 'WGDev', 'WGDev->new returns WGDev object';

throws_ok { $wgd->set_environment } qr/^\QWebGUI root not set/,
    'Exception thrown for ->set_environment with no root set';

my $test_data = File::Spec->catdir(File::Spec->catpath( (File::Spec->splitpath(__FILE__))[0,1], q{} ), 'testdata');
my $root_invalid = File::Spec->catdir($test_data, 'root_invalid');
my $root = File::Spec->catdir($test_data, 'root_one_config');
my $config = File::Spec->catfile($root, 'etc', 'localhost.conf');

throws_ok { $wgd->root($root_invalid) } qr/^\QInvalid WebGUI path:/,
    'Exception thrown for ->root with invalid WebGUI root';

lives_ok { $wgd->root($root) }
    'Able to set valid WebGUI root';

throws_ok { $wgd->config } qr/^\Qno config file available/,
    'Exception thrown for ->config with no config file set';

lives_ok { $wgd->config_file('localhost.conf') }
    'Able to set valid WebGUI config relative to root/etc';

lives_ok { $wgd->config }
    'Able to retrieve config if config set';


