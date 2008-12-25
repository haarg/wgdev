package WGDev::Command::Reset;
use strict;
use warnings;

our $VERSION = '0.1.1';

use WGDev::Command::Base;
our @ISA = qw(WGDev::Command::Base);

sub option_config {
    (shift->SUPER::option_config, qw(
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
        purge!
        cleantags!
        index!
        runwf!
    ))
}

sub parse_params {
    my $self = shift;
    my $result = $self->SUPER::parse_params(@_);

    if ($self->option('fast')) {
        $self->option('backup', 1)
            unless defined $self->option('backup');
        $self->option('uploads', 0)
            unless defined $self->option('uploads');
        $self->option('backup', 0)
            unless defined $self->option('backup');
        $self->option('delcache', 0)
            unless defined $self->option('delcache');
        $self->option('purge', 0)
            unless defined $self->option('purge');
        $self->option('cleantags', 0)
            unless defined $self->option('cleantags');
        $self->option('index', 0)
            unless defined $self->option('index');
        $self->option('runwf', 0)
            unless defined $self->option('runwf');
    }
    if ($self->option('dev')) {
        $self->option('backup', 1)
            unless defined $self->option('backup');
        $self->option('import', 1)
            unless defined $self->option('import');
        $self->option('uploads', 1)
            unless defined $self->option('uploads');
        $self->option('upgrade', 1)
            unless defined $self->option('upgrade');
        $self->option('starter', 0)
            unless defined $self->option('starter');
        $self->option('debug', 1)
            unless defined $self->option('debug');
        $self->option('clear', 1)
            unless defined $self->option('clear');
    }
    if ($self->option('build')) {
        $self->verbosity($self->verbosity + 1);
        $self->option('backup', 1)
            unless defined $self->option('backup');
        $self->option('uploads', 1)
            unless defined $self->option('uploads');
        $self->option('import', 1)
            unless defined $self->option('import');
        $self->option('starter', 1)
            unless defined $self->option('starter');
        $self->option('debug', 0)
            unless defined $self->option('debug');
        $self->option('upgrade', 1)
            unless defined $self->option('upgrade');
        $self->option('purge',1)
            unless defined $self->option('purge');
        $self->option('cleantags', 1)
            unless defined $self->option('cleantags');
        $self->option('index', 1)
            unless defined $self->option('index');
        $self->option('runwf', 1)
            unless defined $self->option('runwf');
    }
    $self->option('delcache', 1)
        unless defined $self->option('delcache');
    return $result;
}

