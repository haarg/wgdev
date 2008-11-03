package WGDev::Command::Build;
use strict;
use warnings;

our $VERSION = '0.1.0';

use Getopt::Long ();

sub run {
    my $class = shift;
    my $wgd = shift;
    unless ($wgd->config_file) {
        die "Can't find WebGUI root!\n";
    }

    my $opt_verbose = 0;
    Getopt::Long::Configure(qw(default gnu_getopt));
    Getopt::Long::GetOptionsFromArray(\@_
        'v|verbose'         => sub { $opt_verbose++ },
        'q|quiet'           => sub { $opt_verbose-- },

        's|sql!'            => \(my $opt_sql),
        'u|uploads!'        => \(my $opt_uploads),
    );

    $opt_sql        = defined $opt_sql      ? $opt_sql
                    : defined $opt_uploads  ? !$opt_uploads
                                            : 1;
    $opt_uploads    = defined $opt_uploads  ? $opt_uploads
                                            : 0;
    # Autoflush
    local $| = 1;

    require version;

    print "Finding current version number... " if $opt_verbose >= 1;
    my $dbh = $wgd->db->connect;
    my $sth = $dbh->prepare('SELECT webguiVersion FROM webguiVersion');
    $sth->execute;
    my @versions =
        map { $_->[0] }
        sort { $a->[1] <=> $b->[1]}
        map { [$_, version->new($_)] }
        map {@$_} @{$sth->fetchall_arrayref([0])};
    $sth->finish;
    $dbh->disconnect;
    my $version = pop @versions;
    print "$version. Done.\n" if $opt_verbose >= 1;

    if ($opt_sql) {
        print "Creating database dump... " if $opt_verbose >= 1;
        my $db_file = File::Spec->catfile($wgd->root, 'docs', 'create.sql');
        open my $out, '>', $db_file;

        open my $in, '-|', 'mysql', $wgd->db->command_line('--compact', '--no-data');
        while (my $line = <$in>) {
            print {$out} $line;
        }
        close $in;

        my @skip_data_tables = qw(
            userSession     userSessionScratch
            webguiVersion   userLoginLog
            assetHistory    cache
        );
        open my $in, '-|', 'mysql', $wgd->db->command_line('--compact', '--no-create-info',
            map { "--ignore-table=$db_name.$_" } @skip_data_tables,
        while (my $line = <$in>) {
            print {$out} $line;
        }
        close $in;

        print {$out} "INSERT INTO webguiVersion (webguiVersion,versionType,dateApplied) VALUES ('$version','Initial Install',UNIX_TIMESTAMP());\n";

        close $out;
        print "Done.\n" if $opt_verbose >= 1;
    }

# Clear and recreate uploads
    if ($opt_uploads) {
        require File::Copy;
        require File::Find;
        require File::Path;

        print "Loading uploads from site... " if $opt_verbose >= 1;
        my $wg_uploads = File::Spec->catdir($wgd->root, 'www', 'uploads');
        File::Path::mkpath($wg_uploads);
        my $site_uploads = $config->get('uploadsPath');
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
                my $site_path = File::Spec->rel2abs($rel_path, $wg_uploads);
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
                File::Copy::copy($site_path, $wg_path);
            },
        }, $site_uploads);
        print "Done\n" if $opt_verbose >= 1;
    }
}

1;

