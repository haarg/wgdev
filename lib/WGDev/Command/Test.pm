package WGDev::Command::Test;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.1.0';

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

use File::Spec ();

sub config_parse_options { return qw(gnu_getopt pass_through) }

sub config_options {
    return qw(
        all|A
        slow
        live|L
        debug
        reset:s
        cover|C:s
        coverOptions:s
    );
}

sub process {
    my $self = shift;
    require Cwd;
    require App::Prove;

    my $wgd = $self->wgd;
    $wgd->set_environment;

    if ( defined $self->option('reset') ) {
        my $reset_options = $self->option('reset');
        if ( $reset_options eq q{} ) {
            $reset_options = '--quiet --backup --delcache --import --upgrade';
        }
        require WGDev::Command::Reset;
        my $reset = WGDev::Command::Reset->new($wgd);
        $reset->parse_params_string($reset_options);
        $reset->process;
    }

    ##no critic (RequireLocalizedPunctuationVars)
    local $ENV{CODE_COP} = 1
        if $self->option('slow');
    local $ENV{TEST_SYNTAX} = 1
        if $self->option('slow');
    local $ENV{TEST_POD} = 1
        if $self->option('slow');

    local $ENV{WEBGUI_LIVE} = 1
        if $self->option('live');

    local $ENV{WEBGUI_TEST_DEBUG} = 1
        if $self->option('debug');

    local $ENV{HARNESS_PERL_SWITCHES} = $ENV{HARNESS_PERL_SWITCHES};
    my $cover_dir;
    if ( defined $self->option('cover') ) {
        $cover_dir = $self->option('cover') || 'cover_db';
        if ( -e $cover_dir ) {
            system 'cover', '-silent', '-delete', $cover_dir;
        }
        my $cover_options = $self->option('coverOptions')
            || '-select,WebGUI,+ignore,^t';
        if ( $ENV{HARNESS_PERL_SWITCHES} ) {
            $ENV{HARNESS_PERL_SWITCHES} .= q{ };
        }
        else {
            $ENV{HARNESS_PERL_SWITCHES} = q{};
        }
        $ENV{HARNESS_PERL_SWITCHES} .= '-MDevel::Cover=' . join q{,},
            -silent => 1,
            $cover_options, -db => $cover_dir;
    }

    my $prove = App::Prove->new;
    my @args  = $self->arguments;
    @args = ( '-r', grep { $_ ne '-r' } @args );
    my $orig_dir;
    if ( $self->option('all') ) {
        $orig_dir = Cwd::cwd();
        chdir $wgd->root;
        unshift @args, 't';
    }
    $prove->process_args(@args);
    my $result = $prove->run;
    if ($orig_dir) {
        chdir $orig_dir;
    }
    if ( defined $cover_dir ) {
        system 'cover', '-silent', $cover_dir;
    }
    return $result;
}

1;

__END__

=head1 NAME

WGDev::Command::Test - Run WebGUI tests

=head1 SYNOPSIS

    wgd test [-ASCL] [--debug] [<prove options>]

=head1 DESCRIPTION

Runs WebGUI tests, setting the needed environment variables beforehand.
Includes quick options for running all tests, and including slow tests.

=head1 OPTIONS

Unrecognized options will be passed through to prove.

=over 8

=item C<-A> C<--all>

Run all tests recursively.  Otherwise, tests will need to be specified.

=item C<--slow>

Includes slow tests by defining CODE_COP, TEST_SYNTAX, and TEST_POD.

=item C<-L> C<--live>

Includes live tests by defining WEBGUI_LIVE.

=item C<--debug>

After a test, output the number of assets, version tags, users, groups, sessions
and session scratch variables, to determine when tests leak objects that can interfere
with downstream tests.

This option is really only useful when passing the --verbose switch through to prove.

=item C<--reset=>

Perform a site reset before running the tests.  The value specified is used
as the command line parameters for the L<C<reset> command|WGDev::Command::Reset>.
With no value, will use the options C<--delcache --backup --import --upgrade> to do a
fast site reset.

=item C<-C> C<--cover=>

Run coverage using Devel::Cover. The value specified is used as the directory to 
put the coverage data and defaults to C<cover_db>.

=item C<--coverOptions=>

Options to pass to L<Devel::Cover>. Defaults to C<-select,WebGUI,+ignore,^t>.

=back

=head1 AUTHOR

Graham Knop <haarg@haarg.org>

=head1 LICENSE

Copyright (c) 2009-2010, Graham Knop

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl 5.10.0. For more details, see the
full text of the licenses in the directory LICENSES.

=cut