sub process {
    my $self = shift;
    my $wgd = $self->wgd;

    require File::Spec;

    local $| = 1;

    if ($self->option('backup')) {
        $self->report("Backing up current database... ");
        $wgd->db->dump('/tmp/WebGUI-reset-backup.sql');
        $self->report("Done.\n");
    }

    # Clear cache
    if ($self->option('delcache')) {
        require File::Path;
        $self->report("Clearing cache... ");
        if ($wgd->config->get('cacheType') eq 'WebGUI::Cache::FileCache') {
            my $cache_dir = $wgd->config->get('fileCacheRoot') || '/tmp/WebGUICache';
            File::Path::rmtree($cache_dir);
        }
        elsif ($wgd->config->get('cacheType') eq 'WebGUI::Cache::Database') {
            # Don't clear the DB cache if we are importing, as that will wipe it anyway
            unless ($self->option('import')) {
                my $dsn = $wgd->db->connect;
                $dsn->do('DELETE FROM cache');
            }
        }
        else {
            # Can't clear a cache we don't know anything about
        }
        $self->report("Done.\n");
    }

    # Clear and recreate uploads
    if ($self->option('uploads')) {
        require File::Copy;
        require File::Find;
        require File::Path;
        $self->report("Recreating uploads... ");

        my $wg_uploads = File::Spec->catdir($wgd->root, 'www', 'uploads');
        my $site_uploads = $wgd->config->get('uploadsPath');
        File::Path::rmtree($site_uploads);
        File::Find::find({
            no_chdir    => 1,
            wanted      => sub {
                no warnings 'once';
                my $wg_path = $File::Find::name;
                my $site_path = File::Spec->rel2abs(File::Spec->abs2rel($wg_path, $wg_uploads), $site_uploads);
                if (-d $wg_path) {
                    my $dir = (File::Spec->splitdir($wg_path))[-1];
                    if ($dir =~ /^\./) {
                        $File::Find::prune = 1;
                        return;
                    }
                    File::Path::mkpath($site_path);
                }
                else {
                    File::Copy::copy($wg_path, $site_path);
                }
            },
        }, $wg_uploads);
        $self->report("Done\n");
    }

    if ($self->option('import')) {
        # Connect using dsn and clean out old tables
        $self->report("Clearing old database information... ");
        $wgd->db->clear;
        $self->report("Done.\n");

        # If we aren't upgrading, we're using the current DB version
        print "Importing clean database dump... " if $self->verbosity >= 1;
        my $db_file = $self->option('upgrade') ? 'previousVersion.sql' : 'create.sql';
        $wgd->db->load(File::Spec->catfile($wgd->root, 'docs', $db_file));
        print "Done.\n" if $self->verbosity >= 1;
    }

    # Run the upgrade in a fork
    if ($self->option('upgrade')) {
        print "Running upgrade script... " if $self->verbosity >= 1;
        # todo: only upgrade single site
        my $pid = fork;
        unless ($pid) {
            # child process, don't need to worry about restoring anything
            chdir File::Spec->catdir($wgd->root, 'sbin');
            @ARGV = qw(--doit --override --skipBackup);
            push @ARGV, '--quiet'
                if $self->verbosity < 2;
            do 'upgrade.pl';
            die $@ if $@;
            exit;
        }
        waitpid $pid, 0;
        if ($?) {
            die "Upgrade failed!\n";
        }
        print "Done.\n" if $self->verbosity >= 1;
    }

    print "Finding current version number... " if $self->verbosity >= 1;
    my $version = $wgd->version->database($wgd->db->connect);
    print "$version. Done.\n" if $self->verbosity >= 1;

    if (defined $self->option('debug') || defined $self->option('starter')) {
        print "Setting WebGUI settings... " if $self->verbosity >= 1;
        my $dbh = $wgd->db->connect;
        my $sth = $dbh->prepare("REPLACE INTO `settings` (`name`, `value`) VALUES (?,?)");
        if ($self->option('debug')) {
            $sth->execute('showDebug', 1);
            $sth->execute('sessionTimeout', 31536000);
        }
        elsif (defined $self->option('debug')) {
            $sth->execute('showDebug', 0);
            $sth->execute('sessionTimeout', 7200);
        }
        if ($self->option('starter')) {
            $sth->execute('specialState', 'init');
        }
        elsif (defined $self->option('starter')) {
            $dbh->do("DELETE FROM `settings` WHERE `name`='specialState'");
        }
        print "Done.\n" if $self->verbosity >= 1;
    }

    if ($self->option('clear')) {
        print "Clearing example assets... " if $self->verbosity >= 1;
        print "\n" if $self->verbosity >= 2;
        my $home = $wgd->asset->home;
        my $children = $home->getLineage(['descendants'], {
            statesToInclude => ['published', 'trash', 'clipboard', 'clipboard-limbo', 'trash-limbo'],
            statusToInclude => ['approved', 'pending', 'archive'],
            excludeClasses  => ['WebGUI::Asset::Wobject::Layout'],
            returnObjects   => 1,
            invertTree      => 1,
        });
        for my $child (@$children) {
            printf "\tRemoving \%-35s '\%s'\n", $child->getName, $child->get('title')
                if $self->verbosity >= 2;
            $child->purge;
        }
        print "Done.\n" if $self->verbosity >= 1;
    }

    if ($self->option('purge')) {
        require WebGUI::Asset;
        print "Purging old Asset revisions... " if $self->verbosity >= 1;
        print "\n" if $self->verbosity >= 2;
        my $sth = $wgd->db->connect->prepare(<<END_SQL);
        SELECT assetData.assetId, asset.className, assetData.revisionDate
        FROM asset
            LEFT JOIN assetData on asset.assetId=assetData.assetId
        ORDER BY assetData.revisionDate ASC
END_SQL
        $sth->execute;
        while (my ($id, $class, $revision) = $sth->fetchrow_array) {
            my $current_revision = WebGUI::Asset->getCurrentRevisionDate($wgd->session, $id);
            if (!defined $current_revision || $current_revision == $revision) {
                next;
            }
            my $asset = WebGUI::Asset->new($wgd->session, $id, $class, $revision)
                || next;
            if ($asset->getRevisionCount("approved") > 1) {
                printf "\tPurging \%-35s \%s '\%s'\n", $asset->getName, $revision, $asset->get('title')
                    if $self->verbosity >= 2;
                $asset->purgeRevision;
            }
        }
        print "Done.\n" if $self->verbosity >= 1;
    }

    if ($self->option('cleantags')) {
        print "Cleaning out versions Tags... " if $self->verbosity >= 1;
        my $tag_id = 'pbversion0000000000001';
        my $dbh = $wgd->db->connect;
        my $sth = $dbh->prepare("UPDATE `assetData` SET `tagId` = ?");
        $sth->execute($tag_id);
        $sth = $dbh->prepare("DELETE FROM `assetVersionTag`");
        $sth->execute;
        $sth = $dbh->prepare(<<'END_SQL');
            INSERT INTO `assetVersionTag`
                ( `tagId`, `name`, `isCommitted`, `creationDate`, `createdBy`, `commitDate`,
                  `committedBy`, `isLocked`, `lockedBy`, `groupToUse`, `workflowId` )
            VALUES (?,?,?,?,?,?,?,?,?,?,?)
END_SQL
        my $now = time;
        $sth->execute($tag_id, "Base $version Install", 1, $now, '3', $now, '3', 0, '', '3', '');
        print "Done.\n" if $self->verbosity >= 1;
    }

    if ($self->option('runwf')) {
        print "Running all pending workflows... " if $self->verbosity >= 1;
        print "\n" if $self->verbosity >= 2;
        require WebGUI::Workflow::Instance;
        my $sth = $wgd->db->connect->prepare("SELECT instanceId FROM WorkflowInstance");
        $sth->execute;
        while (my ($instanceId) = $sth->fetchrow_array) {
            my $instance = WebGUI::Workflow::Instance->new($wgd->session, $instanceId);
            my $waiting_count = 0;
            while (my $result = $instance->run) {
                if ($result eq 'complete') {
                    $waiting_count = 0;
                    next;
                }
                if ($result eq 'waiting') {
                    if ($waiting_count++ > 10) {
                        warn "Unable to finish workflow " . $instanceId . ", too many iterations!\n";
                        last;
                    }
                    next;
                }
                if ($result eq 'done') {
                }
                elsif ($result eq 'error') {
                    warn "Unable to finish workflow " . $instanceId . ".  Error!\n";
                }
                else {
                    warn "Unable to finish workflow " . $instanceId . ".  Unknown status $result!\n";
                }
                last;
            }
        }
        print "Done.\n" if $self->verbosity >= 1;
    }

    if ($self->option('index')) {
        print "Rebuilding lineage... " if $self->verbosity >= 1;
        my $pid = fork;
        unless ($pid) {
            if ($self->verbosity < 3) {
                open STDIN,  '<', File::Spec->devnull;
                open STDOUT, '>', File::Spec->devnull;
                open STDERR, '>', File::Spec->devnull;
            }
            print "\n\n";
            chdir File::Spec->catdir($wgd->root, 'sbin');
            @ARGV = ('--configFile=' . $wgd->config_file_relative);
            $0 = './rebuildLineage.pl';
            do $0;
            exit;
        }
        waitpid $pid, 0;
        print "Done.\n" if $self->verbosity >= 1;

        print "Rebuilding search index... " if $self->verbosity >= 1;
        $pid = fork;
        unless ($pid) {
            if ($self->verbosity < 3) {
                open STDIN,  '<', File::Spec->devnull;
                open STDOUT, '>', File::Spec->devnull;
                open STDERR, '>', File::Spec->devnull;
            }
            print "\n\n";
            chdir File::Spec->catdir($wgd->root, 'sbin');
            @ARGV = ('--configFile=' . $wgd->config_file_relative, '--indexsite');
            $0 = './search.pl';
            do $0;
            exit;
        }
        waitpid $pid, 0;
        print "Done.\n" if $self->verbosity >= 1;
    }
    return;
}

