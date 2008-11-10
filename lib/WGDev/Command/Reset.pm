package WGDev::Command::Reset;
use strict;
use warnings;

our $VERSION = '0.1.1';

use Getopt::Long ();

sub run {
    my $class = shift;
    my $wgd = shift;

    my $opt_verbose = 1;
    Getopt::Long::Configure(qw(default gnu_getopt));
    Getopt::Long::GetOptionsFromArray(\@_,
        'v|verbose'     => sub { $opt_verbose++ },
        'q|quiet'       => sub { $opt_verbose-- },

        'f|fast'        => \(my $opt_fast),     # --no-upload --no-backup --no-delcache
                                                # --no-purge --no-cleantags --no-index --no-runwf

        'backup!'       => \(my $opt_backup),   # take a backup
        'delcache!'     => \(my $opt_delcache), # clear the cache
        'import!'       => \(my $opt_import),   # import a db script

        't|test'        => \(my $opt_test),     # --backup --import
        'd|dev'         => \(my $opt_dev),      # --backup --import --no-starter --debug --clear --upgrade --uploads
        'b|build'       => \(my $opt_build),    # --verbose --backup --import --starter --no-debug --upgrade --purge
                                                # --cleantags --index --runwf

        'uploads!'      => \(my $opt_uploads),  # recreate the uploads dir
        'upgrade!'      => \(my $opt_upgrade),  # use create.sql vs use previousVersion.sql and run the upgrade script

        'debug!'        => \(my $opt_debug),    # enable debug
        'starter!'      => \(my $opt_starter),  # enable site starter
        'clear!'        => \(my $opt_clear),    # clear example content
        'purge!'        => \(my $opt_purge),    # purge old asset revisions
        'cleantags!'    => \(my $opt_cleantags),# clear version tags
        'index!'        => \(my $opt_index),    # rebuild lineage and reindex search
        'runwf!'        => \(my $opt_runwf),    # run all workflows
    );

    if ($opt_fast) {
        $opt_backup     = 1
            unless defined $opt_backup;
        $opt_uploads    = 0
            unless defined $opt_uploads;
        $opt_backup     = 0
            unless defined $opt_backup;
        $opt_delcache   = 0
            unless defined $opt_delcache;
        $opt_purge      = 0
            unless defined $opt_purge;
        $opt_cleantags  = 0
            unless defined $opt_cleantags;
        $opt_index      = 0
            unless defined $opt_index;
        $opt_runwf      = 0
            unless defined $opt_runwf;
    }
    if ($opt_dev) {
        $opt_backup     = 1
            unless defined $opt_backup;
        $opt_import     = 1
            unless defined $opt_import;
        $opt_starter    = 0
            unless defined $opt_starter;
        $opt_debug      = 1
            unless defined $opt_debug;
        $opt_clear      = 1
            unless defined $opt_clear;
        $opt_uploads    = 1
            unless defined $opt_uploads;
        $opt_upgrade    = 1
            unless defined $opt_upgrade;
    }
    if ($opt_build) {
        $opt_verbose++;
        $opt_backup     = 1
            unless defined $opt_backup;
        $opt_import     = 1
            unless defined $opt_import;
        $opt_starter    = 1
            unless defined $opt_starter;
        $opt_debug      = 0
            unless defined $opt_debug;
        $opt_upgrade    = 1
            unless defined $opt_upgrade;
        $opt_purge      = 1
            unless defined $opt_purge;
        $opt_cleantags  = 1
            unless defined $opt_cleantags;
        $opt_index      = 1
            unless defined $opt_index;
        $opt_runwf      = 1
            unless defined $opt_runwf;
    }
    $opt_delcache = 1
        unless defined $opt_delcache;

    require File::Spec;

    local $| = 1;

    if ($opt_backup) {
        print "Backing up current database... " if $opt_verbose >= 1;
        $wgd->db->dump('/tmp/WebGUI-reset-backup.sql');
        print "Done.\n" if $opt_verbose >= 1;
    }

    # Clear cache
    if ($opt_delcache) {
        require File::Path;
        print "Clearing cache... " if $opt_verbose >= 1;
        if ($wgd->config->get('cacheType') eq 'WebGUI::Cache::FileCache') {
            my $cache_dir = $wgd->config->get('fileCacheRoot') || '/tmp/WebGUICache';
            File::Path::rmtree($cache_dir);
        }
        else {
            # We'd clear the DB cache here, but the whole database will be cleared in a later step
        }
        print "Done.\n" if $opt_verbose >= 1;
    }

    # Clear and recreate uploads
    if ($opt_uploads) {
        require File::Copy;
        require File::Find;
        require File::Path;
        print "Recreating uploads... " if $opt_verbose >= 1;

        my $wg_uploads = File::Spec->catdir($wgd->root, 'www', 'uploads');
        my $site_uploads = $wgd->config->get('uploadsPath');
        File::Path::rmtree($site_uploads);
        File::Find::find({
            no_chdir    => 1,
            wanted      => sub {
                no warnings;
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
        print "Done\n" if $opt_verbose >= 1;
    }

    if ($opt_import) {
        # Connect using dsn and clean out old tables
        print "Clearing old database information... " if $opt_verbose >= 1;
        $wgd->db->clear;
        print "Done.\n" if $opt_verbose >= 1;

        # If we aren't upgrading, we're using the current DB version
        print "Importing clean database dump... " if $opt_verbose >= 1;
        my $db_file = $opt_upgrade ? 'previousVersion.sql' : 'create.sql';
        $wgd->db->load(File::Spec->catfile($wgd->root, 'docs', $db_file));
        print "Done.\n" if $opt_verbose >= 1;
    }

    # Run the upgrade in a fork
    if ($opt_upgrade) {
        print "Running upgrade script... " if $opt_verbose >= 1;
        # todo: only upgrade single site
        my $pid = fork;
        unless ($pid) {
            # child process, don't need to worry about restoring anything
            chdir File::Spec->catdir($wgd->root, 'sbin');
            @ARGV = qw(--doit --override --skipBackup);
            push @ARGV, '--quiet'
                if $opt_verbose < 2;
            do 'upgrade.pl';
            die $@ if $@;
            exit;
        }
        waitpid $pid, 0;
        if ($?) {
            die "Upgrade failed!\n";
        }
        print "Done.\n" if $opt_verbose >= 1;
    }

    print "Finding current version number... " if $opt_verbose >= 1;
    my $version = $wgd->version->database($wgd->db->connect);
    print "$version. Done.\n" if $opt_verbose >= 1;

    if (defined $opt_debug || defined $opt_starter) {
        print "Setting WebGUI settings... " if $opt_verbose >= 1;
        my $dbh = $wgd->db->connect;
        my $sth = $dbh->prepare("REPLACE INTO `settings` (`name`, `value`) VALUES (?,?)");
        if ($opt_debug) {
            $sth->execute('showDebug', 1);
            $sth->execute('sessionTimeout', 31536000);
        }
        elsif (defined $opt_debug) {
            $sth->execute('showDebug', 0);
            $sth->execute('sessionTimeout', 7200);
        }
        if ($opt_starter) {
            $sth->execute('specialState', 'init');
        }
        elsif (defined $opt_starter) {
            $dbh->do("DELETE FROM `settings` WHERE `name`='specialState'");
        }
        print "Done.\n" if $opt_verbose >= 1;
    }

    if ($opt_clear) {
        print "Clearing example assets... " if $opt_verbose >= 1;
        print "\n" if $opt_verbose >= 2;
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
                if $opt_verbose >= 2;
            $child->purge;
        }
        print "Done.\n" if $opt_verbose >= 1;
    }

    if ($opt_purge) {
        require WebGUI::Asset;
        print "Purging old Asset revisions... " if $opt_verbose >= 1;
        print "\n" if $opt_verbose >= 2;
        my $sth = $wgd->db->connect->prepare(<<END_SQL);
        SELECT assetData.assetId, asset.className, assetData.revisionDate
        FROM asset
            LEFT JOIN assetData on asset.assetId=assetData.assetId
        ORDER BY assetData.revisionDate ASC
END_SQL
        $sth->execute;
        while (my ($id, $class, $version) = $sth->fetchrow_array) {
            my $current_version = WebGUI::Asset->getCurrentRevisionDate($wgd->session, $id);
            if (!defined $current_version || $current_version == $version) {
                next;
            }
            my $asset = WebGUI::Asset->new($wgd->session, $id, $class, $version)
                || next;
            if ($asset->getRevisionCount("approved") > 1) {
                printf "\tPurging \%-35s \%s '\%s'\n", $asset->getName, $version, $asset->get('title')
                    if $opt_verbose >= 2;
                $asset->purgeRevision;
            }
        }
        print "Done.\n" if $opt_verbose >= 1;
    }

    if ($opt_cleantags) {
        print "Cleaning out versions Tags... " if $opt_verbose >= 1;
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
        print "Done.\n" if $opt_verbose >= 1;
    }

    if ($opt_runwf) {
        print "Running all pending workflows... " if $opt_verbose >= 1;
        print "\n" if $opt_verbose >= 2;
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
        print "Done.\n" if $opt_verbose >= 1;
    }

    if ($opt_index) {
        print "Rebuilding lineage... " if $opt_verbose >= 1;
        my $pid = fork;
        unless ($pid) {
            if ($opt_verbose < 3) {
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
        print "Done.\n" if $opt_verbose >= 1;

        print "Rebuilding search index... " if $opt_verbose >= 1;
        $pid = fork;
        unless ($pid) {
            if ($opt_verbose < 3) {
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
        print "Done.\n" if $opt_verbose >= 1;
    }
    return;
}

sub usage {
    my $class = shift;
    my $message = __PACKAGE__ . "\n" . <<'END_HELP';

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

END_HELP

    return $message;
}

1;

