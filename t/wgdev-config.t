use strict;
use warnings;

use Test::More;
use Test::MockObject;
use Test::MockObject::Extends;
use Test::Exception;
use File::Temp;

use File::Spec::Functions qw(catdir catfile catpath rel2abs splitpath);
use Cwd qw(realpath cwd);

use constant TEST_DIR => catpath( ( splitpath(__FILE__) )[ 0, 1 ], '' );
use lib catdir( TEST_DIR, 'lib' );

use constant HAS_DONE_TESTING => Test::More->can('done_testing') ? 1 : undef;

# use done_testing if possible
if ( !HAS_DONE_TESTING ) {
    plan 'no_plan';
}

use WGDev::Config;

my $config_file = File::Temp::tmpnam();
my $config = WGDev::Config->new($config_file);

ok 1;


if (HAS_DONE_TESTING) {
    done_testing;
}

