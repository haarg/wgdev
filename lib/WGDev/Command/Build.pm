package WGDev::Command::Build;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.2.0';

use WGDev::Command::Base::Verbosity;
BEGIN { our @ISA = qw(WGDev::Command::Base::Verbosity) }

use File::Spec ();
use WGDev::X   ();

sub config_options {
    return (
        shift->SUPER::config_options, qw(
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

    my $version = $wgd->version->database( $wgd->db->connect );
    $self->report("WebGUI version: $version\n");

    $self->report('Creating database dump... ');
    my $db_file = File::Spec->catfile( $wgd->root, 'docs', 'create.sql' );
    open my $out, q{>}, $db_file
        or WGDev::X::IO::Write->throw( path => 'docs/create.sql' );
    print {$out} <<'END_SQL';
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
END_SQL

    $self->write_db_structure($out);
    $self->write_db_data( $out, $version );

    print {$out} <<'END_SQL';
SET character_set_client = @saved_cs_client;
END_SQL

    close $out
        or WGDev::X::IO::Write->throw( path => 'docs/create.sql' );
    $self->report("Done.\n");
    return 1;
}

sub write_db_structure {
    my $self = shift;
    my $out  = shift;
    my $wgd  = $self->wgd;

    open my $in, q{-|}, 'mysqldump',
        $wgd->db->command_line( '--compact', '--no-data',
        '--compatible=mysql40' )
        or WGDev::X::System->throw('Unable to run mysqldump');
    while ( my $line = <$in> ) {
        next
            if $line =~ /\bSET[^=]+=\s*[@][@]character_set_client;/msx
                || $line =~ /\bSET\s+character_set_client\b/msx;
        print {$out} $line;
    }
    close $in
        or WGDev::X::System->throw('Unable to run mysqldump');
    return 1;
}

sub write_db_data {
    my $self = shift;
    my $out  = shift;
    my $wgd  = $self->wgd;

    my $dbh     = $wgd->db->connect;
    my $version = $wgd->version->database($dbh);

    my %skip_data_tables = map { $_ => 1 } qw(
        userSession     userSessionScratch
        webguiVersion   userLoginLog
        assetHistory    cache
    );

    my @tables;

    my $sth = $dbh->table_info( undef, undef, q{%}, undef );
    while ( ( undef, undef, my $table ) = $sth->fetchrow_array ) {
        next
            if $skip_data_tables{$table};
        my ($count)
            = $dbh->selectrow_array(
            'SELECT COUNT(*) FROM ' . $dbh->quote_identifier($table) );
        next
            if !$count;
        push @tables, $table;
    }

    open my $in, q{-|}, 'mysqldump',
        $wgd->db->command_line( '--no-create-info', '--compact',
        '--disable-keys', sort @tables, )
        or WGDev::X::System->throw('Unable to run mysqldump');
    while ( my $line = <$in> ) {
        $line =~ s{ /[*] !\d+ \s+ ([^*]+?) \s* [*]/; }{$1;}msx;
        print {$out} $line;
    }
    close $in
        or WGDev::X::System->throw('Unable to run mysqldump');

    print {$out} 'INSERT INTO webguiVersion '
        . '(webguiVersion,versionType,dateApplied) '
        . "VALUES ('$version','Initial Install',UNIX_TIMESTAMP());\n";

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

=head1 METHODS

=head2 C<create_db_script>

Builds the F<create.sql> database script.  This is done as a dump of the current
database structure and data, excluding the data from some tables.

=head2 C<update_local_uploads>

Updates the working directory's uploads from the current site.  Files will be
deleted or created so the two match.

=head1 AUTHOR

Graham Knop <haarg@haarg.org>

=head1 LICENSE

Copyright (c) 2009, Graham Knop

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl 5.10.0. For more details, see the
full text of the licenses in the directory LICENSES.

=cut

