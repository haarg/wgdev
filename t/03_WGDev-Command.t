use strict;
use warnings;

use Test::More 'no_plan';
use Test::NoWarnings;
use Test::Exception;
use Test::Warn;

use File::Spec::Functions qw(catdir catfile catpath rel2abs splitpath);
use Cwd qw(realpath cwd);
use File::Temp ();
use File::Copy qw(copy);
use Config ();
use JSON ();

use constant TEST_DIR => catpath( ( splitpath(realpath(__FILE__)) )[ 0, 1 ], '' );

use lib catdir( TEST_DIR, 'lib' );
local $ENV{PATH} = join $Config::Config{path_sep}, catdir( TEST_DIR, 'bin' ),
    $ENV{PATH};

use Test::WGDev;

use WGDev                          ();
use WGDev::Command                 ();
use WGDev::Command::_test          ();
use WGDev::Command::_test_baseless ();
use WGDev_tester_command           ();
use WGDev::Help                    ();

BEGIN { $INC{'WGDev/Command/_tester.pm'} = $INC{'WGDev_tester_command.pm'} }

my $test_data = catdir( TEST_DIR, 'testdata' );

# we don't want the user's configuration interfering with the test
local $ENV{WEBGUI_ROOT};
local $ENV{WEBGUI_CONFIG};

my ( $ret, $output );
$output = capture_output {
    ok +WGDev::Command->report_version, 'report_version returns true value';
};
is $output, 'WGDev::Command version ' . WGDev::Command->VERSION . "\n",
    'version number reported to standard output';

$output = capture_output {
    ok +WGDev::Command->report_version(
        'command name', 'WGDev::Command::_test_baseless'
    ),
        'report_version with module returns true value';
};
is $output,
    sprintf(
    "WGDev::Command version %s - WGDev::Command::_test_baseless version %s\n",
    WGDev::Command->VERSION, WGDev::Command::_test_baseless->VERSION
    ),
    'version number of additional module reported to standard output';

$output = capture_output {
    ok +WGDev::Command->report_help, 'report_help returns true value';
};
my $general_usage
    = WGDev::Command->usage( 1 );
is $output, $general_usage, 'report_help prints usage message';

warning_like {
    $output = capture_output {
        ok +WGDev::Command->report_help(
            'command name', 'WGDev::Command::_test_baseless'
        ), 'report_help returns true value for command with no usage info';
    };
} qr{^\QNo documentation for command name command.\E$},
    'report_help warns about command with no usage info';
is $output, q{}, 'report_help prints nothing if command has no usage info';

$output = capture_output {
    ok +WGDev::Command->report_help(
        'command name', 'WGDev::Command::_test'
    ), 'report_help returns true value for command with usage info';
};
is $output, WGDev::Command::_test->usage,
    'report_help prints usage info for provided command';

is +WGDev::Command::get_command_module('_test'), 'WGDev::Command::_test',
    'get_command_module finds normal command modules';

is +WGDev::Command::get_command_module('_test-subclass'),
    'WGDev::Command::_test::Subclass',
    'get_command_module finds subclass command modules';

