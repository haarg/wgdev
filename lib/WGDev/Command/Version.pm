package WGDev::Command::Version;
use strict;
use warnings;

our $VERSION = '0.1.0';

use WGDev::Command::Base;
our @ISA = qw(WGDev::Command::Base);

sub option_parse_config { qw(no_getopt_compat) };
sub option_config {qw(
    create|c
    bare|b
)}

sub process {
    my $self = shift;
    my $wgd = $self->wgd;

    my ($ver) = $self->arguments;

    my $wgv = $wgd->version;
    if ($self->option('create')) {
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
    if ($self->option('bare')) {
        print $perl_version, "\n";
        return 1;
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
    return 1;
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

1;

__END__


=head1 NAME

WGDev::Command::Version - Reports and updates version numbers

=head1 SYNOPSIS

version [options] [version]

 Options:
    version             version number to compare against or create

    -c      --create    update version to next or specified version
    -b      --bare      output bare version number only, from WebGUI.pm

=head1 OPTIONS

=over 8

=item B<--create>

Adds a new section to the changelog for the new version, updates the version
number in WebGUI.pm, and creates a new upgrade script.  The version number to
update to can be specified on the command line.  If not specified, defaults
to incrementing the patch level by one.

=item B<--bare>

Outputs the version number taken from WebGUI.pm only

=back

=head1 DESCRIPTION

Reports the current versions of the WebGUI.pm module, create.sql database
script, changelog, and upgrade file.  Non-matching versions will be noted
in red if possible.

=cut

