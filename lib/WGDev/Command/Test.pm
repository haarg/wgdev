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
        slow|S
        live|L
        reset:s
        cover|C:s
        html=s
        coverOptions:s
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
            $reset_options = '--quiet --backup --delcache --import --upgrade';
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
    local $ENV{WEBGUI_LIVE} = $ENV{WEBGUI_LIVE};
    if ( $self->option('live') ) {
        ##no critic (RequireLocalizedPunctuationVars)
        $ENV{WEBGUI_LIVE} = 1;
    }
    local $ENV{HARNESS_PERL_SWITCHES} = $ENV{HARNESS_PERL_SWITCHES};
    my $cover_dir;
    if ( defined $self->option('cover') ) {
        $cover_dir = $self->option('cover') || 'cover_db';
        if ( -e $cover_dir ) {
            system 'cover', '-silent', '-delete', $cover_dir;
        }
        my $cover_options = $self->option('coverOptions')
            || '-select,WebGUI,+ignore,^t';
        ##no critic (RequireLocalizedPunctuationVars)
        $ENV{HARNESS_PERL_SWITCHES}
            = '-MDevel::Cover=-silent,1'
            . ",$cover_options," . '-db,'
            . $cover_dir;
    }
    my $prove = App::Prove->new;
    my @args  = $self->arguments;
    my $orig_dir;
    my $tar_file;
    my $html_file;
    if ( $self->option('html') ) {
        $html_file = File::Spec->rel2abs($self->option('html'));
        $tar_file = File::Temp->new(TEMPLATE => 'webgui-test-XXXXXX', SUFFIX => '.tar', DIR => File::Spec->tmpdir);
        unshift @args, "--archive=$tar_file";
    }
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
    if ( $html_file ) {
        $self->generate_html_from_archive($html_file, $tar_file);
    }
    if ( defined $cover_dir ) {
        system 'cover', '-silent', $cover_dir;
    }
    return $result;
}

sub generate_html_from_archive {
    my ($self, $html_file, $tar_file) = @_;

    require File::Temp;
    require File::Spec;
    require Cwd;
    require Archive::Tar;
    require TAP::Parser;
    require TAP::Parser::Aggregator;
    require TAP::Formatter::HTML;
    require Benchmark;
    require YAML::Tiny;

    my $dir = File::Temp->newdir;

    my $cwd = Cwd::cwd();
    chdir $dir;
    Archive::Tar->extract_archive("$tar_file");

    my $test_data = YAML::Tiny->read('meta.yml')->[0];

    my $aggregator = TAP::Parser::Aggregator->new;
    my $formatter = TAP::Formatter::HTML->new({
        verbosity => -3,
        output_file => $html_file,
    });

    # Formatter gets only names.
    $formatter->prepare( map { $_->{description} } @{$test_data->{file_attributes}} );

    for my $test_details ( @{ $test_data->{file_attributes} } ) {
        my $test_name = $test_details->{description};
        open my $fh, '<', $test_name;
        my $tap = do { local $/; <$fh> };
        close $fh;
        my $parser = TAP::Parser->new({tap => $tap});

        my $session = $formatter->open_test($test_name, $parser);

        while ( defined( my $result = $parser->next ) ) {
            $session->result($result);
        }

        $parser->start_time($test_details->{start_time});
        $parser->end_time($test_details->{end_time});

        $session->close_test;

        $aggregator->add($test_name, $parser);
    }

    # this is ugly but will do for now
    $aggregator->{start_time}
        = bless [$test_data->{start_time}, (0) x 5], 'Benchmark';
    $aggregator->{end_time}
        = bless [$test_data->{stop_time}, (0) x 5], 'Benchmark';

    $formatter->summary($aggregator);

    chdir $cwd;

    return 1;
}

1;

__END__

=head1 NAME

WGDev::Command::Test - Run WebGUI tests

=head1 SYNOPSIS

    wgd test [-ASCL] [<prove options>]

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

=item C<-L> C<--live>

Includes live tests by defining WEBGUI_LIVE.

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

Copyright (c) 2009, Graham Knop

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl 5.10.0. For more details, see the
full text of the licenses in the directory LICENSES.

=cut

