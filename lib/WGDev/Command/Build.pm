package WGDev::Command::Build;
# ABSTRACT: Builds an SQL script and uploads for site creation
use strict;
use warnings;
use 5.008008;

use parent qw(WGDev::Command::Base::Verbosity);

use File::Spec ();
use WGDev::X   ();
use WGDev::File;

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
    my $wg8 = $wgd->version->module =~ /^8[.]/msx;
    my $db_file = $wg8 ? do {
        require WebGUI::Paths;
        WebGUI::Paths->defaultCreateSQL;
    } : File::Spec->catfile( $wgd->root, 'docs', 'create.sql' );
    open my $out, q{>}, $db_file
        or WGDev::X::IO::Write->throw( path => $db_file );

    $self->write_db_header($out);
    $self->write_db_structure($out);
    $self->write_db_data($out);
    $self->write_db_footer($out);

    close $out
        or WGDev::X::IO::Write->throw( path => $db_file );
    $self->report("Done.\n");
    return 1;
}

sub write_db_header {
    my $self = shift;
    my $out  = shift;
    print {$out} <<'END_SQL';
SET @OLD_CHARACTER_SET_CLIENT       = @@CHARACTER_SET_CLIENT;
SET @OLD_CHARACTER_SET_RESULTS      = @@CHARACTER_SET_RESULTS;
SET @OLD_CHARACTER_SET_CONNECTION   = @@CHARACTER_SET_CONNECTION;
SET @OLD_COLLATION_CONNECTION       = @@COLLATION_CONNECTION;
SET @OLD_TIME_ZONE                  = @@TIME_ZONE;
SET @OLD_UNIQUE_CHECKS              = @@UNIQUE_CHECKS;
SET @OLD_FOREIGN_KEY_CHECKS         = @@FOREIGN_KEY_CHECKS;
SET @OLD_SQL_MODE                   = @@SQL_MODE;
SET @OLD_SQL_NOTES                  = @@SQL_NOTES;

SET CHARACTER_SET_CLIENT            = 'utf8';
SET CHARACTER_SET_RESULTS           = 'utf8';
SET CHARACTER_SET_CONNECTION        = 'utf8';
SET TIME_ZONE                       = '+00:00';
SET UNIQUE_CHECKS                   = 0;
SET FOREIGN_KEY_CHECKS              = 0;
SET SQL_MODE                        = 'NO_AUTO_VALUE_ON_ZERO';
SET SQL_NOTES                       = 0;
END_SQL
    return;
}

sub write_db_footer {
    my $self = shift;
    my $out  = shift;
    print {$out} <<'END_SQL';
SET CHARACTER_SET_CLIENT        = @OLD_CHARACTER_SET_CLIENT;
SET CHARACTER_SET_RESULTS       = @OLD_CHARACTER_SET_RESULTS;
SET CHARACTER_SET_CONNECTION    = @OLD_CHARACTER_SET_CONNECTION;
SET COLLATION_CONNECTION        = @OLD_COLLATION_CONNECTION;
SET TIME_ZONE                   = @OLD_TIME_ZONE;
SET UNIQUE_CHECKS               = @OLD_UNIQUE_CHECKS;
SET FOREIGN_KEY_CHECKS          = @OLD_FOREIGN_KEY_CHECKS;
SET SQL_MODE                    = @OLD_SQL_MODE;
SET SQL_NOTES                   = @OLD_SQL_NOTES;
END_SQL
    return;
}

sub write_db_structure {
    my $self = shift;
    my $out  = shift;
    my $wgd  = $self->wgd;

    open my $in, q{-|}, 'mysqldump',
        $wgd->db->command_line( '--compact', '--no-data',
        '--compatible=mysql40' )
        or WGDev::X::System->throw('Unable to run mysqldump');
    my $statement;
    while ( my $line = <$in> ) {
        next
            if $line =~ /\bSET[^=]+=\s*[@][@]character_set_client;/msxi
                || $line =~ /\bSET\s+character_set_client\b/msxi;
        if ( !$statement && $line =~ /\A(CREATE[ ]TABLE)/msx ) {
            $statement = $1;
        }
        if ( $statement && $line =~ /;\n?\z/msx ) {
            if ( $statement eq 'CREATE TABLE' ) {
                $line =~ s/TYPE=(InnoDB|MyISAM)/ENGINE=$1/;
                $line =~ s/;(\n?)\z/ CHARSET=utf8;$1/msx;
            }
            undef $statement;
        }
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

    $self->report('Loading uploads from site... ');

    my $wg_uploads = File::Spec->catdir( $wgd->root, 'www', 'uploads' );
    my $site_uploads    = $wgd->config->get('uploadsPath');
    WGDev::File->sync_dirs($site_uploads, $wg_uploads);

    $self->report("Done\n");
    return 1;
}

1;

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

=method C<create_db_script>

Builds the F<create.sql> database script.  This is done as a dump of the current
database structure and data, excluding the data from some tables.

=method C<update_local_uploads>

Updates the working directory's uploads from the current site.  Files will be
deleted or created so the two match.

=cut

