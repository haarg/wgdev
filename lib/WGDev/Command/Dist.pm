package WGDev::Command::Dist;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.1.0';

use WGDev::Command::Base::Verbosity;
BEGIN { our @ISA = qw(WGDev::Command::Base::Verbosity) }

use File::Spec ();
use File::Find ();
use File::Path ();
use File::Copy ();

sub config_options {
    return (
        shift->SUPER::config_options, qw(
            buildDir|b=s
            langDir|l=s
            lang|g=s@
            ) );
}

sub needs_config {
    return;
}

sub process {
    my $self = shift;
    my $wgd  = $self->wgd;
    require File::Temp;
    require File::Copy;
    require Cwd;

    $self->set_option_default('langDir', '/data/domains/translation.webgui.org/public/translations');
    $self->set_option_default('lang',    [qw/Spanish Dutch German/]);
    my ( $version, $status ) = $wgd->version->module;
    my $build_dir = $self->option('buildDir');
    my $build_root;
    if ($build_dir) {
        $build_root = $build_dir;
        mkdir $build_root;
    }
    if ( $build_root && !-e $build_root ) {
        $build_root = File::Temp->newdir;
    }
    $self->report("Created build directory: " . $build_root . "\n");
    my $build_webgui = File::Spec->catdir( $build_root, 'WebGUI' );
    my $build_docs   = File::Spec->catdir( $build_root, 'api' );
    my $cwd          = Cwd::cwd();

    mkdir $build_webgui;
    $self->report("Exporting files for WebGUI core\n");
    $self->export_files($build_webgui);
    foreach my $language ( @{ $self->option('lang') } ) {
        $self->report("Adding language pack for " . $language . "\n");
        $self->install_language($build_webgui, $language);
    }
    my $inst_dir = $build_dir || $cwd;
    if ( !fork ) {
        chdir $build_root;
        exec 'tar', 'czf',
            File::Spec->catfile( $inst_dir,
            "webgui-$version-$status.tar.gz" ),
            'WebGUI';
    }
    wait;

    mkdir $build_docs;
    $self->report("Building API docs\n");
    $self->generate_docs($build_docs);
    if ( !fork ) {
        chdir $build_root;
        exec 'tar', 'czf',
            File::Spec->catfile(
            $inst_dir, "webgui-api-$version-$status.tar.gz"
            ),
            'api';
    }
    wait;
    return 1;
}

sub export_files {
    my $self    = shift;
    my $to_root = shift;
    my $from    = $self->wgd->root;

    if ( -e File::Spec->catdir( $from, '.git' ) ) {
        system 'git', '--git-dir=' . File::Spec->catdir( $from, '.git' ),
            'checkout-index', '-a', '--prefix=' . $to_root . q{/};
    }
    elsif ( -e File::Spec->catdir( $from, '.svn' ) ) {
        system 'svn', 'export', $from, $to_root;
    }
    else {
        $self->copy_deeply($from, $to_root);
    }

    for my $file (
        [ 'docs', 'previousVersion.sql' ],
        [ 'etc',  '*.conf' ],
        [ 'sbin', 'preload.custom' ],
        [ 'sbin', 'preload.exclude' ] )
    {
        my $file_path = File::Spec->catfile( $to_root, @{$file} );
        for my $file ( glob $file_path ) {
            unlink $file;
        }
    }
    return $to_root;
}

sub generate_docs {
    my $self    = shift;
    my $to_root = shift;
    my $from    = $self->wgd->root;
    require File::Find;
    require File::Path;
    require Pod::Html;
    require File::Temp;
    my $code_dir = File::Spec->catdir( $from, 'lib', 'WebGUI' );
    my $temp_dir = File::Temp->newdir;
    File::Find::find( {
            no_chdir => 1,
            wanted   => sub {
                no warnings 'once';
                my $code_file = $File::Find::name;
                return
                    if -d $code_file;
                my $doc_file = $code_file;
                return
                    if $doc_file =~ /\b\QOperation.pm\E$/msx;
                return
                    if $doc_file !~ s/\Q.pm\E$/.html/msx;
                $doc_file = File::Spec->rel2abs(
                    File::Spec->abs2rel( $doc_file, $code_dir ), $to_root );
                my $directory = File::Spec->catpath(
                    ( File::Spec->splitpath($doc_file) )[ 0, 1 ] );
                File::Path::mkpath($directory);
                Pod::Html::pod2html(
                    '--quiet',
                    '--noindex',
                    '--infile=' . $code_file,
                    '--outfile=' . $doc_file,
                    '--cachedir=' . $temp_dir,
                );
            },
        },
        $code_dir
    );
    return $to_root;
}

