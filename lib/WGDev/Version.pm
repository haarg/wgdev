package WGDev::Version;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.1.0';

use File::Spec;
use Carp qw(croak);

sub new {
    my $class = shift;
    my $dir   = shift || croak 'Must specify WebGUI base directory!';
    my $self  = bless \$dir, $class;
    return $self;
}

sub pm { goto &module }

sub module {
    my $dir = ${ +shift };
    my $version;
    my $status;
    ##no critic (RequireBriefOpen)
    open my $fh, '<', File::Spec->catfile( $dir, 'lib', 'WebGUI.pm' )
        or croak "Unable to read WebGUI.pm module: $!";
    while ( my $line = <$fh> ) {
        ##no critic (ProhibitStringyEval)
        if ( $line =~ /\$VERSION\s*=(.*)$/msx ) {
            $version = eval $1;
        }
        if ( $line =~ /\$STATUS\s*=(.*)$/msx ) {
            $status = eval $1;
        }
        last
            if $version && $status;
    }
    close $fh or croak "Unable to close filehandle: $!";
    return wantarray ? ( $version, $status ) : $version;
}

sub db_script { goto &database_script }

sub database_script {
    my $dir = ${ +shift };
    my $version;
    ##no critic (RequireBriefOpen)
    open my $fh, '<', File::Spec->catfile( $dir, 'docs', 'create.sql' )
        or croak "Unable to read create.sql script: $!";
    while ( my $line = <$fh> ) {
        ##no critic (ProhibitComplexRegexes)
        if (
            $line =~ m{
            (?:(?i)INSERT INTO)  \s+
            (`?)webguiVersion\1  \s+
            .+?                  \s+?
            (?i)VALUES           \s+
            \Q('\E ( [^']+ ) \Q')\E
            }msx
            )
        {
            $version = $2;
            last;
        }
    }
    close $fh or croak "Unable to close filehandle: $!";
    return $version;
}

sub db { goto &database }

sub database {
    my $dir = ${ +shift };
    my $dbh = shift;
    require version;
    my $sth = $dbh->prepare('SELECT webguiVersion FROM webguiVersion');
    $sth->execute;
    my @versions
        = map { $_->[0] }
        sort  { $a->[1] <=> $b->[1] }
        map { [ $_, version->new($_) ] }
        map { @{$_} } @{ $sth->fetchall_arrayref( [0] ) };
    $sth->finish;
    my $version = pop @versions;
    return $version;
}

sub changelog {
    my $dir = ${ +shift };
    require version;
    my @changelogs;
    opendir my $dh, File::Spec->catdir( $dir, 'docs', 'changelog' )
        or croak "Unable to list changelogs: $!";
    while ( my $file = readdir $dh ) {
        if ( $file =~ /^( [x\d]+ [.] [x\d]+ [.] [x\d]+ ) \Q.txt\E $/msx ) {
            ( my $v = $1 ) =~ tr/x/0/;
            push @changelogs, [ $file, version->new($v) ];
        }
    }
    closedir $dh;
    @changelogs = sort { $a->[1] <=> $b->[1] } @changelogs;
    my $latest = pop @changelogs;
    open my $fh, '<',
        File::Spec->catfile( $dir, 'docs', 'changelog', $latest->[0] )
        or croak "Unable to read changelog: $!";
    while ( my $line = <$fh> ) {
        if ( $line =~ /^(\d+\.\d+\.\d+)$/msx ) {
            $latest->[1] = $1;
            last;
        }
    }
    close $fh or croak "Unable to close filehandle: $!";
    return @{$latest};
}

# returns ($upgrade_file, $from_version, $to_version, $to_version_file)
sub upgrade {
    my $dir = ${ +shift };
    require version;
    my @upgrades;
    opendir my $dh, File::Spec->catdir( $dir, 'docs', 'upgrades' )
        or croak "Unable to list upgrades: $!";
    while ( my $file = readdir $dh ) {
        if ( $file =~ /^upgrade_ ([.\d]+) - ([.\d]+) \Q.pl\E$/msx ) {
            push @upgrades, [ $file, version->new($1), version->new($2) ];
        }
    }
    closedir $dh;
    @upgrades = sort { $a->[2] <=> $b->[2] } @upgrades;
    my $latest = pop @upgrades;
    open my $fh, '<',
        File::Spec->catfile( $dir, 'docs', 'upgrades', $latest->[0] )
        or croak "Unable to read upgrade script: $!";
    while ( my $line = <$fh> ) {
        if ( $line =~ /\$toVersion\s*=(.*)$/msx ) {
            ##no critic (ProhibitStringyEval RequireCheckingReturnValueOfEval)
            push @{$latest}, eval $1;
            last;
        }
    }
    close $fh or "Unable to close filehandle: $!";
    return @{$latest};
}

1;

