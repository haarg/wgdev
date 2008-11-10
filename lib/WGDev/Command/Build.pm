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
    Getopt::Long::GetOptionsFromArray(\@_,
        'v|verbose'         => sub { $opt_verbose++ },
        'q|quiet'           => sub { $opt_verbose-- },

        's|sql!'            => \(my $opt_sql),
        'u|uploads!'        => \(my $opt_uploads),
    );

    unless (defined $opt_sql || defined $opt_uploads) {
        $opt_sql = 1;
        $opt_uploads = 1;
    }

    # Autoflush
    local $| = 1;

    require version;

    print "Finding current version number... " if $opt_verbose >= 1;
    my $version = $wgd->version->database($wgd->db->connect);
    print "$version. Done.\n" if $opt_verbose >= 1;

    if ($opt_sql) {
        require File::Copy;
        print "Creating database dump... " if $opt_verbose >= 1;
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

sub usage {
    my $class = shift;
    return __PACKAGE__ . " - Builds database script and uploads\n" . <<'END_HELP';

Uses the current database and uploads to build a new create.sql and update
the local uploads directory.  With no options, builds both sql and uploads.

arguments:
    -s
    --sql           make create.sql based on current database contents
    -u
    --uploads       make uploads based on current site's uploads

END_HELP
}
sub usage {

}

1;

