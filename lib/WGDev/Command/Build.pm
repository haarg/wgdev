package WGDev::Command::Build;
use strict;
use warnings;

our $VERSION = '0.1.0';

use WGDev::Command::Base::Verbosity;
our @ISA = qw(WGDev::Command::Base::Verbosity);

sub option_config {
    (shift->SUPER::option_config, qw(
        sql|s
        uploads|u
    ));
}

sub parse_params {
    my $self = shift;
    my $result = $self->SUPER::parse_params(@_);
    if (!defined $self->option('sql') && !defined $self->option('uploads')) {
        $self->option('sql', 1);
        $self->option('uploads', 1);
    }
    return $result;
}

sub process {
    my $self = shift;
    my $wgd = $self->wgd;
    require File::Copy;
    unless ($wgd->config_file) {
        die "Can't find WebGUI root!\n";
    }

    # Autoflush
    local $| = 1;

    require version;

    $self->report("Finding current version number... ");
    my $version = $wgd->version->database($wgd->db->connect);
    $self->report("$version. Done.\n");

    if ($self->option('sql')) {
        $self->report("Creating database dump... ");
        my $db_file = File::Spec->catfile($wgd->root, 'docs', 'create.sql');
        open my $out, '>', $db_file;

        open my $in, '-|', 'mysqldump', $wgd->db->command_line('--compact', '--no-data');
        File::Copy::copy($in, $out);
        close $in;

        my @skip_data_tables = qw(
            userSession     userSessionScratch
            webguiVersion   userLoginLog
            assetHistory    cache
        );
        open $in, '-|', 'mysqldump', $wgd->db->command_line('--compact', '--no-create-info',
            map { "--ignore-table=" . $wgd->db->database . '.' . $_ } @skip_data_tables
            );
        File::Copy::copy($in, $out);
        close $in;

        print {$out} "INSERT INTO webguiVersion (webguiVersion,versionType,dateApplied) VALUES ('$version','Initial Install',UNIX_TIMESTAMP());\n";

        close $out;
        $self->report("Done.\n");
    }

    # Clear and recreate uploads
    if ($self->option('uploads')) {
        require File::Find;
        require File::Path;

        $self->report("Loading uploads from site... ");
        my $wg_uploads = File::Spec->catdir($wgd->root, 'www', 'uploads');
        File::Path::mkpath($wg_uploads);
        my $site_uploads = $wgd->config->get('uploadsPath');
        File::Find::find({
            no_chdir    => 1,
            wanted      => sub {
                my $wg_path = $File::Find::name;
                my (undef, undef, $filename) = File::Spec->splitpath($wg_path);
                if ($filename eq '.svn' || $filename eq 'temp') {
                    $File::Find::prune = 1;
                    return;
                }
                my $rel_path = File::Spec->abs2rel($wg_path, $wg_uploads);
                my $site_path = File::Spec->rel2abs($rel_path, $site_uploads);
                return
                    if -e $site_path;
                if (-d $site_path) {
                    File::Path::rmtree($wg_path);
                }
                else {
                    unlink $wg_path;
                }
            },
        }, $wg_uploads);
        File::Find::find({
            no_chdir    => 1,
            wanted      => sub {
                my $site_path = $File::Find::name;
                my (undef, undef, $filename) = File::Spec->splitpath($site_path);
                if ($filename eq '.svn' || $filename eq 'temp') {
                    $File::Find::prune = 1;
                    return;
                }
                return
                    if -d $site_path;
                my $rel_path = File::Spec->abs2rel($site_path, $site_uploads);
                my $wg_path = File::Spec->rel2abs($rel_path, $wg_uploads);
                return
                    if -e $wg_path && (stat(_))[7] == (stat($site_path))[7];
                my $wg_dir = File::Spec->catpath((File::Spec->splitpath($wg_path))[0,1]);
                File::Path::mkpath($wg_dir);
                File::Copy::copy($site_path, $wg_path);
            },
        }, $site_uploads);
        $self->report("Done\n");
    }
}

1;

__END__

=head1 NAME

WGDev::Command::Build - Builds an SQL script and uploads for site creation

=head1 SYNOPSIS

wgd build [-s] [-u]

=head1 DESCRIPTION

Uses the current database and uploads to build a new create.sql and update
the local uploads directory.  With no options, builds both sql and uploads.

=head1 OPTIONS

=over 8

=item B<-s --sql>

make create.sql based on current database contents

=item B<-u --uploads>

make uploads based on current site's uploads

=back

=head1 AUTHOR

Graham Knop <graham@plainblack.com>

=head1 LICENSE

Copyright (c) Graham Knop.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