1;

__END__

=head1 NAME

WGDev::Command::Reset - Reset a site to defaults

=head1 DESCRIPTION

arguments:
    -v
    --verbose       Output more information
    -q
    --quiet         Output less information

    -f
    --fast          Fast mode - equivalent to:
                    --no-upload --no-backup --no-delcache --no-purge
                    --no-cleantags --no-index --no-runwf

    -t
    --test          Test mode - equivalent to:
                    --backup --import
    -d
    --dev           Developer mode - equivalent to:
                    --backup --import --no-starter --debug --clear
                    --upgrade --uploads
    -b
    --build         Build mode - equivalent to:
                    --verbose --backup --import --starter --no-debug
                    --upgrade --purge --cleantags --index --runwf

    --backup
    --no-backup     Backup database before doing any other operations.  Defaults to on.
    --delcache
    --no-delcache   Delete the site's cache.  Defaults to on.
    --import
    --no-import     Import a database script
    --uploads
    --no-uploads    Recreate uploads directory
    --upgrade
    --no-upgrade    Perform an upgrade - also controls which DB script to import
    --debug
    --no-debug      Enable debug mode and increase session timeout
    --starter
    --no-starter    Enable the site starter
    --clear
    --no-clear      Clear the content off the home page and its children
    --purge
    --no-purge      Purge all old revisions
    --cleantags
    --no-cleantags  Removes all version tags and sets all asset revisions to be
                    under a new version tag marked with the current version number
    --index
    --no-index      Rebuild the site lineage and reindex all of the content
    --runwf
    --no-runwf      Attempt to finish any running workflows

=cut

