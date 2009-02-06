package WGDev::Command::Dist;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.1.0';

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

sub process {
    require File::Temp;
    require File::Copy;
    require Cwd;
    my $self = shift;
    my $wgd = $self->wgd;

    my ($version, $status) = $wgd->version->module;
    my $build_root = File::Temp->newdir;
    my $build_webgui = File::Spec->catdir($build_root, 'WebGUI');
    my $build_docs = File::Spec->catdir($build_root, 'api');
    my $cwd = Cwd::cwd();

    mkdir $build_webgui;
    $self->export_files($build_webgui);
    unless (fork()) {
        chdir $build_root;
        exec 'tar', 'czf', File::Spec->catfile($cwd, "webgui-$version-$status.tar.gz"), 'WebGUI';
    }
    wait;

    mkdir $build_docs;
    $self->generate_docs($build_docs);
    unless (fork()) {
        chdir $build_root;
        exec 'tar', 'czf', File::Spec->catfile($cwd, "webgui-api-$version-$status.tar.gz"), 'api';
    }
    wait;
}

sub export_files {
    my $self = shift;
    my $from = $self->wgd->root;
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
    require File::Temp;
    my $self = shift;
    my $from = $self->wgd->root;
    my $to_root = shift;
    my $code_dir = File::Spec->catdir($from, 'lib', 'WebGUI');
    my $temp_dir = File::Temp->newdir;
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
            $doc_file = File::Spec->rel2abs(File::Spec->abs2rel($doc_file, $code_dir), $to_root);
            my $directory = File::Spec->catpath( (File::Spec->splitpath($doc_file))[0,1] );
            File::Path::mkpath($directory);
            Pod::Html::pod2html(
                '--quiet',
                '--noindex',
                '--infile=' . $code_file,
                '--outfile=' . $doc_file,
                '--cachedir=' . $temp_dir,
            );
        },
    }, $code_dir);
    return $to_root;
}

1;

__END__

=head1 NAME

WGDev::Command::Dist - Create a distribution file for WebGUI

=head1 SYNOPSIS

wgd dist [-c] [-d]

=head1 DESCRIPTION

Generates distribution files containing WebGUI or the WebGUI API.

=head1 OPTIONS

By default, generates both a code and API documentation package.

=over 8

=item B<-c --code>

Generates a code distrobution

=item B<-d --documentation>

Generates an API documentation distribution

=back

=head1 AUTHOR

Graham Knop <graham@plainblack.com>

=head1 LICENSE

Copyright (c) Graham Knop.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

