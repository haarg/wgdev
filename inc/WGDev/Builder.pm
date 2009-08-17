package WGDev::Builder;
use strict;
use warnings;

use 5.008008;
our $VERSION = '0.0.2';

use Module::Build ();
BEGIN { our @ISA = qw(Module::Build) }

use File::Spec     ();
use File::Temp     ();
##no critic (ProhibitMagicNumbers Capitalization)

sub new {
    my $class   = shift;
    my %options = @_;
    $options{test_types}{author}   = ['.at'];
    my $self = $class->SUPER::new(%options);
    return $self;
}

sub ACTION_testauthor {
    return shift->generic_test( type => 'author' );
}

# we're overriding this to use Pod::Coverage::CountParent instead of the
# default
sub ACTION_testpodcoverage {
    my $self = shift;

    $self->depends_on('docs');

    eval {
        require Test::Pod::Coverage;
        Test::Pod::Coverage->VERSION(1.0);
    }
        or die q{The 'testpodcoverage' action requires },
        q{Test::Pod::Coverage version 1.00};

    local @INC = @INC;
    my $p = $self->{properties};
    unshift @INC, File::Spec->catdir( $p->{base_dir}, $self->blib, 'lib' );

    Test::Pod::Coverage::all_pod_coverage_ok(
        { coverage_class => 'Pod::Coverage::CountParents' } );
    return;
}

# Run perltidy over all the Perl code
# Borrowed from Test::Harness
sub ACTION_tidy {
    my $self = shift;

    my %found_files = map {%{$_}} $self->find_pm_files,
        $self->_find_file_by_type( 'pm', 't' ),
        $self->_find_file_by_type( 'pm', 'inc' ),
        $self->_find_file_by_type( 't',  't' ),
        $self->_find_file_by_type( 'at', 't' ),
        $self->_find_file_by_type( 'PL', q{.} );

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
    $self->depends_on('build');

    my $temp;
    {
        local $^W = 0;
        (undef, $temp) = File::Temp::tempfile(OPEN => 0);
    }
    system 'tar', 'czf', $temp, '-C', $self->blib, 'lib', 'script';
    my $archive_size = (stat $temp)[7];
    open my $archive, '<', $temp;

    my $dist_script = 'wgd-' . $self->dist_version;
    open my $fh, '>', $dist_script;
    syswrite $fh, sprintf <<'END_SCRIPT', $archive_size;
#!/bin/sh

if [ $0 -nt "$TMPDIR/WGDev/.marker" ];
then
    [[ -e "$TMPDIR/WGDev" ]] && rm -rf "$TMPDIR/WGDev"
    mkdir "$TMPDIR/WGDev"
    mkdir "$TMPDIR/WGDev/perl"
    tail -c %s $0 | tar xz -C "$TMPDIR/WGDev/perl"
    touch "$TMPDIR/WGDev/.marker"
fi

export PERL5LIB=$TMPDIR/WGDev/perl/lib:$PERL5LIB
$TMPDIR/WGDev/perl/script/wgd $@
exit $?

################## END #################

END_SCRIPT
    open my $tar_fh, '<', $temp;
    while (1) {
        my $buffer;
        my $read = sysread $tar_fh, $buffer, 1000;
        last
            if ! $read;
        syswrite $fh, $buffer;
    }
    close $tar_fh;
    close $fh;
    $self->make_executable($dist_script);
}

1;

