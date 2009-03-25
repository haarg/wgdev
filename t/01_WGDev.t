use strict;
use warnings;

use Test::More tests => 19;
use Test::Exception;

use WGDev ();
use File::Spec ();
use Config ();

my $wgd = WGDev->new;

isa_ok $wgd, 'WGDev', 'WGDev->new returns WGDev object';

throws_ok { $wgd->set_environment } qr/^\QWebGUI root not set/,
    'Exception thrown for ->set_environment with no root set';

my $test_data = File::Spec->catdir(File::Spec->catpath( (File::Spec->splitpath(__FILE__))[0,1], q{} ), 'testdata');
my $root_invalid = File::Spec->catdir($test_data, 'root_invalid');
my $root = File::Spec->catdir($test_data, 'root_one_config');
my $lib = File::Spec->catdir($root, 'lib');
my $config = File::Spec->catfile($root, 'etc', 'localhost.conf');

my $root_abs = File::Spec->rel2abs($root);
my $lib_abs = File::Spec->rel2abs($lib);
my $config_abs = File::Spec->rel2abs($config);

throws_ok { $wgd->root($root_invalid) } qr/^\QInvalid WebGUI path:/,
    'Exception thrown for ->root with invalid WebGUI root';

lives_ok { $wgd->root($root) }
    'Able to set valid WebGUI root';

is $wgd->root, $root_abs, 'WebGUI root set correctly';

throws_ok { $wgd->config } qr/^\Qno config file available/,
    'Exception thrown for ->config with no config file set';

throws_ok { $wgd->set_environment } qr/^\QWebGUI config file not set/,
    'Exception thrown for ->set_environment with no config file set';

lives_ok { $wgd->config_file('localhost.conf') }
    'Able to set valid WebGUI config relative to root/etc';

is $wgd->config_file, $config_abs, 'Config file path set correctly';

lives_ok { $wgd->config }
    'Able to retrieve config if config set';

{
    local $ENV{WEBGUI_ROOT} = 'initial value';
    local $ENV{WEBGUI_CONFIG} = 'initial value';
    local $ENV{PERL5LIB};

    $wgd->reset_environment;

    is $ENV{WEBGUI_ROOT}, 'initial value', 'reset_environment doesn\'t change env if not previously set';

    lives_ok { $wgd->set_environment }
        'Able to ->set_environment if config file set';

    is $ENV{WEBGUI_ROOT}, $root_abs, 'WEBGUI_ROOT environment variable set correctly';
    is $ENV{WEBGUI_CONFIG}, $config_abs, 'WEBGUI_CONFIG environment variable set correctly';
    is $ENV{PERL5LIB}, $lib_abs, 'PERL5LIB environment variable set correctly';

    $wgd->set_environment;

    $wgd->reset_environment;

    is $ENV{WEBGUI_ROOT}, 'initial value', 'reset_environment sets environment variables back to initial values';

    $ENV{PERL5LIB} = $lib;

    $wgd->set_environment;

    is $ENV{PERL5LIB}, $lib_abs . $Config::Config{path_sep} . $lib;

    $wgd->reset_environment;
}

$wgd = WGDev->new($root, $config);

is $wgd->root, $root_abs, 'Can initialize root on new call';

$wgd = WGDev->new($config, $root);

is $wgd->root, $root_abs, 'Can initialize root on new call in reverse order';



