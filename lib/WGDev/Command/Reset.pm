package WGDev::Command::Reset;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.1.1';

use WGDev::Command::Base::Verbosity;
BEGIN { our @ISA = qw(WGDev::Command::Base::Verbosity) }

use File::Spec ();
use Carp qw(croak);

sub option_config {
    return (
        shift->SUPER::option_config, qw(
            fast|f

            backup!
            delcache!
            import!

            test|t
            dev|d
            build|b

            uploads!
            upgrade!

            debug!
            starter!
            clear!
            config!
            purge!
            cleantags!
            index!
            runwf!
            ) );
}

sub parse_params {
    my ( $self, @args ) = @_;
    my $result = $self->SUPER::parse_params(@args);

    if ( $self->option('fast') ) {
        $self->option_default( backup    => 1 );
        $self->option_default( uploads   => 0 );
        $self->option_default( backup    => 0 );
        $self->option_default( delcache  => 0 );
        $self->option_default( purge     => 0 );
        $self->option_default( cleantags => 0 );
        $self->option_default( index     => 0 );
        $self->option_default( runwf     => 0 );
    }
    if ( $self->option('dev') ) {
        $self->option_default( backup  => 1 );
        $self->option_default( import  => 1 );
        $self->option_default( uploads => 1 );
        $self->option_default( upgrade => 1 );
        $self->option_default( starter => 0 );
        $self->option_default( debug   => 1 );
        $self->option_default( clear   => 1 );
    }
    if ( $self->option('build') ) {
        $self->verbosity( $self->verbosity + 1 );
        $self->option_default( backup    => 1 );
        $self->option_default( uploads   => 1 );
        $self->option_default( import    => 1 );
        $self->option_default( starter   => 1 );
        $self->option_default( debug     => 0 );
        $self->option_default( upgrade   => 1 );
        $self->option_default( purge     => 1 );
        $self->option_default( cleantags => 1 );
        $self->option_default( index     => 1 );
        $self->option_default( runwf     => 1 );
    }
    $self->option_default( 'delcache', 1 );
    return $result;
}

sub process {
    my $self = shift;
    my $wgd  = $self->wgd;

    if ( $self->option('backup') ) {
        $self->backup;
    }

    # Clear cache
    if ( $self->option('delcache') ) {
        $self->clear_cache;
    }

    # Clear and recreate uploads
    if ( $self->option('uploads') ) {
        $self->reset_uploads;
    }

    if ( $self->option('import') ) {
        $self->import_db_script;
    }

    # Run the upgrade in a fork
    if ( $self->option('upgrade') ) {
        $self->upgrade;
    }

    if ( $self->option('config') ) {
        $self->reset_config;
    }

    if ( defined $self->option('debug') || defined $self->option('starter') )
    {
        $self->set_settings;
    }

    if ( $self->option('clear') ) {
        $self->clear_default_content;
    }

    if ( $self->option('purge') ) {
        $self->purge_old_revisions;
    }

    if ( $self->option('cleantags') ) {
        $self->clean_version_tags;
    }

    if ( $self->option('runwf') ) {
        $self->run_all_workflows;
    }

    if ( $self->option('index') ) {
        $self->rebuild_lineage;
        $self->rebuild_index;
    }

    return 1;
}

sub backup {
    my $self = shift;
    $self->report('Backing up current database... ');
    $self->wgd->db->dump(
        File::Spec->catfile( File::Spec->tmpdir, 'WebGUI-reset-backup.sql' )
    );
    $self->report("Done.\n");
    return 1;
}

sub clear_cache {
    my $self = shift;
    my $wgd  = $self->wgd;
    require File::Path;
    $self->report('Clearing cache... ');
    if ( $wgd->config->get('cacheType') eq 'WebGUI::Cache::FileCache' ) {
        my $cache_dir = $wgd->config->get('fileCacheRoot')
            || '/tmp/WebGUICache';
        File::Path::rmtree($cache_dir);
    }
    elsif ( $wgd->config->get('cacheType') eq 'WebGUI::Cache::Database' ) {

   # Don't clear the DB cache if we are importing, as that will wipe it anyway
        if ( !$self->option('import') ) {
            my $dsn = $wgd->db->connect;
            $dsn->do('DELETE FROM cache');
        }
    }
    else {

        # Can't clear a cache we don't know anything about
    }
    $self->report("Done.\n");
    return 1;
}

