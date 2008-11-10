package WGDev::Command::Version;
use strict;
use warnings;

our $VERSION = '0.1.0';

use Getopt::Long ();

sub run {
    my $class = shift;
    my $wgd = shift;
    Getopt::Long::Configure(qw(no_getopt_compat));
    Getopt::Long::GetOptionsFromArray(\@_,
        'c|create'      => \(my $opt_create),
        'b|bare'        => \(my $opt_bare),
    );

    my $ver = shift @_;

    my $wgv = $wgd->version;
    if ($opt_create) {
        my $root = $wgd->root;
        my $old_version = $wgv->module;
        my $new_version = $ver || do {
            my @parts = split /\./, $old_version;
            $parts[-1]++;
            join '.', @parts;
        };

        open my $fh, '<', File::Spec->catfile($root, 'lib', 'WebGUI.pm');
        my @pm_content = do { local $/; <$fh> };
        close $fh;
        open $fh, '>', File::Spec->catfile($root, 'lib', 'WebGUI.pm');
        for my $line (@pm_content) {
            $line =~ s/(\$VERSION\s*=).*;/$1 '$new_version';/;
            print {$fh} $line;
        }
        close $fh;

        my ($change_file) = $wgv->changelog;
        my $change_content = do {
            open my $fh, '<', File::Spec->catfile($root, 'docs', 'changelog', $change_file);
            local $/;
            <$fh>;
        };
        open $fh, '>', File::Spec->catfile($root, 'docs', 'changelog', $change_file);
        print {$fh} $new_version . "\n\n" . $change_content;
        close $fh;

        open my $in, '<', File::Spec->catfile($root, 'docs', 'upgrades', '_upgrade.skeleton');
        open my $out, '>', File::Spec->catfile($root, 'docs', 'upgrades', "upgrade_$old_version-$new_version.pl");
        while (my $line = <$in>) {
            $line =~ s/(\$toVersion\s*=).*$/$1 '$new_version';/;
            print {$out} $line;
        }
        close $out;
        close $in;
    }

    my ($perl_version, $perl_status) = $wgv->module;
    if ($opt_bare) {
        print $perl_version, "\n";
        exit;
    }

    my $db_version = $wgv->database_script;
    my ($change_file, $change_version) = $wgv->changelog;
    my ($up_file, undef, $up_file_ver, $up_version) = $wgv->upgrade;

    my $err_count = 0;
    my $expect_ver = $ver || $perl_version;
    if ($perl_version ne $expect_ver) {
        $err_count++;
        $perl_version = colored($perl_version, 'bold red')
    }
    if ($db_version ne $expect_ver) {
        $err_count++;
        $db_version = colored($db_version, 'bold red')
    }
    if ($change_version ne $expect_ver) {
        $err_count++;
        $change_version = colored($change_version, 'bold red')
    }
    if ($up_version ne $expect_ver) {
        $err_count++;
        $up_version = colored($up_version, 'bold red')
    }
    if ($up_file_ver ne $expect_ver) {
        $err_count++;
        $up_file = colored($up_file, 'bold red')
    }

    print <<END_REPORT;
  Perl version:             $perl_version - $perl_status
  Database version:         $db_version
  Changelog version:        $change_version
  Upgrade script version:   $up_version
  Upgrade script filename:  $up_file
END_REPORT

    print colored("\n  Version numbers don't match!\n", 'bold red')
        if $err_count;

}

sub colored {
    no warnings 'redefine';
    if (eval { require Term::ANSIColor; 1 }) {
        *colored = \&Term::ANSIColor::colored;
    }
    else {
        *colored = sub {$_[0]};
    }
    goto &colored;
}

sub usage {
    my $class = shift;
    return __PACKAGE__ . " - Reports and updates version numbers\n" . <<'END_HELP';

Reports the current versions of the WebGUI.pm module, create.sql database
script, changelog, and upgrade file.  Non-matching versions will be noted
in red if possible.

arguments:
    <version number>    the expected version number to compare with
    -c
    --create            change the version number to a new one in the changelog,
                        WebGUI.pm, and creates a new upgrade script.  If the
                        version number isn't otherwise specified, increments
                        the patch level by one.

END_HELP
}

1;

