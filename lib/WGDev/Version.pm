package WGDev::Version;
use strict;
use warnings;

our $VERSION = '0.1.0';

use version;
use File::Spec;

sub new {
    my $class = shift;
    my $dir = shift || die;
    my $self = bless \$dir, $class;
    return $self;
}

sub pm { goto &module }
sub module {
    my $dir = ${ +shift };
    my $version;
    my $status;
    open my $fh, '<', File::Spec->catfile($dir, 'lib', 'WebGUI.pm') or die;
    while (my $line = <$fh>) {
        if ($line =~ /\$VERSION\s*=(.*)$/) {
            $version = eval $1;
        }
        if ($line =~ /\$STATUS\s*=(.*)$/) {
            $status = eval $1;
        }
        last
            if $version && $status;
    }
    close $fh;
    return wantarray ? ($version, $status) : $version;
}

sub db_script { goto &database_script }
sub database_script {
    my $dir = ${ +shift };
    my $version;
    open my $fh, '<', File::Spec->catfile($dir, 'docs', 'create.sql') or die;
    while (my $line = <$fh>) {
        if ($line =~ /(?:(?i)INSERT INTO) (`?)webguiVersion\1\s+.+? (?i)VALUES \('([^']+)'/) {
            $version = $2;
            last;
        }
    }
    close $fh;
    return $version;
}

sub db { goto &database }
sub database {
    my $dir = ${ +shift };
    my $dbh = shift;
    require version;
    my $sth = $dbh->prepare('SELECT webguiVersion FROM webguiVersion');
    $sth->execute;
    my @versions =
        map { $_->[0] }
        sort { $a->[1] <=> $b->[1]}
        map { [$_, version->new($_)] }
        map {@$_} @{$sth->fetchall_arrayref([0])};
    $sth->finish;
    my $version = pop @versions;
    return $version;
}

sub changelog {
    my $dir = ${ +shift };
    my @changelogs;
    opendir my $dh, File::Spec->catdir($dir, 'docs', 'changelog') or die;
    while (my $file = readdir($dh)) {
        if ($file =~ /^([0-9x]+\.[0-9x]+\.[0-9x]+)\.txt$/) {
            (my $v = $1) =~ tr/x/0/;
            push @changelogs, [$file, version->new($v)];
        }
    }
    closedir $dh;
    @changelogs = sort {$a->[1] <=> $b->[1]} @changelogs;
    my $latest = pop @changelogs;
    open my $fh, '<', File::Spec->catfile($dir, 'docs', 'changelog', $latest->[0]) or die;
    while (my $line = <$fh>) {
        if ($line =~ /^(\d+\.\d+\.\d+)$/) {
            $latest->[1] = $1;
            last;
        }
    }
    close $fh;
    return @$latest;
}

# returns ($upgrade_file, $from_version, $to_version, $to_version_file)
sub upgrade {
    my $dir = ${ +shift };
    my @upgrades;
    opendir my $dh, File::Spec->catdir($dir, 'docs', 'upgrades') or die;
    while (my $file = readdir($dh)) {
        if ($file =~ /^upgrade_([.0-9]+)-([.0-9]+)\.pl$/) {
            push @upgrades, [$file, version->new($1), version->new($2)];
        }
    }
    closedir $dh;
    @upgrades = sort {$a->[2] <=> $b->[2]} @upgrades;
    my $latest = pop @upgrades;
    open my $fh, '<', File::Spec->catfile($dir, 'docs', 'upgrades', $latest->[0]) or die;
    while (my $line = <$fh>) {
        if ($line =~ /\$toVersion\s*=(.*)$/) {
            push @$latest, eval $1;
            last;
        }
    }
    close $fh;
    return @$latest;
}

1;

