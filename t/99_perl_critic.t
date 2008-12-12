use strict;
use warnings;

use Test::More;
use File::Spec;

if ( ! $ENV{TEST_AUTHOR} ) {
    plan skip_all => 'Author test.  Set $ENV{TEST_AUTHOR} to a true value to run.';
}

if ( ! eval { require Test::Perl::Critic } ) {
    plan skip_all => 'Test::Perl::Critic required to criticise code';
}

Test::Perl::Critic->import( -profile => '.perlcriticrc' );
Test::Perl::Critic::all_critic_ok();

