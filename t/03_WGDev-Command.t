use strict;
use warnings;

# set this right now so we can override it later
BEGIN {
    *CORE::GLOBAL::exit = sub (;$) {
        goto &CORE::exit;
    };
}

use Test::More 'no_plan';
use Test::NoWarnings;
use Test::Exception;
use Test::Warn;

use File::Spec::Functions qw(catdir catfile catpath rel2abs splitpath);
use Cwd qw(realpath cwd);
use File::Temp ();
use File::Copy qw(copy);
use Config ();

use constant TEST_DIR => catpath( ( splitpath(__FILE__) )[ 0, 1 ], '' );

use lib catdir( TEST_DIR, 'lib' );
local $ENV{PATH} = join $Config::Config{path_sep}, catdir( TEST_DIR, 'bin' ),
    $ENV{PATH};

use WGDev                          ();
use WGDev::Command                 ();
use WGDev::Command::_test          ();
use WGDev::Command::_test_baseless ();
use WGDev_tester_command           ();
use WGDev::Help                    ();

BEGIN { $INC{'WGDev/Command/_tester.pm'} = $INC{'WGDev_tester_command.pm'} }

my $test_data = catdir( TEST_DIR, 'testdata' );

sub capture_output (&) {
    my $sub    = shift;
    my $output = q{};
    open my $out_fh, '>', \$output;
    my $orig_out = select($out_fh);

    $sub->();
    select $orig_out;
    close $out_fh;
    return $output;
}

sub capture_exit (&) {
    my $sub = shift;
    my $exit_code;

    EXIT: {
        no warnings 'redefine';
        local *CORE::GLOBAL::exit = sub (;$) {
            $exit_code = @_ ? 0 + shift : 0;
            no warnings 'exiting';
            last EXIT;
        };
        $sub->();
        return;
    }
    return $exit_code;
}

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
    = WGDev::Command->usage( verbosity => 2, include_cmd_list => 1 );
is $output, $general_usage, 'report_help prints usage message';

warning_like {
    $output = capture_output {
        ok +WGDev::Command->report_help(
            'command name', 'WGDev::Command::_test_baseless'
            ),
            'report_help returns true value for command with no usage info';
    };
}
qr{^\QNo documentation for command name command.\E$},
    'report_help warns about command with no usage info';
is $output, q{}, 'report_help prints nothing if command has no usage info';

$output = capture_output {
    ok +WGDev::Command->report_help(
        'command name', 'WGDev::Command::_test'
        ),
        'report_help returns true value for command with usage info';
};
is $output, WGDev::Command::_test->usage,
    'report_help prints usage info for provided command';

is +WGDev::Command::get_command_module('_test'), 'WGDev::Command::_test',
    'get_command_module finds normal command modules';

is +WGDev::Command::get_command_module('_test-subclass'),
    'WGDev::Command::_test::Subclass',
    'get_command_module finds subclass command modules';

is +WGDev::Command::get_command_module('base'), undef,
    'get_command_module returns undef for existing command modules that aren\'t runnable';

is +WGDev::Command::get_command_module('_nonexistant'), undef,
    'get_command_module returns undef for nonexisting command modules';

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

my $usage_verbosity_2 = WGDev::Help::package_usage( 'WGDev::Command', 2 );
is +WGDev::Command->usage(2), $usage_verbosity_2,
    'usage with one parameter treats it as verbosity';

is +WGDev::Command->usage( verbosity => 2 ), $usage_verbosity_2,
    'usage with hash uses verbosity option';

is +WGDev::Command->usage( message => 'prefixed message' ),
    'prefixed message' . $usage_base,
    'usage with message option prefixes it to output';

my @commands = WGDev::Command->command_list;
is +WGDev::Command->usage( include_cmd_list => 1 ),
    $usage_base . "SUBCOMMANDS\n    " . join( "\n    ", @commands ) . "\n\n",
    'usage with include_cmd_list option includes command list';

is + ( grep { $_ eq 'util' } @commands ), 1,
    'command_list includes unloaded commands';

is + ( grep { $_ eq '_test' } @commands ), 1,
    'command_list includes loaded commands';

is + ( grep { $_ eq '_tester' } @commands ), 1,
    'command_list includes commands with mismatched filename and package';

is + ( grep { $_ eq 'tester-executable' } @commands ), 1,
    'command_list includes standalone executables in path';

is + ( grep { $_ eq 'tester-non-executable' } @commands ), 0,
    'command_list doesn\'t include standalone non-executables in path';

is + ( grep { $_ eq 'base' } @commands ), 0,
    'command_list doesn\'t include command modules that are not runnable';

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

my $root_abs   = rel2abs($root);
my $lib_abs    = rel2abs($lib);
my $config_abs = rel2abs($config);

