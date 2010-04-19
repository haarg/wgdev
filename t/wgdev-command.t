use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Warn;
use Test::MockObject;
use Test::MockObject::Extends;

use File::Spec::Functions qw(catdir catfile catpath rel2abs splitpath);
use Cwd qw(realpath cwd);
use File::Temp 0.19 ();
use File::Copy qw(copy);
use Config ();
use JSON   ();

use constant TEST_DIR =>
    catpath( ( splitpath( realpath(__FILE__) ) )[ 0, 1 ], '' );

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

use constant HAS_DONE_TESTING => Test::More->can('done_testing') ? 1 : undef;

# use done_testing if possible
if ( !HAS_DONE_TESTING ) {
    plan 'no_plan';
}

my $test_data = catdir( TEST_DIR, 'testdata' );

# we don't want the user's configuration interfering with the test
local $ENV{WEBGUI_ROOT};
local $ENV{WEBGUI_CONFIG};

my ( $ret, $output );
output_is {
    ok +WGDev::Command->report_version, 'report_version returns true value';
}
'WGDev::Command version ' . WGDev::Command->VERSION . "\n",
    '... and reports version number on standard output';

my $command_object = bless \( my $s ), 'WGDev::Command';
output_is {
    ok $command_object->report_version,
        'report_version on object returns true value';
}
'WGDev::Command version ' . WGDev::Command->VERSION . "\n",
    '... and reports version number on standard output';

output_is {
    ok +WGDev::Command->report_version(
        'command name', 'WGDev::Command::_test_baseless'
        ),
        'report_version with module returns true value';
}
sprintf(
    "WGDev::Command version %s - WGDev::Command::_test_baseless version %s\n",
    WGDev::Command->VERSION, WGDev::Command::_test_baseless->VERSION
    ),
    '... and reports version number of additional module on standard output';

output_is {
    ok +WGDev::Command->report_help, 'report_help returns true value';
}
WGDev::Command->usage(1), '... and prints usage message';

output_is {
    ok $command_object->report_help,
        'report_help on object returns true value';
}
WGDev::Command->usage(1), '... and prints usage message';

warning_like {
    output_is {
        ok +WGDev::Command->report_help(
            'command name', 'WGDev::Command::_test_baseless'
            ),
            'report_help returns true value for command with no usage info';
    }
    q{}, 'report_help prints nothing if command has no usage info';
}
qr{^\QNo documentation for command name command.\E$},
    'report_help warns about command with no usage info';

output_is {
    ok +WGDev::Command->report_help(
        'command name', 'WGDev::Command::_test'
        ),
        'report_help returns true value for command with usage info';
}
WGDev::Command::_test->usage,
    'report_help prints usage info for provided command';

is +WGDev::Command->get_command_module('_test'), 'WGDev::Command::_test',
    'get_command_module finds normal command modules';

is +WGDev::Command->get_command_module('_test-subclass'),
    'WGDev::Command::_test::Subclass',
    'get_command_module finds subclass command modules';

throws_ok { WGDev::Command->get_command_module('command...') }
'WGDev::X::BadCommand',
    q{get_command_module throws exception for invalid command names};

throws_ok { WGDev::Command->get_command_module('_test_cant_run') }
'WGDev::X::BadCommand',
    q{get_command_module throws exception for existing command modules with no run method};

throws_ok { WGDev::Command->get_command_module('_test_cant_is_runnable') }
'WGDev::X::BadCommand',
    q{get_command_module throws exception for existing command modules with no is_runnable method};

