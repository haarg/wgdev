package WGDev::Command::Test;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.0.1';

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

use File::Spec ();

sub option_parse_config { return qw(gnu_getopt pass_through) }

sub option_config {
    return qw(
        all|A
        slow|S
        reset:s
    );
}

sub process {
    my $self = shift;
    my $wgd  = $self->wgd;
    $wgd->set_environment;
    require Cwd;
    require App::Prove;
    if ( defined $self->option('reset') ) {
        my $reset_options = $self->option('reset');
        if ( $reset_options eq q{} ) {
            $reset_options = '--quiet --delcache --import --upgrade';
        }
        require WGDev::Command::Reset;
        my $reset = WGDev::Command::Reset->new($wgd);
        $reset->parse_params_string($reset_options);
        $reset->process;
    }
    local $ENV{CODE_COP}    = $ENV{CODE_COP};
    local $ENV{TEST_SYNTAX} = $ENV{TEST_SYNTAX};
    local $ENV{TEST_POD}    = $ENV{TEST_POD};
    if ( $self->option('slow') ) {
        ##no critic (RequireLocalizedPunctuationVars)
        $ENV{CODE_COP}    = 1;
        $ENV{TEST_SYNTAX} = 1;
        $ENV{TEST_POD}    = 1;
    }
    my $prove = App::Prove->new;
    my @args  = $self->arguments;
    my $orig_dir;
    if ( $self->option('all') ) {
        $orig_dir = Cwd::cwd();
        chdir $wgd->root;
        unshift @args, '-r', 't';
    }
    $prove->process_args(@args);
    my $result = $prove->run;
    if ($orig_dir) {
        chdir $orig_dir;
    }
    return $result;
}

1;

__END__

=head1 NAME

WGDev::Command::Test - Run WebGUI tests

=head1 SYNOPSIS

    wgd test [-AS] [<prove options>]

=head1 DESCRIPTION

Runs WebGUI tests, setting the needed environment variables beforehand.
Includes quick options for running all tests, and including slow tests.

=head1 OPTIONS

Unrecognized options will be passed through to prove.

=over 8

=item C<-A> C<--all>

Run all tests recursively.  Otherwise, tests will need to be specified.

=item C<-S> C<--slow>

Includes slow tests by defining CODE_COP, TEST_SYNTAX, and TEST_POD.

=item C<--reset=>

Perform a site reset before running the tests.  The value specified is used
as the command line parameters for the L<C<reset> command|WGDev::Command::Reset>.
With no value, will use the options C<--delcache --import --upgrade> to do a
fast site reset.

=back

=head1 AUTHOR

Graham Knop <graham@plainblack.com>

=head1 LICENSE

Copyright (c) Graham Knop.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

