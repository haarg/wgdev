use strict;
use warnings;

use Test::More;
use Test::Exception;

use File::Spec::Functions qw(catdir catfile catpath rel2abs splitpath);
use Cwd qw(realpath);
use File::Temp 0.19 ();
use File::Copy qw(copy);
use Config ();

use constant TEST_DIR =>
    catpath( ( splitpath( realpath(__FILE__) ) )[ 0, 1 ], '' );

use lib catdir( TEST_DIR, 'lib' );

use Test::WGDev;

use WGDev ();

use constant HAS_DONE_TESTING => Test::More->can('done_testing') ? 1 : undef;

# use done_testing if possible
if ( !HAS_DONE_TESTING ) {
    plan 'no_plan';
}

my $test_data = catdir( TEST_DIR, 'testdata' );

my $wgd = WGDev->new;

isa_ok $wgd, 'WGDev', 'WGDev->new returns WGDev object';

throws_ok { $wgd->set_environment } 'WGDev::X::NoWebGUIRoot',
    'Exception thrown for ->set_environment with no root set';

{
    my $root_invalid = File::Temp->newdir;
    throws_ok { $wgd->root($root_invalid) } 'WGDev::X::BadParameter',
        'Exception thrown for ->root with invalid WebGUI root';
}

my $root = File::Temp->newdir;

my $docs = catdir( $root, 'docs' );
my $etc  = catdir( $root, 'etc' );
my $lib  = catdir( $root, 'lib' );
my $sbin = catdir( $root, 'sbin' );
mkdir $docs;
mkdir $etc;
mkdir $lib;
mkdir $sbin;

my $config = catfile( $etc, 'www.example.com.conf' );
copy catfile( $test_data, 'www.example.com.conf' ), $config;
copy catfile( $test_data, 'www.example.com.conf' ),
    catfile( $etc, 'WebGUI.conf.original' );
my $config_broken = catfile( $etc, 'www.broken.com.conf' );
{
    open my $fh, '>', $config_broken;
    print {$fh} 'garbage data';
    close $fh;
}

my $module = catfile( $lib, 'WebGUI.pm' );
copy catfile( $test_data, 'WebGUI.pm' ), $module;

my $root_abs   = File::Spec->rel2abs($root);
my $lib_abs    = File::Spec->rel2abs($lib);
my $config_abs = File::Spec->rel2abs($config);

lives_ok { $wgd->root($root) } 'Able to set valid WebGUI root';

is $wgd->root, $root_abs, 'WebGUI root set correctly';

throws_ok { $wgd->config } 'WGDev::X::NoWebGUIConfig',
    'Exception thrown for ->config with no config file set';

throws_ok { $wgd->set_environment } 'WGDev::X::NoWebGUIConfig',
    'Exception thrown for ->set_environment with no config file set';

lives_ok { $wgd->config_file('www.example.com.conf') }
'Able to set valid WebGUI config relative to root/etc';

isa_ok $wgd->config, 'Config::JSON',
    'Config::JSON object returned returned from ->config';

is $wgd->config_file, $config_abs, 'Config file path set correctly';

lives_ok { $wgd->config } 'Able to retrieve config if config set';

{
    local $ENV{WEBGUI_ROOT}   = 'initial value';
    local $ENV{WEBGUI_CONFIG} = 'initial value';
    local $ENV{PERL5LIB};

    $wgd->reset_environment;

    is $ENV{WEBGUI_ROOT}, 'initial value',
        'reset_environment doesn\'t change env if not previously set';

    lives_ok { $wgd->set_environment }
    'Able to ->set_environment if config file set';

    is $ENV{WEBGUI_ROOT}, $root_abs,
        'WEBGUI_ROOT environment variable set correctly';
    is $ENV{WEBGUI_CONFIG}, $config_abs,
        'WEBGUI_CONFIG environment variable set correctly';
    is $ENV{PERL5LIB}, $lib_abs,
        'PERL5LIB environment variable set correctly';

    $wgd->set_environment;

    $wgd->reset_environment;

    is $ENV{WEBGUI_ROOT}, 'initial value',
        'reset_environment sets environment variables back to initial values';

    $ENV{PERL5LIB} = $lib;

    $wgd->set_environment;

    is $ENV{PERL5LIB}, $lib_abs . $Config::Config{path_sep} . $lib,
        'set_environment adds lib path to existing PERL5LIB';

    $wgd->reset_environment;
}

$wgd = WGDev->new( $root, $config );

is $wgd->root, $root_abs, 'Can initialize root on new call';

$wgd = WGDev->new( $config, $root );

is $wgd->root, $root_abs, 'Can initialize root on new call in reverse order';

throws_ok { $wgd->root($lib) } 'WGDev::X::BadParameter',
    'Error thrown when trying to set root to directory that isn\'t a WebGUI root';

my $nonexistant_path = catdir( $root, 'nonexistant' );
throws_ok { $wgd->root($nonexistant_path) } 'WGDev::X::BadParameter',
    'Error thrown when trying to set root to directory that doesn\'t exist';

is $wgd->root, $root_abs, 'Root not modified after failed attempts to set';

throws_ok { $wgd->config_file('nonexistant') } 'WGDev::X::BadParameter',
    'Error thrown when trying to set config to nonexistant file with root set';

throws_ok { $wgd->config_file($config_broken) } 'WGDev::X::BadParameter',
    'Error thrown when trying to set config to broken config file';

$wgd = WGDev->new;

throws_ok { $wgd->config_file('nonexistant') } 'WGDev::X::BadParameter',
    'Error thrown when trying to set config to nonexistant file with no root set';

lives_ok { $wgd->config_file($config_abs) }
'Can set just config file using full path';

is_path $wgd->root, $root_abs,
    'Root set correctly based on absolute config file';

ok scalar( grep { $_ eq $wgd->lib } @INC ), 'WebGUI lib path added to @INC';

ok $wgd->close_config, 'Can close config';
lives_and { isa_ok $wgd->config, 'Config::JSON' }
'Call to config reopens config as needed';

open my $fh, '>', catfile( $sbin, 'preload.custom' );
print {$fh} $sbin . "\n"
    . catdir( $root, 'nonexistant' ) . "\n"
    . $config . "\n";
close $fh;

$wgd = WGDev->new($config);

is_deeply [ map { realpath($_) } $wgd->lib ],
    [ map { realpath($_) } ( $sbin, $lib ) ],
    'WebGUI lib paths are read from preload.custom, ignoring invalid entries';

is_path scalar $wgd->lib, $lib,
    '->lib in scalar context returns primary lib path';

SKIP: {
    skip q{Can't test non-readability as root}, 1
        if $< == 0;

    chmod 0, catfile( $sbin, 'preload.custom' );

    $wgd = WGDev->new($config);

    is_deeply [ map { realpath($_) } $wgd->lib ],
        [ map { realpath($_) } ($lib) ],
        'Unreadable preload.custom silently ignored';
}

if (HAS_DONE_TESTING) {
    done_testing;
}