# Clear and recreate uploads
sub reset_uploads {
    my $self = shift;
    my $wgd  = $self->wgd;
    require File::Copy;
    require File::Find;
    require File::Path;
    $self->report('Recreating uploads... ');

    my $wg_uploads = File::Spec->catdir( $wgd->root, 'www', 'uploads' );
    my $site_uploads = $wgd->config->get('uploadsPath');
    File::Path::rmtree($site_uploads);
    File::Find::find( {
            no_chdir => 1,
            wanted   => sub {
                no warnings 'once';    ##no critic (ProhibitNoWarnings)
                my $wg_path = $File::Find::name;
                my $site_path
                    = File::Spec->rel2abs(
                    File::Spec->abs2rel( $wg_path, $wg_uploads ),
                    $site_uploads );
                if ( -d $wg_path ) {
                    my $dir = ( File::Spec->splitdir($wg_path) )[-1];
                    if ( $dir =~ /^[.]/msx ) {
                        $File::Find::prune = 1;
                        return;
                    }
                    File::Path::mkpath($site_path);
                }
                else {
                    File::Copy::copy( $wg_path, $site_path );
                }
            },
        },
        $wg_uploads
    );
    $self->report("Done\n");
    return 1;
}

sub import_db_script {
    my $self = shift;
    my $wgd  = $self->wgd;
    $self->report('Clearing old database information... ');
    $wgd->db->clear;
    $self->report("Done.\n");

    $self->report('Importing clean database dump... ');

    # If we aren't upgrading, we're using the current DB version
    my $db_file
        = $self->option('upgrade') ? 'previousVersion.sql' : 'create.sql';
    $wgd->db->load( File::Spec->catfile( $wgd->root, 'docs', $db_file ) );
    $self->report("Done\n");
    return 1;
}

# Run the upgrade in a fork
sub upgrade {
    my $self = shift;
    my $wgd  = $self->wgd;
    $self->report('Running upgrade script... ');

    # TODO: only upgrade single site
    my $pid = fork;
    if ( !$pid ) {

        # child process, don't need to worry about restoring anything
        chdir File::Spec->catdir( $wgd->root, 'sbin' );
        local @ARGV = qw(--doit --override --skipBackup);
        if ( $self->verbosity < 2 ) {
            push @ARGV, '--quiet';
        }
        do 'upgrade.pl';
        croak $@ if $@;
        exit;
    }
    waitpid $pid, 0;

    # error status of subprocess
    if ($?) {    ##no critic (ProhibitPunctuationVars)
        die "Upgrade failed!\n";
    }
    $self->report("Done\n");
    return 1;
}

sub reset_config {
    my $self = shift;
    my $wgd  = $self->wgd;
    require File::Copy;

    $self->report('Resetting config file... ');
    my $reset_config = $wgd->my_config('config');
    my %set_config   = %{ $reset_config->{override} };
    for my $key (
        @{ $reset_config->{copy} }, qw(
        dsn dbuser dbpass uploadsPath uploadsURL
        exportPath extrasPath extrasURL cacheType
        sitename spectreIp spectrePort spectreSubnets
        ) )
    {
        $set_config{$key} = $wgd->config->get($key);
    }

    $wgd->close_config;
    open my $fh, '>', $wgd->config_file or croak "Unable to write config file: $!";
    File::Copy::copy(
        File::Spec->catfile( $wgd->root, 'etc', 'WebGUI.conf.original' ),
        $fh );
    close $fh;

    my $config = $wgd->config;
    while ( my ( $key, $value ) = each %set_config ) {
        $config->set( $key, $value );
    }

    $self->report("Done\n");
    return 1;
}

sub set_settings {
    my $self = shift;
    my $wgd  = $self->wgd;
    $self->report('Setting WebGUI settings... ');
    my $dbh = $wgd->db->connect;
    my $sth = $dbh->prepare(
        q{REPLACE INTO `settings` (`name`, `value`) VALUES (?,?)});
    if ( $self->option('debug') ) {
        $sth->execute( 'showDebug', 1 );

        # for debug we set this to 1 year
        $sth->execute( 'sessionTimeout', 365 * 24 * 60 * 60 );
    }
    elsif ( defined $self->option('debug') ) {
        $sth->execute( 'showDebug', 0 );

        # default time is 2 hours
        $sth->execute( 'sessionTimeout', 2 * 60 * 60 );
    }
    if ( $self->option('starter') ) {
        $sth->execute( 'specialState', 'init' );
    }
    elsif ( defined $self->option('starter') ) {
        $dbh->do(q{DELETE FROM `settings` WHERE `name`='specialState'});
    }
    $self->report("Done\n");
    return 1;
}