my $command_config = {
    webgui_root   => undef,
    webgui_config => undef,
};
{
    no warnings 'redefine';
    *WGDev::write_wgd_config = sub {
        return 1;
    };
    *WGDev::read_wgd_config = sub {
        my $self = shift;
        return $self->{wgd_config} = { command => $command_config, };
    };
}

my $cwd = cwd;

chdir $emptydir;
my $wgd = WGDev->new;
throws_ok { WGDev::Command->guess_webgui_paths($wgd) }
qr{^\QUnable to find WebGUI root directory!},
    'guess_webgui_paths throws correct error for invalid dir';

chdir $root;
$wgd = WGDev->new;
lives_and { is +WGDev::Command->guess_webgui_paths($wgd), $wgd }
'guess_webgui_paths returns passed in WGDev instance when finding path based on current';

is realpath( $wgd->root ), realpath($root_abs), 'root path set correctly';

is realpath( $wgd->config_file ), realpath($config_abs),
    'config file path set correctly';

$wgd = WGDev->new;
throws_ok { WGDev::Command->guess_webgui_paths( $wgd, $emptydir ) }
qr{^\QInvalid WebGUI path: },
    'guess_webgui_paths throws correct error for invalid dir when in valid dir';

chdir $sbin;
$wgd = WGDev->new;
lives_and {
    is realpath( WGDev::Command->guess_webgui_paths($wgd)->root ),
        realpath($root_abs);
}
'guess_webgui_paths finds root searching updward from current dir';

chdir $cwd;
$wgd = WGDev->new;
lives_and {
    is realpath(
        WGDev::Command->guess_webgui_paths( $wgd, undef, $config_abs )
            ->root ), realpath($root_abs);
}
'guess_webgui_paths finds root when given config file';

$wgd = WGDev->new;
throws_ok {
    WGDev::Command->guess_webgui_paths( $wgd, undef,
        catfile( $test_data, 'www.example.com.conf' ) );
}
qr{^\QUnable to find WebGUI root directory!},
    'guess_webgui_paths throws correct error when given a config file without a valid root';

chdir $root;
$ENV{WEBGUI_ROOT} = $emptydir;
$wgd = WGDev->new;
throws_ok { WGDev::Command->guess_webgui_paths($wgd) }
qr{^\QInvalid WebGUI path: },
    'guess_webgui_paths throws correct error for invalid dir set via ENV when in valid dir';

chdir $cwd;

$ENV{WEBGUI_ROOT} = $root_abs;
$wgd = WGDev->new;
lives_and {
    is realpath( WGDev::Command->guess_webgui_paths($wgd)->root ),
        realpath($root_abs);
}
'guess_webgui_paths finds root given by environment';
$ENV{WEBGUI_ROOT} = undef;

$command_config->{webgui_root} = $root_abs;
$wgd = WGDev->new;
lives_and {
    is realpath( WGDev::Command->guess_webgui_paths($wgd)->root ),
        realpath($root_abs);
}
'guess_webgui_paths finds root given by wgdevcfg file';

$command_config->{webgui_root} = undef;
copy catfile( $test_data, 'www.example.com.conf' ),
    catfile( $etc, 'www.example2.com.conf' );
throws_ok { WGDev::Command->guess_webgui_paths( $wgd, $root ) }
qr{^\QUnable to find WebGUI config file!},
    'guess_webgui_paths throws correct error for root with two config files';

$ENV{WEBGUI_ROOT} = $root_abs;
$wgd = WGDev->new;
my $truncated_config = catfile( $etc, 'www.example.com' );
lives_and {
    is realpath(
        WGDev::Command->guess_webgui_paths( $wgd, undef, $truncated_config )
            ->config_file ), realpath($config);
}
'guess_webgui_paths intelligently adds .conf to config file';

my $nonexistant_config = catfile( $etc, 'duff' );
throws_ok {
    WGDev::Command->guess_webgui_paths( $wgd, undef, $nonexistant_config );
}
qr{^\QInvalid WebGUI config file: $nonexistant_config\E$}m,
    'guess_webgui_paths throws with the config file requested, not with an unspecified .conf appended to the end';
$ENV{WEBGUI_ROOT} = undef;

chdir $root;
$wgd = WGDev->new;
lives_and {
    is realpath(
        WGDev::Command->guess_webgui_paths( $wgd, undef, 'www.example.com' )
            ->config_file ),
        realpath($config);
}
'guess_webgui_paths with guessed root intelligently adds .conf to config file';

throws_ok {
    WGDev::Command->guess_webgui_paths( $wgd, undef, 'duff' );
}
qr{^\QInvalid WebGUI config file: duff\E$}m,
    'guess_webgui_paths with guessed root throws with the config file requested, not with an unspecified .conf appended to the end';
chdir $cwd;

my $exit;
warning_like {
    $exit = capture_exit {
        WGDev::Command->run();
    };
}
qr/^\QNo command specified!/, 'run with no params warns correctly';

is $exit, 1, '... and exits with an error code of 1';

