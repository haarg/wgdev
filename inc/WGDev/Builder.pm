package WGDev::Builder;
use strict;
use warnings;

use 5.008008;
our $VERSION = '0.0.2';

use Module::Build ();
BEGIN { our @ISA = qw(Module::Build) }

use File::Spec ();
use File::Temp ();
##no critic (ProhibitMagicNumbers Capitalization)

sub new {
    my $class   = shift;
    my %options = @_;
    $options{test_types}{author} = ['.at'];
    my $self = $class->SUPER::new(%options);
    return $self;
}

sub ACTION_testauthor {
    return shift->generic_test( type => 'author' );
}

# we're overriding this to use Pod::Coverage::TrustPod instead of the
# default
sub ACTION_testpodcoverage {
    my $self = shift;

    $self->depends_on('docs');

    eval {
        require Test::Pod::Coverage;
        Test::Pod::Coverage->VERSION(1.0);
        require Pod::Coverage::TrustPod;
        Pod::Coverage::TrustPod->VERSION(0.092400);
    }
        or die q{The 'testpodcoverage' action requires },
        q{Test::Pod::Coverage version 1.00 and Pod::Coverage::TrustPod version 0.092400};

    local @INC = @INC;
    my $p = $self->{properties};
    unshift @INC, File::Spec->catdir( $p->{base_dir}, $self->blib, 'lib' );

    Test::Pod::Coverage::all_pod_coverage_ok(
        { coverage_class => 'Pod::Coverage::TrustPod' } );
    return;
}

# Run perltidy over all the Perl code
# Borrowed from Test::Harness
sub ACTION_tidy {
    my $self = shift;

    my %found_files = map { %{$_} } $self->find_pm_files,
        $self->_find_file_by_type( 'pm', 't' ),
        $self->_find_file_by_type( 'pm', 'inc' ),
        $self->_find_file_by_type( 't',  't' ),
        $self->_find_file_by_type( 'at', 't' ),
        { 'Build.PL' => 'Build.PL' };

    my @files = sort keys %found_files;

    require Perl::Tidy;

    print "Running perltidy on @{[ scalar @files ]} files...\n";
    for my $file (@files) {
        print "  $file\n";
        if (
            eval {
                Perl::Tidy::perltidy( argv => [ '-b', '-nst', $file ], );
                1;
            } )
        {
            unlink "$file.bak";
        }
    }
}

sub ACTION_distexec {
    my $self = shift;

    my $dist_script = 'wgd-' . $self->dist_version;
    unlink $dist_script;
    open my $out_fh, '>', $dist_script;

    print { $out_fh } <<'END_HEADER';
#!/usr/bin/env perl

END_HEADER

    mkdir 'fatlib';
    open my $fh, '-|', 'fatpack', 'file'
        or die "Can't run fatpack: $!";
    while ( my $line = <$fh> ) {
        print { $out_fh } $line;
    }
    close $fh;
    rmdir 'fatlib';
    open $fh, '<', 'bin/wgd';
    while ( my $line = <$fh> ) {
        print { $out_fh } $line;
    }
    close $fh;
    close $out_fh;
    chmod oct(755), $dist_script;
}

1;