sub clear_default_content {
    my $self = shift;
    my $wgd  = $self->wgd;
    $self->report('Clearing example assets... ');
    $self->report( 2, "\n" );
    my $home     = $wgd->asset->home;
    my $children = $home->getLineage(
        ['descendants'],
        {
            statesToInclude => [
                'published', 'trash',
                'clipboard', 'clipboard-limbo',
                'trash-limbo'
            ],
            statusToInclude => [ 'approved', 'pending', 'archive' ],
            excludeClasses => ['WebGUI::Asset::Wobject::Layout'],
            returnObjects  => 1,
            invertTree     => 1,
        } );
    for my $child ( @{$children} ) {
        $self->report( 2, sprintf "\tRemoving \%-35s '\%s'\n",
            $child->getName, $child->get('title') );
        $child->purge;
    }
    $self->report("Done\n");
    return 1;
}

sub purge_old_revisions {
    my $self = shift;
    my $wgd  = $self->wgd;
    require WebGUI::Asset;
    $self->report('Purging old Asset revisions... ');
    $self->report( 2, "\n" );
    my $sth = $wgd->db->connect->prepare(<<'END_SQL');
    SELECT assetData.assetId, asset.className, assetData.revisionDate
    FROM asset
        LEFT JOIN assetData on asset.assetId=assetData.assetId
    ORDER BY assetData.revisionDate ASC
END_SQL
    $sth->execute;
    while ( my ( $id, $class, $revision ) = $sth->fetchrow_array ) {
        my $current_revision
            = WebGUI::Asset->getCurrentRevisionDate( $wgd->session, $id );
        if ( !defined $current_revision || $current_revision == $revision ) {
            next;
        }
        my $asset
            = WebGUI::Asset->new( $wgd->session, $id, $class, $revision )
            || next;
        if ( $asset->getRevisionCount('approved') > 1 ) {
            $self->report( 2, sprintf "\tPurging \%-35s \%s '\%s'\n",
                $asset->getName, $revision, $asset->get('title') );
            $asset->purgeRevision;
        }
    }
    $self->report("Done\n");
    return 1;
}

sub clean_version_tags {
    my $self = shift;
    my $wgd  = $self->wgd;

    $self->report('Finding current version number... ');
    my $version = $wgd->version->database( $wgd->db->connect );
    $self->report("$version. Done\n");

    $self->report('Cleaning out versions Tags... ');
    my $tag_id = 'pbversion0000000000001';
    my $dbh    = $wgd->db->connect;
    my $sth    = $dbh->prepare(q{UPDATE `assetData` SET `tagId` = ?});
    $sth->execute($tag_id);
    $sth = $dbh->prepare(q{DELETE FROM `assetVersionTag`});
    $sth->execute;
    $sth = $dbh->prepare(<<'END_SQL');
        INSERT INTO `assetVersionTag`
            ( `tagId`, `name`, `isCommitted`, `creationDate`, `createdBy`, `commitDate`,
                `committedBy`, `isLocked`, `lockedBy`, `groupToUse`, `workflowId` )
        VALUES (?,?,?,?,?,?,?,?,?,?,?)
END_SQL
    my $now = time;
    $sth->execute( $tag_id, "Base $version Install",
        1, $now, '3', $now, '3', 0, q{}, '3', q{} );
    $self->report("Done\n");
    return 1;
}

sub run_all_workflows {
    my $self = shift;
    my $wgd  = $self->wgd;
    $self->report('Running all pending workflows... ');
    $self->report( 2, "\n" );
    require WebGUI::Workflow::Instance;
    my $sth = $wgd->db->connect->prepare(
        q{SELECT instanceId FROM WorkflowInstance});
    $sth->execute;
    while ( my ($instance_id) = $sth->fetchrow_array ) {
        my $instance
            = WebGUI::Workflow::Instance->new( $wgd->session, $instance_id );
        my $waiting_count = 0;
        while ( my $result = $instance->run ) {
            if ( $result eq 'complete' ) {
                $waiting_count = 0;
                next;
            }
            if ( $result eq 'waiting' ) {
                ##no critic (ProhibitMagicNumbers)
                if ( $waiting_count++ > 10 ) {
                    warn
                        "Unable to finish workflow $instance_id, too many iterations!\n";
                    last;
                }
                next;
            }
            if ( $result eq 'done' ) {
            }
            elsif ( $result eq 'error' ) {
                warn "Unable to finish workflow $instance_id.  Error!\n";
            }
            else {
                warn
                    "Unable to finish workflow $instance_id.  Unknown status $result!\n";
            }
            last;
        }
    }
    $self->report("Done\n");
    return 1;
}

