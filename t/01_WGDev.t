use strict;
use warnings;

use Test::More 'no_plan'; #tests => 19;
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
my $root = File::Spec->catdir($test_data, 'root');
my $lib = File::Spec->catdir($root, 'lib');
my $config = File::Spec->catfile($root, 'etc', 'localhost.conf');
my $sbin = File::Spec->catdir($root, 'sbin');

my $root_abs = File::Spec->rel2abs($root);
my $lib_abs = File::Spec->rel2abs($lib);
my $config_abs = File::Spec->rel2abs($config);

mkdir File::Spec->catdir($root, 'sbin');
unlink File::Spec->catfile($root, 'sbin', 'preload.custom');

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

isa_ok $wgd->config, 'Config::JSON',
    'Config::JSON object returned returned from ->config';

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

    is $ENV{PERL5LIB}, $lib_abs . $Config::Config{path_sep} . $lib, 'set_environment adds lib path to existing PERL5LIB';

    $wgd->reset_environment;
}

$wgd = WGDev->new($root, $config);

is $wgd->root, $root_abs, 'Can initialize root on new call';

$wgd = WGDev->new($config, $root);

is $wgd->root, $root_abs, 'Can initialize root on new call in reverse order';

throws_ok { $wgd->root($lib) } qr/^\QInvalid WebGUI path: $lib/,
    'Error thrown when trying to set root to directory that isn\'t a WebGUI root';

my $nonexistant_path = File::Spec->catdir($root, 'nonexistant');
throws_ok { $wgd->root($nonexistant_path) } qr/^\QInvalid WebGUI path: $nonexistant_path/,
    'Error thrown when trying to set root to directory that doesn\'t exist';

is $wgd->root, $root_abs, 'Root not modified after failed attempts to set';

throws_ok { $wgd->config_file('nonexistant') } qr/^\QInvalid WebGUI config file: nonexistant/,
    'Error thrown when trying to set config to nonexistant file with root set';

$wgd = WGDev->new;

throws_ok { $wgd->config_file('nonexistant') } qr/^\QInvalid WebGUI config file: nonexistant/,
    'Error thrown when trying to set config to nonexistant file with no root set';

lives_ok { $wgd->config_file($config_abs) }
    'Can set just config file using full path';

is Cwd::realpath($wgd->root), Cwd::realpath($root_abs), 'Root set correctly based on absolute config file';

ok scalar(grep { $_ eq $wgd->lib } @INC), 'WebGUI lib path added to @INC';

open my $fh, '>', File::Spec->catfile($sbin, 'preload.custom');
print {$fh} $sbin . "\n";
print {$fh} File::Spec->catdir($root, 'nonexistant') . "\n";
print {$fh} $config . "\n";
close $fh;

$wgd = WGDev->new($config);

is_deeply [map {Cwd::realpath($_)} $wgd->lib], [map {Cwd::realpath($_)} ($sbin, $lib)],
    'WebGUI lib paths are read from preload.custom, ignoring invalid entries';

is Cwd::realpath(scalar $wgd->lib), Cwd::realpath($lib), '->lib in scalar context returns primary lib path';

chmod 0, File::Spec->catfile($sbin, 'preload.custom');

$wgd = WGDev->new($config);

is_deeply [map {Cwd::realpath($_)} $wgd->lib], [map {Cwd::realpath($_)} ($lib)],
    'Unreadable preload.custom silently ignored';