throws_ok { WGDev::Command::get_command_module('base') } 'WGDev::X::BadCommand',
    q{get_command_module throws exception for existing command modules that aren't runnable};

throws_ok { WGDev::Command::get_command_module('_nonexistant') } 'WGDev::X::BadCommand',
    'get_command_module throws exception for nonexisting command modules';

is +WGDev::Command::command_to_module('command'), 'WGDev::Command::Command',
    'command_to_module converts command name to module name properly';

is +WGDev::Command::command_to_module('sub-command'),
    'WGDev::Command::Sub::Command',
    'command_to_module converts multi-part command name to module name properly';

is +WGDev::Command::_find_cmd_exec('tester-executable'),
    catfile( TEST_DIR, 'bin', 'wgd-tester-executable' ),
    '_find_cmd_exec returns file path for executables in path starting with wgd-';
is +WGDev::Command::_find_cmd_exec('tester-non-executable'), undef,
    '_find_cmd_exec returns undef for non-executables in path starting with wgd-';

my $usage_base = WGDev::Help::package_usage('WGDev::Command');
is +WGDev::Command->usage, $usage_base,
    'usage with no parameters gives base usage';

my $usage_verbosity_0 = WGDev::Help::package_usage( 'WGDev::Command', 0 );
is +WGDev::Command->usage(0), $usage_verbosity_0,
    'usage with one parameter treats it as verbosity';

my @commands = WGDev::Command->command_list;

is +( grep { $_ eq 'util' } @commands ), 1,
    'command_list includes unloaded commands';

is +( grep { $_ eq '_test' } @commands ), 1,
    'command_list includes loaded commands';

is +( grep { $_ eq '_tester' } @commands ), 1,
    'command_list includes commands with mismatched filename and package';

is +( grep { $_ eq 'tester-executable' } @commands ), 1,
    'command_list includes standalone executables in path';

is +( grep { $_ eq 'tester-non-executable' } @commands ), 0,
    q{command_list doesn't include standalone non-executables in path};

is +( grep { $_ eq 'base' } @commands ), 0,
    q{command_list doesn't include command modules that are not runnable};

my $emptydir = File::Temp->newdir;
my $root     = File::Temp->newdir;

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

my $module = catfile( $lib, 'WebGUI.pm' );
copy catfile( $test_data, 'WebGUI.pm' ), $module;

my $root_abs   = realpath($root);
my $lib_abs    = realpath($lib);
my $config_abs = realpath($config);

# TODO: use some kind of proper API for this
my $command_config = {
    webgui_root   => undef,
    webgui_config => undef,
};
{
    no warnings 'redefine';
    sub WGDev::write_wgd_config {
        return 1;
    }
    sub WGDev::read_wgd_config {
        my $self = shift;
        return $self->{wgd_config} = { command => $command_config, };
    }
}

## guess_webgui_paths tests

{
    my $saved = guard_chdir $emptydir;
    my $wgd = WGDev->new;
    lives_and { is +WGDev::Command->guess_webgui_paths(wgd => $wgd), $wgd }
        q{guess_webgui_paths returns WGDev object when unable to locate WebGUI paths};

    is $wgd->root, undef, '... and leaves root as undef';
    is $wgd->config_file, undef, '... and leaves config_file as undef';
}

## testing setting root
{
    my $saved = guard_chdir $root;
    my $wgd = WGDev->new;
    lives_and {
        is +WGDev::Command->guess_webgui_paths(wgd => $wgd), $wgd;
    } 'guess_webgui_paths returns WGDev object when finding path based on current';

    is_path $wgd->root, $root_abs,
        '... and sets root path correctly';

    is $wgd->config_file, undef,
        '... and leaves config_file as undef';
}

{
    my $saved = guard_chdir $sbin;
    lives_and {
        is_path +WGDev::Command->guess_webgui_paths(wgd => WGDev->new)->root, $root_abs;
    } 'guess_webgui_paths finds root searching updward from current dir';
}

{
    local $ENV{WEBGUI_ROOT} = $root_abs;
    lives_and {
        is_path +WGDev::Command->guess_webgui_paths(wgd => WGDev->new)->root,
            $root_abs;
    } 'guess_webgui_paths finds root given by environment';
}

{
    local $command_config->{webgui_root} = $root_abs;
    lives_and {
        is_path +WGDev::Command->guess_webgui_paths(wgd => WGDev->new)->root,
            $root_abs;
    } 'guess_webgui_paths finds root given by wgdevcfg file';
}


{
    my $saved = guard_chdir $root;
    throws_ok { WGDev::Command->guess_webgui_paths( wgd => WGDev->new, root => $emptydir ) }
        'WGDev::X::BadParameter',
        'guess_webgui_paths throws correct error for invalid dir when in valid dir';
}

{
    my $saved = guard_chdir $root;
    local $ENV{WEBGUI_ROOT} = $emptydir;
    throws_ok { WGDev::Command->guess_webgui_paths(wgd => WGDev->new) } 'WGDev::X::BadParameter',
        'guess_webgui_paths throws correct error for invalid dir set via ENV when in valid dir';
}

{
    my $saved = guard_chdir $root;
    local $command_config->{webgui_root} = $emptydir;
    throws_ok { WGDev::Command->guess_webgui_paths(wgd => WGDev->new) } 'WGDev::X::BadParameter',
        'guess_webgui_paths throws correct error for invalid dir set via wgdevcfg file when in valid dir';
}

## testing setting config
{
    my $wgd = WGDev->new;
    lives_ok { WGDev::Command->guess_webgui_paths( wgd => $wgd, config_file => $config_abs ) }
        'guess_webgui_paths lives when given absolute config file';

    is_path $wgd->root, $root_abs, '... and finds correct WebGUI root';
    is_path $wgd->config_file, $config_abs, '... and sets correct config file';
}

lives_and {
    is_path +WGDev::Command->guess_webgui_paths(
        wgd => WGDev->new,
        root => $root_abs,
        config_file => 'www.example.com.conf',
    )->config_file, $config_abs;
} 'guess_webgui_paths finds config file when given bare filename';

{
    local $ENV{WEBGUI_CONFIG} = 'www.example.com.conf';
    lives_and {
        is_path +WGDev::Command->guess_webgui_paths(
            wgd => WGDev->new,
            root => $root_abs,
        )->config_file, $config_abs;
    } 'guess_webgui_paths finds config file from ENV';
}

{
    local $command_config->{webgui_config} = 'www.example.com.conf';
    lives_and {
        is_path +WGDev::Command->guess_webgui_paths(
            wgd => WGDev->new,
            root => $root_abs,
        )->config_file, $config_abs;
    } 'guess_webgui_paths finds config file from wgdevcfg file';
}

{
    my $saved = guard_chdir $root;
    lives_and {
        is_path +WGDev::Command->guess_webgui_paths(
            wgd => WGDev->new,
            config_file => 'www.example.com.conf',
        )->config_file, $config_abs;
    } 'guess_webgui_paths finds config file with root based on current directory';
}

{
    my $saved = guard_chdir $sbin;
    lives_and {
        is_path +WGDev::Command->guess_webgui_paths(
            wgd => WGDev->new,
            config_file => 'www.example.com.conf',
        )->config_file, $config_abs;
    } 'guess_webgui_paths finds config file with root from upward search';
}

{
    my $invalid_config = catfile($emptydir, 'nonexistant');
    throws_ok { WGDev::Command->guess_webgui_paths( wgd => WGDev->new, config_file => $invalid_config ) }
        'WGDev::X::BadParameter',
        'guess_webgui_paths throws correct exception for invalid config file';

    SKIP: {
        my $e = WGDev::X::BadParameter->caught;
        skip 'no exception to test', 1 if !$e;
        is $e->value, $invalid_config, '... and exception lists the correct filename';
    }
}

{
    my $wgd = WGDev->new;
    my $test_config = catfile( $test_data, 'www.example.com.conf' );
    lives_ok {
        WGDev::Command->guess_webgui_paths(
            wgd => $wgd,
            config_file => $test_config,
        );
    } 'guess_webgui_paths lives when given a config file without a valid root';
    is $wgd->root, undef, '... and leaves root set to undef';
    is_path $wgd->config_file, $test_config, '... and sets the correct config_file';
}

lives_and {
    is_path +WGDev::Command->guess_webgui_paths(
        wgd         => WGDev->new,
        config_file => catfile($etc, 'www.example.com'),
        root        => $root_abs,
    )->config_file, $config_abs;
} 'guess_webgui_paths intelligently adds .conf to config file';

lives_and {
    is_path +WGDev::Command->guess_webgui_paths(
        wgd         => WGDev->new,
        config_file => 'www.example.com',
        root        => $root_abs,
    )->config_file, $config_abs;
} 'guess_webgui_paths intelligently adds .conf to bare config file';

{
    my $saved = guard_chdir $root;
    lives_and {
        is_path +WGDev::Command->guess_webgui_paths(
            wgd         => WGDev->new,
            config_file => 'www.example.com',
        )->config_file, $config_abs;
    } 'guess_webgui_paths intelligently adds .conf to config file with guessed root';
}

my $config2_abs = catfile($etc, 'www.example2.com.conf');
{
    my $json = JSON->new->relaxed->pretty;
    open my $fh, '<', catfile($test_data, 'www.example.com.conf');
    my $config_data = $json->decode(scalar do { local $/; <$fh> });
    close $fh;
    $config_data->{sitename} = ['www.example2.com', 'www.example.com'];
    open $fh, '>', $config2_abs;
    print {$fh} $json->encode($config_data);
    close $fh;
}

{
    my $saved = guard_chdir $root;
    lives_and {
        is_path +WGDev::Command->guess_webgui_paths(
            wgd => WGDev->new,
            root => $root,
            sitename => 'www.example2.com',
        )->config_file, $config2_abs;
    }
    'guess_webgui_paths finds config file when given sitename';

    throws_ok {
        WGDev::Command->guess_webgui_paths( wgd => WGDev->new, root => $root, sitename => 'www.example.com' )
    } 'WGDev::X',
        'guess_webgui_paths throws error for ambiguous sitenames';

    throws_ok {
        WGDev::Command->guess_webgui_paths( wgd => WGDev->new, root => $root, sitename => 'www.newexample.com' )
    } 'WGDev::X',
        'guess_webgui_paths throws error for invalid sitenames';

    {
        local $ENV{WEBGUI_SITENAME} = 'www.example2.com';
        lives_and {
            is_path +WGDev::Command->guess_webgui_paths(
                wgd => WGDev->new,
                root => $root,
            )->config_file, $config2_abs;
        } 'guess_webgui_paths finds config file when given sitename through ENV';
    }

    {
        local $command_config->{webgui_sitename} = 'www.example2.com';
        lives_and {
            is_path +WGDev::Command->guess_webgui_paths(
                wgd => WGDev->new,
                root => $root,
            )->config_file, $config2_abs;
        }
        'guess_webgui_paths finds config file when given sitename through config file';
    }

    {
        local $ENV{WEBGUI_CONFIG} = $config_abs;
        lives_and {
            is_path +WGDev::Command->guess_webgui_paths(
                wgd => WGDev->new,
                root => $root,
                sitename => 'www.example2.com',
            )->config_file, $config2_abs;
        }
        'guess_webgui_paths finds config file when given sitename and config is set through ENV';
    }

    # TODO: Add more tests for sitename/config conflicts
}

my $return;
$output = capture_output {
    $return = WGDev::Command->run;
};
like $output, qr/^\QRun WGDev commands/, 'run with no params outputs correct message';
ok $return, '... and returns a true value';