throws_ok { WGDev::Command->get_command_module('base') }
'WGDev::X::BadCommand',
    q{get_command_module throws exception for existing command modules that aren't runnable};

throws_ok { WGDev::Command->get_command_module('_nonexistant') }
'WGDev::X::BadCommand',
    'get_command_module throws exception for nonexisting command modules';

is +WGDev::Command->command_to_module('command'), 'WGDev::Command::Command',
    'command_to_module converts command name to module name properly';

is +WGDev::Command->command_to_module('sub-command'),
    'WGDev::Command::Sub::Command',
    'command_to_module converts multi-part command name to module name properly';

is +WGDev::Command->_find_cmd_exec('tester-executable'),
    catfile( TEST_DIR, 'bin', 'wgd-tester-executable' ),
    '_find_cmd_exec returns file path for executables in path starting with wgd-';
is +WGDev::Command->_find_cmd_exec('tester-non-executable'), undef,
    '_find_cmd_exec returns undef for non-executables in path starting with wgd-';

is +WGDev::Command->_find_cmd_exec(), undef,
    '_find_cmd_exec returns undef when not given command parameter';

my $usage_base = WGDev::Help::package_usage('WGDev::Command');
is +WGDev::Command->usage, $usage_base,
    'usage with no parameters gives base usage';

my $usage_verbosity_0 = WGDev::Help::package_usage( 'WGDev::Command', 0 );
is +WGDev::Command->usage(0), $usage_verbosity_0,
    'usage with one parameter treats it as verbosity';

my @commands = WGDev::Command->command_list;

is + ( grep { $_ eq 'util' } @commands ), 1,
    'command_list includes unloaded commands';

is + ( grep { $_ eq '_test' } @commands ), 1,
    'command_list includes loaded commands';

is + ( grep { $_ eq '_tester' } @commands ), 1,
    'command_list includes commands with mismatched filename and package';

is + ( grep { $_ eq 'tester-executable' } @commands ), 1,
    'command_list includes standalone executables in path';

is + ( grep { $_ eq 'tester-non-executable' } @commands ), 0,
    q{command_list doesn't include standalone non-executables in path};

is + ( grep { $_ eq 'base' } @commands ), 0,
    q{command_list doesn't include command modules that are not runnable};

is + ( grep { $_ eq '_test_cant_run' } @commands ), 0,
    q{command_list doesn't include command modules with no run method};

is + ( grep { $_ eq '_test_cant_is_runnable' } @commands ), 0,
    q{command_list doesn't include command modules with no is_runnable method};

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

copy catfile( $test_data, 'www.example.com.conf' ),
    catfile( $etc, 'WebGUI.conf.original' );
my $config = catfile( $etc, 'www.example.com.conf' );
copy catfile( $test_data, 'www.example.com.conf' ), $config;
my $config_in_empty = catfile( $emptydir, 'www.example.com.conf' );
copy catfile( $test_data, 'www.example.com.conf' ), $config_in_empty;
my $config_broken = catfile( $etc, 'www.broken.com.conf' );
{
    open my $fh, '>', $config_broken;
    print {$fh} 'garbage data';
    close $fh;
}

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
    my $wgd   = WGDev->new;
    lives_and { is +WGDev::Command->guess_webgui_paths( wgd => $wgd ), $wgd }
    q{guess_webgui_paths returns WGDev object when unable to locate WebGUI paths};

    is $wgd->root,        undef, '... and leaves root as undef';
    is $wgd->config_file, undef, '... and leaves config_file as undef';
}

## testing setting root
{
    my $saved = guard_chdir $root;
    my $wgd   = WGDev->new;
    lives_and {
        is +WGDev::Command->guess_webgui_paths( wgd => $wgd ), $wgd;
    }
    'guess_webgui_paths returns WGDev object when finding path based on current';

    is_path $wgd->root, $root_abs, '... and sets root path correctly';

    is $wgd->config_file, undef, '... and leaves config_file as undef';
}

{
    my $saved = guard_chdir $sbin;
    lives_and {
        is_path +WGDev::Command->guess_webgui_paths( wgd => WGDev->new )
            ->root, $root_abs;
    }
    'guess_webgui_paths finds root searching updward from current dir';
}

{
    local $ENV{WEBGUI_ROOT} = $root_abs;
    lives_and {
        is_path +WGDev::Command->guess_webgui_paths( wgd => WGDev->new )
            ->root,
            $root_abs;
    }
    'guess_webgui_paths finds root given by environment';
}

{
    local $command_config->{webgui_root} = $root_abs;
    lives_and {
        is_path +WGDev::Command->guess_webgui_paths( wgd => WGDev->new )
            ->root,
            $root_abs;
    }
    'guess_webgui_paths finds root given by wgdevcfg file';
}

{
    my $saved = guard_chdir $root;
    throws_ok {
        WGDev::Command->guess_webgui_paths(
            wgd  => WGDev->new,
            root => $emptydir
        );
    }
    'WGDev::X::BadParameter',
        'guess_webgui_paths throws correct error for invalid dir when in valid dir';
}

{
    my $saved = guard_chdir $root;
    local $ENV{WEBGUI_ROOT} = $emptydir;
    throws_ok { WGDev::Command->guess_webgui_paths( wgd => WGDev->new ) }
    'WGDev::X::BadParameter',
        'guess_webgui_paths throws correct error for invalid dir set via ENV when in valid dir';
}

{
    my $saved = guard_chdir $root;
    local $command_config->{webgui_root} = $emptydir;
    throws_ok { WGDev::Command->guess_webgui_paths( wgd => WGDev->new ) }
    'WGDev::X::BadParameter',
        'guess_webgui_paths throws correct error for invalid dir set via wgdevcfg file when in valid dir';
}

## testing setting config
{
    my $wgd = WGDev->new;
    lives_ok {
        WGDev::Command->guess_webgui_paths(
            wgd         => $wgd,
            config_file => $config_abs
        );
    }
    'guess_webgui_paths lives when given absolute config file';

    is_path $wgd->root, $root_abs, '... and finds correct WebGUI root';
    is_path $wgd->config_file, $config_abs,
        '... and sets correct config file';
}

{
    my $saved = guard_chdir $root;
    my $wgd   = WGDev->new;
    lives_ok {
        WGDev::Command->guess_webgui_paths(
            wgd         => $wgd,
            config_file => $config_in_empty
        );
    }
    'guess_webgui_paths lives when given absolute config file';

    is_path $wgd->root, $root_abs, '... and finds correct WebGUI root';
    is_path $wgd->config_file, $config_in_empty,
        '... and sets correct config file';
}

lives_and {
    is_path +WGDev::Command->guess_webgui_paths(
        wgd         => WGDev->new,
        root        => $root_abs,
        config_file => 'www.example.com.conf',
    )->config_file, $config_abs;
}
'guess_webgui_paths finds config file when given bare filename';

{
    throws_ok {
        WGDev::Command->guess_webgui_paths(
            wgd         => WGDev->new,
            config_file => 'www.example.com.conf',
        );
    }
    'WGDev::X', q{guess_webgui_paths throws if it can't find config file};

    my $mock = Test::MockObject::Extends->new('WGDev::Command');
    $mock->mock( 'set_config_by_input', sub { die "non-exception error\n" } );
    throws_ok {
        $mock->guess_webgui_paths(
            wgd         => WGDev->new,
            config_file => 'www.example.com.conf',
        );
    }
    'WGDev::X',
        q{guess_webgui_paths throws exception even if set_config_by_input fails some other way};
}

{
    local $ENV{WEBGUI_CONFIG} = 'www.example.com.conf';
    lives_and {
        is_path +WGDev::Command->guess_webgui_paths(
            wgd  => WGDev->new,
            root => $root_abs,
        )->config_file, $config_abs;
    }
    'guess_webgui_paths finds config file from ENV';
}

{
    local $command_config->{webgui_config} = 'www.example.com.conf';
    lives_and {
        is_path +WGDev::Command->guess_webgui_paths(
            wgd  => WGDev->new,
            root => $root_abs,
        )->config_file, $config_abs;
    }
    'guess_webgui_paths finds config file from wgdevcfg file';
}

{
    my $saved = guard_chdir $root;
    lives_and {
        is_path +WGDev::Command->guess_webgui_paths(
            wgd         => WGDev->new,
            config_file => 'www.example.com.conf',
        )->config_file, $config_abs;
    }
    'guess_webgui_paths finds config file with root based on current directory';
}

{
    my $saved = guard_chdir $sbin;
    lives_and {
        is_path +WGDev::Command->guess_webgui_paths(
            wgd         => WGDev->new,
            config_file => 'www.example.com.conf',
        )->config_file, $config_abs;
    }
    'guess_webgui_paths finds config file with root from upward search';
}

{
    my $invalid_config = catfile( $emptydir, 'nonexistant' );
    throws_ok {
        WGDev::Command->guess_webgui_paths(
            wgd         => WGDev->new,
            config_file => $invalid_config
        );
    }
    'WGDev::X::BadParameter',
        'guess_webgui_paths throws correct exception for invalid config file';

    SKIP: {
        my $e = WGDev::X::BadParameter->caught;
        skip 'no exception to test', 1 if !$e;
        is $e->value, $invalid_config,
            '... and exception lists the correct filename';
    }
}

{
    my $wgd = WGDev->new;
    my $test_config = catfile( $test_data, 'www.example.com.conf' );
    lives_ok {
        WGDev::Command->guess_webgui_paths(
            wgd         => $wgd,
            config_file => $test_config,
        );
    }
    'guess_webgui_paths lives when given a config file without a valid root';
    is $wgd->root, undef, '... and leaves root set to undef';
    is_path $wgd->config_file, $test_config,
        '... and sets the correct config_file';
}

lives_and {
    is_path +WGDev::Command->guess_webgui_paths(
        wgd         => WGDev->new,
        config_file => catfile( $etc, 'www.example.com' ),
        root        => $root_abs,
    )->config_file, $config_abs;
}
'guess_webgui_paths intelligently adds .conf to config file';

lives_and {
    is_path +WGDev::Command->guess_webgui_paths(
        wgd         => WGDev->new,
        config_file => 'www.example.com',
        root        => $root_abs,
    )->config_file, $config_abs;
}
'guess_webgui_paths intelligently adds .conf to bare config file';

{
    my $saved = guard_chdir $root;
    lives_and {
        is_path +WGDev::Command->guess_webgui_paths(
            wgd         => WGDev->new,
            config_file => 'www.example.com',
        )->config_file, $config_abs;
    }
    'guess_webgui_paths intelligently adds .conf to config file with guessed root';
}

my $config2_abs = catfile( $etc, 'www.example2.com.conf' );
{
    my $json = JSON->new->relaxed->pretty;
    open my $fh, '<', catfile( $test_data, 'www.example.com.conf' );
    my $config_data = $json->decode(
        scalar do { local $/; <$fh> }
    );
    close $fh;
    $config_data->{sitename} = [
        'www.example2.com', 'www.example.com',
        'www.example4.com', 'example5.com'
    ];
    open $fh, '>', $config2_abs;
    print {$fh} $json->encode($config_data);
    close $fh;
}

{
    my $saved = guard_chdir $root;
    lives_and {
        is_path +WGDev::Command->guess_webgui_paths(
            wgd      => WGDev->new,
            root     => $root,
            sitename => 'www.example2.com',
        )->config_file, $config2_abs;
    }
    'guess_webgui_paths finds config file when given sitename';

    lives_and {
        is_path +WGDev::Command->guess_webgui_paths(
            wgd      => WGDev->new,
            root     => $root,
            sitename => 'example2.com',
        )->config_file, $config2_abs;
    }
    'guess_webgui_paths finds config file when given shortened sitename';

    lives_and {
        is_path +WGDev::Command->guess_webgui_paths(
            wgd      => WGDev->new,
            root     => $root,
            sitename => 'www.example2.com',
        )->config_file, $config2_abs;
    }
    q{broken config file doesn't interfere with sitename search};

    throws_ok {
        WGDev::Command->guess_webgui_paths(
            wgd      => WGDev->new,
            root     => $root,
            sitename => 'www.example.com'
        );
    }
    'WGDev::X', 'guess_webgui_paths throws error for ambiguous sitenames';

    throws_ok {
        WGDev::Command->guess_webgui_paths(
            wgd      => WGDev->new,
            root     => $root,
            sitename => 'w.example2.com'
        );
    }
    'WGDev::X',
        q{guess_webgui_paths throws error for shortened sitename that isn't shortened on domain boundary};

    throws_ok {
        WGDev::Command->guess_webgui_paths(
            wgd      => WGDev->new,
            root     => $root,
            sitename => 'www.example2'
        );
    }
    'WGDev::X',
        q{guess_webgui_paths throws error for shortened sitename that is shortened on the wrong end};

    throws_ok {
        WGDev::Command->guess_webgui_paths(
            wgd      => WGDev->new,
            root     => $root,
            sitename => 'example4.com'
        );
    }
    'WGDev::X',
        'guess_webgui_paths throws error for ambiguous shortened sitename';

    throws_ok {
        WGDev::Command->guess_webgui_paths(
            wgd      => WGDev->new,
            root     => $root,
            sitename => 'example5.com'
        );
    }
    'WGDev::X',
        'guess_webgui_paths throws error for ambiguous sitenames even when exact match exists';

    throws_ok {
        WGDev::Command->guess_webgui_paths(
            wgd      => WGDev->new,
            root     => $root,
            sitename => 'www.newexample.com'
        );
    }
    'WGDev::X', 'guess_webgui_paths throws error for invalid sitenames';

    throws_ok {
        WGDev::Command->guess_webgui_paths(
            wgd         => WGDev->new,
            root        => $root,
            sitename    => 'www.example2.com',
            config_file => $config2_abs,
        );
    }
    'WGDev::X::BadParameter',
        'guess_webgui_paths throws error if given both sitename and config';

    {
        local $ENV{WEBGUI_SITENAME} = 'www.example2.com';
        lives_and {
            is_path +WGDev::Command->guess_webgui_paths(
                wgd  => WGDev->new,
                root => $root,
            )->config_file, $config2_abs;
        }
        'guess_webgui_paths finds config file when given sitename through ENV';
    }

    {
        local $command_config->{webgui_sitename} = 'www.example2.com';
        lives_and {
            is_path +WGDev::Command->guess_webgui_paths(
                wgd  => WGDev->new,
                root => $root,
            )->config_file, $config2_abs;
        }
        'guess_webgui_paths finds config file when given sitename through config file';
    }

    {
        local $ENV{WEBGUI_CONFIG} = $config_abs;
        lives_and {
            is_path +WGDev::Command->guess_webgui_paths(
                wgd      => WGDev->new,
                root     => $root,
                sitename => 'www.example2.com',
            )->config_file, $config2_abs;
        }
        'guess_webgui_paths finds config file when given sitename and config is set through ENV';
    }

    # TODO: Add more tests for sitename/config conflicts
}

throws_ok {
    my $wgd = WGDev->new;
    WGDev::Command->guess_webgui_paths(
        wgd         => $wgd,
        config_file => $config_broken
    );
}
'WGDev::X::BadParameter', 'throws when given a broken config file';

# TODO: test cwd in valid WebGUI root and specified config in different valid WebGUI root

throws_ok {
    WGDev::Command->run('invalid-command');
}
'WGDev::X::CommandLine::BadCommand',
    'run with invalid command throws correct error';

{
    no warnings qw(once redefine);
    local $INC{'WGDev/Command/Commands.pm'} = __FILE__;
    local *WGDev::Command::Commands::help = sub {'magic'};

    my $mock = Test::MockObject::Extends->new('WGDev::Command');
    $mock->mock(
        'usage',
        sub {
            $_[0]->{verbosity} = $_[1];
            return 'printed usage';
        } );

    output_is {
        is $mock->run, 'magic',
            'run with no params dispatches to WGDev::Command::Commands->help';
    }
    'printed usage', '... after printing usage information';
    is $mock->{verbosity}, 0, '... with verbosity of 0';
}

{
    no warnings qw(once redefine);

    # This normally can't fail with the config used
    local *Getopt::Long::GetOptions = sub {0};

    throws_ok {
        WGDev::Command->run;
    }
    'WGDev::X::CommandLine',
        'run throws correct error if option parsing failed somehow';
}

{
    no warnings qw(once redefine);
    my @run_params;
    local $INC{'WGDev/Command/Run.pm'} = __FILE__;
    local @WGDev::Command::Run::ISA = ();
    local *WGDev::Command::Run::is_runnable = sub {1};
    local *WGDev::Command::Run::new = sub {
        my $class = shift;
        return bless \( my $s ), $class;
    };
    local *WGDev::Command::Run::run = sub {
        my $self = shift;
        @run_params = @_;
        return 1;
    };

    my $exec_file = WGDev::Command->_find_cmd_exec('tester-executable');
    ok +WGDev::Command->run( 'tester-executable', 'parameter' ),
        'running external executable returns true value on success';
    is_deeply \@run_params, [ $exec_file, 'parameter' ],
        'running external executable dispatches correctly to WGDev::Command::Run';

    WGDev::Command->run( '-h', '-V', 'tester-executable', 'parameter' );
    is_deeply \@run_params, [ $exec_file, qw(--help --version parameter) ],
        'running external executable passes help and version params when requested';
}

{
    my $mock = Test::MockObject::Extends->new('WGDev::Command');
    $mock->set_true( 'report_version', 'report_help' );

    $mock->run( '_test', '--help' );
    $mock->called_ok( 'report_help',
        'run with --help switch calls report_help method' );

    $mock->clear;

    $mock->run( '_test', '--version' );
    $mock->called_ok( 'report_version',
        'run with --version switch calls report_version method' );

    my $mocked_command = Test::MockObject->new;
    $mocked_command->set_always( 'run', 'magic' );

    my $mocked_command_module = Test::MockObject::Extends->new('UNIVERSAL');
    $mocked_command_module->set_always( 'new', $mocked_command );

    $mock->set_always( 'get_command_module', $mocked_command_module );

    my $return = $mock->run( 'command-name', 'run parameter' );

    $mocked_command_module->called_ok( 'new',
        'run call constructed new command object' );
    $mocked_command->called_ok( 'run', '... then called run method on it' );
    $mocked_command->called_args_pos_is(
        0, 2,
        'run parameter',
        '... passing correct parameters'
    );
    is $return, 'magic', '... and returns value from object directly';
}

if (HAS_DONE_TESTING) {
    done_testing;
}

