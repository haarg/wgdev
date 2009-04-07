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
        if (
            $line =~ m{
            (?:(?i)\QINSERT INTO\E) \s+
            (`?)webguiVersion\1     \s+
            .+?                     \s+?
            (?i)VALUES              \s+
            \Q('\E ( [^']+ )        [']
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
    my @versions = map { $_->[0] }
        sort { $a->[1] <=> $b->[1] }
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
    closedir $dh
        or croak "Unable to close directory handle: $!";
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
    closedir $dh
        or croak "Unable to close directory handle: $!";
    @upgrades = sort { $a->[2] <=> $b->[2] } @upgrades;
    my $latest = pop @upgrades;
    open my $fh, '<',    ##no critic (RequireBriefOpen)
        File::Spec->catfile( $dir, 'docs', 'upgrades', $latest->[0] )
        or croak "Unable to read upgrade script: $!";
    while ( my $line = <$fh> ) {
        if ( $line =~ /\$toVersion\s*=(.*)$/msx ) {
            ##no critic (ProhibitStringyEval RequireCheckingReturnValueOfEval)
            push @{$latest}, eval $1;
            last;
        }
    }
    close $fh or croak "Unable to close filehandle: $!";
    return @{$latest};
}

1;

__END__

=head1 NAME

WGDev::Version - Extract version information from WebGUI

=head1 SYNOPSIS

    my $wgv = WGDev::Version->new('/data/WebGUI');
    print "You have WebGUI " . $wgv->module . "\n";

=head1 DESCRIPTION

Extracts version information from various places in WebGUI: the change log,
the upgrade script, the WebGUI module, the database creation script, or a
live database.

=head1 METHODS

=head2 C<new ( $webgui_root )>

Creates a new WGDev::Version object.  Needs a WebGUI directory to be specified.

=head3 C<$webgui_root>

The root of the WebGUI directory to use for finding each file.

=head2 C<module>

In scalar context, returns the version number from the F<lib/WebGUI.pm>
module.  In array context, returns the version number and the status
(beta/stable).

=head2 C<pm>

An alias for the L</module> method.

=head2 C<changelog>

Returns the most recent version number noted in the change log.

=head2 C<upgrade>

    my ($upgrade_file, $from_version, $to_version, $to_version_file) = $wgv->upgrade;

Finds the most recent upgrade script and returns an array of
information about it.  The array contains the script's file name,
the version number it will upgrade from and to based on its file name,
and the version it will upgrade to noted in the script itself.

=head2 C<database_script>

Returns the version noted in the F<create.sql> database script.

=head2 C<db_script>

An alias for the L</database_script> method.

=head2 C<database ( $dbh )>

Accepts a database handle, and returns the latest version from the
C<webguiVersion> table.

=head2 C<db>

An alias for the L</database> method.

=head1 AUTHOR

Graham Knop <graham@plainblack.com>

=head1 LICENSE

Copyright (c) Graham Knop.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

