package WGDev::Command::Dist;
use strict;
use warnings;

use File::Spec;

sub new {
    my $class = shift;
    my $wgd = shift;
    my $self = bless {
        wgd     => $wgd,
    }, $class;
    #GetOptionsFromArray(\@_,
    #);
    return $self;
}

sub run {
    require File::Temp;
    require File::Copy;
    require Cwd;
    my $self = ref $_[0] ? shift : shift->new(@_);

    my $wgd = $self->{wgd};
    my ($version, $status) = $wgd->version->module;
    my $build_root = File::Temp->newdir;
    my $build_webgui = File::Spec->catdir($build_root, 'WebGUI');
    my $build_docs = File::Spec->catdir($build_root, 'api');
    my $cwd = Cwd::cwd;

    mkdir $build_webgui;
    $self->export_files($build_webgui);
    unless (fork()) {
        chdir $build_root;
        exec 'tar', 'czf', File::Spec->catfile($cwd, "webgui-$version-$status.tar.gz"), 'WebGUI';
    }
    wait;

    mkdir $build_docs;
    $self->generate_docs($build_webgui, $build_docs);
    unless (fork()) {
        chdir $build_root;
        exec 'tar', 'czf', File::Spec->catfile($cwd, "webgui-api-$version-$status.tar.gz"), 'api';
    }
    wait;
}

sub export_files {
    my $self = shift;
    my $from = $self->{wgd}->root;
    my $to_root = shift;

    if (-e File::Spec->catdir($from, '.git')) {
        system 'git', '--git-dir=' . File::Spec->catdir($from, '.git'), 'checkout-index', '-a', '--prefix=' . $to_root . '/';
    }
    elsif (-e File::Spec->catdir($from, '.svn')) {
        system 'svn', 'export', $from, $to_root;
    }
    else {
        system 'cp', '-r', $from, $to_root;
    }

    for my $file ( ['docs', 'previousVersion.sql'], ['etc', '*.conf'],
                   ['sbin', 'preload.custom'], ['sbin', 'preload.exclude'] ) {
        my $file_path = File::Spec->catfile($to_root, @$file);
        unlink $_
            for glob $file_path;
    }
    return $to_root;
}

sub generate_docs {
    require File::Find;
    require File::Path;
    require Pod::Html;
    my $self = shift;
    my $build_webgui = shift;
    my $build_docs = shift;
    my $code_dir = File::Spec->catdir($build_webgui, 'lib', 'WebGUI');
    File::Find::find({
        no_chdir    => 1,
        wanted      => sub {
            no warnings 'once';
            my $code_file = $File::Find::name;
            return
                if -d $code_file;
            my $doc_file = $code_file;
            return
                if $doc_file =~ /\bOperation\.pm$/;
            return
                unless $doc_file =~ s/\.pm$/.html/;
            $doc_file = File::Spec->rel2abs(File::Spec->abs2rel($doc_file, $code_dir), $build_docs);
            my $directory = File::Spec->catpath( (File::Spec->splitpath($doc_file))[0,1] );
            File::Path::mkpath($directory);
            Pod::Html::pod2html(
                '--quiet',
                '--noindex',
                '--infile=' . $code_file,
                '--outfile=' . $doc_file,
                '--cachedir=' . $build_webgui,
            );
        },
    }, $code_dir);
    return 1;
}

1;