sub rebuild_lineage {
    my $self = shift;
    my $wgd  = $self->wgd;
    $self->report('Rebuilding lineage... ');
    my $pid = fork;
    if ( !$pid ) {

        # silence output of rebuildLineage unless we're at max verbosity
        if ( $self->verbosity < 3 ) {    ##no critic (ProhibitMagicNumbers)
            ##no critic (RequireCheckedOpen R)
            open STDIN,  '<', File::Spec->devnull;
            open STDOUT, '>', File::Spec->devnull;
            open STDERR, '>', File::Spec->devnull;
        }
        print "\n\n";
        chdir File::Spec->catdir( $wgd->root, 'sbin' );
        local @ARGV = ( '--configFile=' . $wgd->config_file_relative );
        ##no critic (ProhibitPunctuationVars)
        # $0 should have the filename of the script being run
        local $0 = './rebuildLineage.pl';
        do $0;
        exit;
    }
    waitpid $pid, 0;
    $self->report("Done\n");
    return 1;
}

sub rebuild_index {
    my $self = shift;
    my $wgd  = $self->wgd;
    $self->report('Rebuilding search index... ');
    my $pid = fork;
    if ( !$pid ) {

        # silence output of searhc indexer unless we're at max verbosity
        if ( $self->verbosity < 3 ) {    ##no critic (ProhibitMagicNumbers)
            ##no critic (RequireCheckedOpen)
            open STDIN,  '<', File::Spec->devnull;
            open STDOUT, '>', File::Spec->devnull;
            open STDERR, '>', File::Spec->devnull;
        }
        print "\n\n";
        chdir File::Spec->catdir( $wgd->root, 'sbin' );
        local @ARGV
            = ( '--configFile=' . $wgd->config_file_relative, '--indexsite' );
        ##no critic (ProhibitPunctuationVars)
        # $0 should have the filename of the script being run
        local $0 = './search.pl';
        do $0;
        exit;
    }
    waitpid $pid, 0;
    $self->report("Done\n");
    return 1;
}

1;

__END__

=head1 NAME

WGDev::Command::Reset - Reset a site to defaults

=head1 SYNOPSIS

wgd reset [-v] [-q] [-f] [-d | -b | -t]

=head1 DESCRIPTION

Resets a site to defaults, including multiple cleanup options for setting up
a site for development or for a build.  Can also perform the cleanup functions
without resetting a site.

=head1 OPTIONS

=over 8

=item B<-v --verbose>

Output more information

=item B<-q --quiet>

Output less information

=item B<-f --fast>

Fast mode - equivalent to:
--no-upload --no-backup --no-delcache --no-purge --no-cleantags --no-index
--no-runwf

=item B<-t --test>

Test mode - equivalent to:
--backup --import

=item B<-d --dev>

Developer mode - equivalent to:
--backup --import --no-starter --debug --clear --upgrade --uploads

=item B<-b --build>

Build mode - equivalent to:
--verbose --backup --import --starter --no-debug --upgrade --purge --cleantags
--index --runwf

=item B<--backup --no-backup>

Backup database before doing any other operations.  Defaults to on.

=item B<--delcache --no-delcache>

Delete the site's cache.  Defaults to on.

=item B<--import --no-import>

Import a database script

=item B<--uploads --no-uploads>

Recreate uploads directory

=item B<--upgrade --no-upgrade>

Perform an upgrade - also controls which DB script to import

=item B<--debug --no-debug>

Enable debug mode and increase session timeout

=item B<--starter --no-starter>

Enable the site starter

=item B<--clear --no-clear>

Clear the content off the home page and its children

=item B<--config --no-config>

Resets the site's config file.  Some values like database information will be
preserved.  Additional options can be set in the WGDev config file.

=item B<--purge --no-purge>

Purge all old revisions

=item B<--cleantags --no-cleantags>

Removes all version tags and sets all asset revisions to be
under a new version tag marked with the current version number

=item B<--index --no-index>

Rebuild the site lineage and reindex all of the content

=item B<--runwf --no-runwf>

Attempt to finish any running workflows

=back

=head1 AUTHOR

Graham Knop <graham@plainblack.com>

=head1 LICENSE

Copyright (c) Graham Knop.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

