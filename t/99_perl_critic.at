use strict;
use warnings;

use Test::More;
use File::Spec;

if ( !eval { require Test::Perl::Critic } ) {
    plan skip_all => 'Test::Perl::Critic required to criticise code';
}

Test::Perl::Critic->import( -profile => '.perlcriticrc' );
Test::Perl::Critic::all_critic_ok();

