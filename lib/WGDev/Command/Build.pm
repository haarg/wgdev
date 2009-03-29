package WGDev::Command::Build;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.1.0';

use WGDev::Command::Base::Verbosity;
BEGIN { our @ISA = qw(WGDev::Command::Base::Verbosity) }

use File::Spec ();
use Carp qw(croak);

sub option_config {
    return (
        shift->SUPER::option_config, qw(
            sql|s
            uploads|u
            ) );
}

sub parse_params {
    my $self   = shift;
    my $result = $self->SUPER::parse_params(@_);
    if ( !defined $self->option('sql') && !defined $self->option('uploads') )
    {
        $self->option( 'sql',     1 );
        $self->option( 'uploads', 1 );
    }
    return $result;
}

sub process {
    my $self = shift;
    my $wgd  = $self->wgd;
    require File::Copy;
    if ( !$wgd->config_file ) {
        die "Can't find WebGUI root!\n";
    }

    if ( $self->option('sql') ) {
        $self->create_db_script;
    }

    if ( $self->option('uploads') ) {
        $self->update_local_uploads;
    }
    return 1;
}

sub create_db_script {
    my $self = shift;
    my $wgd  = $self->wgd;
    require File::Copy;

    $self->report('Finding current version number... ');
    my $version = $wgd->version->database( $wgd->db->connect );
    $self->report("$version. Done.\n");

    $self->report('Creating database dump... ');
    my $db_file = File::Spec->catfile( $wgd->root, 'docs', 'create.sql' );
    ##no critic (RequireBriefOpen)
    open my $out, q{>}, $db_file
        or croak "Unable to output database script: $!";
    open my $in, q{-|}, 'mysqldump',
        $wgd->db->command_line( '--compact', '--no-data' )
        or croak "Unable to run mysqldump: $!";
    File::Copy::copy( $in, $out );
    close $in or croak "Unable to close filehandle: $!";

    my @skip_data_tables = qw(
        userSession     userSessionScratch
        webguiVersion   userLoginLog
        assetHistory    cache
    );
    open $in, q{-|}, 'mysqldump', $wgd->db->command_line(
        '--compact',
        '--no-create-info',
        map { '--ignore-table=' . $wgd->db->database . q{.} . $_ }
            @skip_data_tables
    ) or croak "Unable to run mysqldunp command: $!";
    File::Copy::copy( $in, $out );
    close $in or croak "Unable to close filehandle: $!";

    print {$out} 'INSERT INTO webguiVersion '
        . '(webguiVersion,versionType,dateApplied) '
        . "VALUES ('$version','Initial Install',UNIX_TIMESTAMP());\n";

    close $out or croak "Unable to close filehandle: $!";
    $self->report("Done.\n");
    return 1;
}

sub update_local_uploads {
    my $self = shift;
    my $wgd  = $self->wgd;
    require File::Find;
    require File::Path;
    require File::Copy;

    $self->report('Loading uploads from site... ');
    my $wg_uploads = File::Spec->catdir( $wgd->root, 'www', 'uploads' );
    File::Path::mkpath($wg_uploads);
    my $site_uploads    = $wgd->config->get('uploadsPath');
    my $remove_files_cb = sub {
        no warnings 'once';
        my $wg_path = $File::Find::name;
        my ( undef, undef, $filename ) = File::Spec->splitpath($wg_path);
        if ( $filename eq '.svn' || $filename eq 'temp' ) {
            $File::Find::prune = 1;
            return;
        }
        my $rel_path = File::Spec->abs2rel( $wg_path, $wg_uploads );
        my $site_path = File::Spec->rel2abs( $rel_path, $site_uploads );
        return
            if -e $site_path;
        if ( -d $site_path ) {
            File::Path::rmtree($wg_path);
        }
        else {
            unlink $wg_path;
        }
    };
    File::Find::find( { no_chdir => 1, wanted => $remove_files_cb },
        $wg_uploads );
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
        my $rel_path = File::Spec->abs2rel( $site_path, $site_uploads );
        my $wg_path = File::Spec->rel2abs( $rel_path, $wg_uploads );

        # stat[7] is file size
        ##no critic (ProhibitMagicNumbers)
        return
            if -e $wg_path && ( stat _ )[7] == ( stat $site_path )[7];
        my $wg_dir = File::Spec->catpath(
            ( File::Spec->splitpath($wg_path) )[ 0, 1 ] );
        File::Path::mkpath($wg_dir);
        File::Copy::copy( $site_path, $wg_path );
    };
    File::Find::find( { no_chdir => 1, wanted => $copy_files_cb },
        $site_uploads );
    $self->report("Done\n");
    return 1;
}

1;

__END__

=head1 NAME

WGDev::Command::Build - Builds an SQL script and uploads for site creation

=head1 SYNOPSIS

    wgd build [-s] [-u]

=head1 DESCRIPTION

Uses the current database and uploads to build a new F<create.sql> and update
the local uploads directory.  With no options, builds both the database
script and the uploads directory.

=head1 OPTIONS

=over 8

=item C<-s> C<--sql>

Make F<create.sql> based on current database contents

=item C<-u> C<--uploads>

Make uploads based on current site's uploads

=back

=head1 AUTHOR

Graham Knop <graham@plainblack.com>

=head1 LICENSE

Copyright (c) Graham Knop.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

