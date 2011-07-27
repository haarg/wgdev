package Dist::Zilla::Plugin::WGDev;
use Moose;
use namespace::autoclean;
with 'Dist::Zilla::Role::BeforeArchive';

use Path::Class::Dir ();
use File::Temp ();
use File::Copy qw(copy);
use File::Copy::Recursive qw(dircopy);
use Cwd qw(cwd);
use Capture::Tiny qw(capture);
use Config ();
use App::FatPacker ();
use Module::CoreList;

sub before_archive {
    my $self = shift;
    my $build_root = $self->zilla->ensure_built;

    $self->generate_fatlib;
    $self->generate_fatscript;
    $build_root->subdir('fatlib')->rmtree;
}

sub generate_fatscript {
    my $self = shift;
    my $pack_root = $self->zilla->ensure_built;

    my $cwd = cwd;
    chdir $pack_root;

    $self->log('building fatpacked script wgd');
    my $fat = capture {
        App::FatPacker->new->run_script(['file']);
    };

    chdir $cwd;

    my @libs =
        grep { /\.pm$/ }
        grep { m{^lib/} }
        map { $_->name }
        @{ $self->zilla->files };
    for (@libs) {
        s{^lib/}{};
    }
    my $packed = join "\n", q{}, @libs, q{};

    my $script = $self->zilla->ensure_built->file('bin', 'wgd')->slurp;
    $script =~ s/^our\s+\$PACKED\b.*?;/our \$PACKED = 1;/m;
    $script =~ s/^our\s+\@PACKED\b.*?;/our \@PACKED = qw($packed);/m;

    my $dist_script = $self->zilla->root->file('wgd');
    $dist_script->remove;
    my $out_fh = $dist_script->openw;
    print { $out_fh } <<"END_SCRIPT";
#!/usr/bin/env perl

$fat
$script
END_SCRIPT

    close $out_fh;
    chmod oct(755), $dist_script;
}

sub generate_fatlib {
    my $self = shift;
    my $pack_root = $self->zilla->ensure_built;

    $pack_root->subdir('fatlib')->rmtree;

    $self->log('tracing dependencies for fatpack');
    my $temp_script = File::Temp->new;
    for my $module ( $self->calculate_prereqs ) {
        print {$temp_script} "use $module ();\n";
    }
    $temp_script->flush;
    my (undef, $trace) = capture {
        App::FatPacker->new->run_script(['trace', '--to-stderr', $temp_script]);
    };
    my @modules;
    for my $module ( split /[\r\n]+/, $trace ) {
        ( my $package = $module ) =~ s{/}{::}g;
        $package =~ s/\.pm$//
            or next;
        if ( ! $Module::CoreList::version{5.008008}{$package} ) {
            push @modules, $module;
        }
    }

    my $packlists = capture {
        App::FatPacker->new->run_script(['packlists-for', @modules]);
    };
    my @packlists = split /[\r\n]+/, $packlists;

    $self->log('bundling dependencies for fatpack');
    my $cwd = cwd;
    chdir $pack_root;
    App::FatPacker->new->run_script(['tree', @packlists]);
    chdir $cwd;

    $pack_root->subdir('fatlib', $Config::Config{archname})->rmtree;
    $pack_root->subdir('fatlib')->recurse( callback => sub {
        my $item = shift;
        if (! $item->is_dir && $item !~ /\.pm$/ ) {
            $item->remove;
        }
    });
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

sub calculate_prereqs {
    my $self = shift;
    my @deps = $self->zilla->prereqs->requirements_for('runtime', 'requires')->required_modules;
    @deps = grep {
        $_ ne 'perl' and
        !$wg_deps{$_} and
        !$Module::CoreList::version{5.008008}{$_}
    } @deps;
    return @deps;
}

__PACKAGE__->meta->make_immutable;

package inc::Dist::Zilla::Plugin::WGDev;
use Moose;
extends 'Dist::Zilla::Plugin::WGDev';
__PACKAGE__->meta->make_immutable;

1;