sub install_language {
    my $self     = shift;
    my $to_root  = shift;
    my $language = shift;
    my $lang_root = $self->option('langDir');
    my $lang_dir  = File::Spec->catdir( $lang_root, $language );
    return unless -e $lang_dir;
    my $extras_dir = File::Spec->catdir( $lang_dir, 'extras' );
    if (-e $extras_dir) {
        $self->copy_deeply($extras_dir, File::Spec->catdir( $to_root, qw/www extras/ ));
    }
    File::Copy::copy(
        File::Spec->catfile( $lang_dir, $language . '.pm' ),
        File::Spec->catfile( $to_root, qw/lib WebGUI i18n/, $language . '.pm' )
    );
    $self->copy_deeply( File::Spec->catdir( $lang_dir, $language ), File::Spec->catdir( $to_root, qw/lib WebGUI i18n/, $language ) );
}

sub copy_deeply {
    my $self     = shift;
    my $from     = shift;
    my $to       = shift;
    my $copy_files_cb = sub {
        no warnings 'once';
        my $site_path = $File::Find::name;
        my ( undef, undef, $filename ) = File::Spec->splitpath($site_path);
        if ( $filename eq '.svn' || $filename eq 'temp' ) {
            $File::Find::prune = 1;
            return;
        }
        return
            if -d $site_path;
        my $rel_path = File::Spec->abs2rel( $site_path, $from );
        my $wg_path  = File::Spec->rel2abs( $rel_path,  $to );

        # stat[7] is file size
        ##no critic (ProhibitMagicNumbers)
        return
            if -e $wg_path && ( stat _ )[7] == ( stat $site_path )[7];
        my $wg_dir = File::Spec->catpath(
            ( File::Spec->splitpath($wg_path) )[ 0, 1 ] );
        File::Path::mkpath($wg_dir);
        File::Copy::copy( $site_path, $wg_path );
    };
    File::Find::find( { no_chdir => 1, wanted => $copy_files_cb }, $from );
}

1;

__END__

=head1 NAME

WGDev::Command::Dist - Create a distribution file for WebGUI

=head1 SYNOPSIS

    wgd dist [-c] [-d] [-b /data/builds] [ -l /data/domains/i18n.webgui.org/public/translations ] [--lang=Dutch]

=head1 DESCRIPTION

Generates distribution files containing WebGUI or the WebGUI API.

=head1 OPTIONS

By default, generates both a code and API documentation package.

=over 8

=item C<-c> C<--code>

Generates a code distribution

=item C<-d> C<--documentation>

Generates an API documentation distribution

=item C<-b> C<--buildDir>

Install the directories and tarballs in a different location.  If no build directory
is specified, it will create a temp file.

=item C<-l> C<--langDir>

Source directory for languages.  Defaults to the location of the master WebGUI translation server.

=item C<-lang>

A language to install into the build directory.  Multiple languages can be chosen by using the
option several times.  Defaults to --lang=Dutch --lang=German --lang=Spanish.

=back

=head1 METHODS

=head2 C<export_files ( $directory )>

Exports the WebGUI root directory, excluding common site specific files, to
the specified directory.

=head2 C<generate_docs ( $directory )>

Generate API documentation for WebGUI using Pod::Html in the specified
directory.

=head1 AUTHOR

Graham Knop <haarg@haarg.org>

=head1 LICENSE

Copyright (c) 2009, Graham Knop

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl 5.10.0. For more details, see the
full text of the licenses in the directory LICENSES.

=cut

