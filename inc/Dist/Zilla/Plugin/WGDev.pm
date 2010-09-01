package Dist::Zilla::Plugin::WGDev;
use Moose;
use namespace::autoclean;
with 'Dist::Zilla::Role::BeforeArchive';
with 'Dist::Zilla::Role::FileMunger';
use Path::Class::Dir ();
use Path::Class::File ();
use File::Temp ();
use File::Copy::Recursive qw(dircopy);
use File::Spec::Functions qw(catdir);
use Cwd qw(cwd);

sub munge_file {
    my $self = shift;
    my $file = shift;
    if ( $file->content !~ /\n$/ ) {
        $file->content($file->content . "\n");
    }
}

sub before_archive {
    my $self = shift;
    my $build_root = $self->zilla->ensure_built;

    my $pack_temp = File::Temp->newdir;
    my $pack_root = Path::Class::Dir->new($pack_temp->dirname);

    dircopy(
        $build_root->subdir('lib')->stringify,
        $pack_root->subdir('lib')->stringify,
    );

    $self->regenerate_fatlib($pack_root);

    my $dist_script = $self->zilla->root->file('wgd');
    $dist_script->remove;
    my $out_fh = $dist_script->openw;

    print { $out_fh } <<'END_HEADER';
#!/usr/bin/env perl

END_HEADER

    my $cwd = cwd;
    chdir $pack_root;

    open my $fh, '-|', 'fatpack', 'file'
        or die "Can't run fatpack: $!";
    while ( my $line = <$fh> ) {
        # hack so we can extract the list later
        $line =~ s/\bmy %fatpacked\b/our %fatpacked/;
        print { $out_fh } $line;
    }
    close $fh;
    chdir $cwd;
    $fh = $build_root->file('bin', 'wgd')->openr;
    while ( my $line = <$fh> ) {
        print { $out_fh } $line;
    }
    close $fh;
    close $out_fh;
    chmod oct(755), $dist_script;
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
    my $pack_root = shift;

    $pack_root->subdir('fatlib')->rmtree;
    my $temp_script = File::Temp->new(UNLINK => 0);
    my @deps = $self->zilla->prereqs->requirements_for('runtime', 'requires')->required_modules;
    for my $module ( @deps ) {
        if ($module eq 'perl') {
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
    my $cwd = cwd;
    chdir $pack_root;
    system 'fatpack', 'tree', @packlists;
    chdir $cwd;
    require Config;
    $pack_root->subdir('fatlib', $Config::Config{archname})->rmtree;
    $pack_root->subdir('fatlib')->recurse( callback => sub {
        my $item = shift;
        if (! $item->is_dir) {
            if ( $item =~ /\.pm$/ ) {
                my $fh = $item->open('+<');
                seek $fh, -1, 2;
                read $fh, my $last_char, 1;
                if ($last_char !~ /\n/) {
                    print {$fh} "\n";
                }
                close $fh;
            }
            else {
                $item->remove;
            }
        }
    });
}

__PACKAGE__->meta->make_immutable;
package inc::Dist::Zilla::Plugin::WGDev;
use Moose;
extends 'Dist::Zilla::Plugin::WGDev';
__PACKAGE__->meta->make_immutable;

1;

