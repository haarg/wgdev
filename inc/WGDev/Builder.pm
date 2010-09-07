package WGDev::Builder;
use strict;
use warnings;

use 5.008008;
our $VERSION = '0.0.2';

use Module::Build ();
BEGIN { our @ISA = qw(Module::Build) }

use File::Spec ();
use File::Temp ();
use File::Path ();
use File::Find ();
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

    $self->regenerate_fatlib;

    my $dist_script = 'wgd';
    unlink $dist_script;
    open my $out_fh, '>', $dist_script;

    print { $out_fh } <<'END_HEADER';
#!/usr/bin/env perl

END_HEADER

    open my $fh, '-|', 'fatpack', 'file'
        or die "Can't run fatpack: $!";
    while ( my $line = <$fh> ) {
        # hack so we can extract the list later
        $line =~ s/\bmy %fatpacked\b/our %fatpacked/;
        print { $out_fh } $line;
    }
    close $fh;
    open $fh, '<', 'bin/wgd';
    while ( my $line = <$fh> ) {
        print { $out_fh } $line;
    }
    close $fh;
    close $out_fh;
    chmod oct(755), $dist_script;
    File::Path::remove_tree('fatlib');
}

my %wg_deps = map { $_ => 1 } qw(
    Apache2::Request
    Archive::Tar
    Archive::Zip
    Class::InsideOut
    Color::Calc
    Compress::Zlib
    Config::JSON
    DBD::mysql
    DBI
    Data::Structure::Util
    DateTime
    DateTime::Format::Mail
    DateTime::Format::Strptime
    Digest::MD5
    Finance::Quote
    HTML::Highlight
    HTML::Parser
    HTML::TagCloud
    HTML::TagFilter
    HTML::Template
    HTML::Template::Expr
    HTTP::Headers
    HTTP::Request
    IO::Zlib
    Image::Magick
    JSON
    LWP
    List::Util
    Locale::US
    Log::Log4perl
    MIME::Tools
    Net::LDAP
    Net::POP3
    Net::SMTP
    Net::Subnets
    POE
    POE::Component::Client::HTTP
    POE::Component::IKC::Server
    POSIX
    Parse::PlainConfig
    Pod::Coverage
    SOAP::Lite
    Test::Deep
    Test::MockObject
    Test::More
    Text::Aspell
    Text::Balanced
    Text::CSV_XS
    Tie::CPHash
    Tie::IxHash
    Time::HiRes
    URI::Escape
    Weather::Com::Finder
    XML::RSSLite
    XML::Simple
);

sub regenerate_fatlib {
    my $self = shift;

    File::Path::remove_tree('fatlib');
    my $temp_script = File::Temp->new(UNLINK => 0);
    my %deps = %{ $self->requires };
    for my $module ( keys %deps ) {
        if ($module eq 'perl') {
            print {$temp_script} "use $deps{$module};\n";
        }
        elsif ( $wg_deps{$module} ) {
        }
        else {
            print {$temp_script} "use $module ();\n";
        }
    }
    $temp_script->flush;
    my (undef, $trace_file) = do { local $^W; File::Temp::tempfile(OPEN => 0) };
    open my $oldout, '>&', \*STDOUT;
    open my $olderr, '>&', \*STDERR;
    open STDOUT, '>', File::Spec->devnull;
    open STDERR, '>', File::Spec->devnull;
    system 'fatpack', 'trace', '--to=' . $trace_file, $temp_script;
    open STDOUT, '>&=', $oldout;
    open STDERR, '>&=', $olderr;
    open my $trace_fh, '<', $trace_file;
    my @modules = <$trace_fh>;
    close $trace_fh;
    unlink $trace_file;
    chomp @modules;
    @modules = grep { /\.pm$/ } @modules;
    open my $pack_fh, '-|', 'fatpack', 'packlists-for', @modules;
    my @packlists = <$pack_fh>;
    chomp @packlists;
    system 'fatpack', 'tree', @packlists;
    require Config;
    File::Path::remove_tree(File::Spec->catdir('fatlib', $Config::Config{archname}));
    File::Find::find({
        no_chdir => 1,
        wanted => sub {
            if ( -f ) {
                if ( /\.pm$/ ) {
                    open my $fh, '+<', $_;
                    seek $fh, -1, 2;
                    read $fh, my $last_char, 1;
                    if ($last_char !~ /\n/) {
                        print {$fh} "\n";
                    }
                    close $fh;
                }
                else {
                    unlink $_;
                }
            }
        },
    }, 'fatlib');
}

1;

