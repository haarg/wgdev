package WGDev::Version;
# ABSTRACT: Extract version information from WebGUI
use strict;
use warnings;
use 5.008008;

use File::Spec;
use WGDev::X ();

sub new {
    my $class = shift;
    my $dir   = shift || WGDev::X::NoWebGUIRoot->throw;
    my $self  = bless \$dir, $class;
    return $self;
}

sub pm { goto &module }

sub module {
    my $dir = ${ +shift };
    my $version;
    my $status;
    open my $fh, '<', File::Spec->catfile( $dir, 'lib', 'WebGUI.pm' )
        or WGDev::X::IO::Read->throw( path => 'WebGUI.pm' );
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
    close $fh
        or WGDev::X::IO::Read->throw( path => 'WebGUI.pm' );
    return wantarray ? ( $version, $status ) : $version;
}

sub db_script { goto &database_script }

sub database_script {
    my $self = shift;
    my $dir = ${ $self };
    my $wg8 = $self->module =~ /^8[.]/msx;
    my $version;
    my $db_file = $wg8 ? do {
        require WebGUI::Paths;
        WebGUI::Paths->defaultCreateSQL;
    } : File::Spec->catfile( $dir, 'docs', 'create.sql' );
    open my $fh, '<', $db_file
        or WGDev::X::IO::Read->throw( path => $db_file );
    while ( my $line = <$fh> ) {
        if (
            ##no critic (ProhibitComplexRegexes);
            $line =~ m{
                (?:(?i)\QINSERT INTO\E) \s+
                (`?)webguiVersion\1     \s+
                .+?                     \s+?
                (?i)VALUES              \s+
                \Q('\E ( [^']+ )        [']
            }msx
        ) {
            $version = $2;
            last;
        }
    }
    close $fh
        or WGDev::X::IO::Read->throw( path => $db_file );
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
        or WGDev::X::IO::Read->throw( path => 'docs/changelog' );
    while ( my $file = readdir $dh ) {
        if ( $file =~ /^( [x\d]+ [.] [x\d]+ [.] [x\d]+ ) \Q.txt\E $/msx ) {
            ( my $v = $1 ) =~ tr/x/0/;
            push @changelogs, [ $file, version->new($v) ];
        }
    }
    closedir $dh
        or WGDev::X::IO::Read->throw( path => 'docs/changelog' );
    @changelogs = sort { $a->[1] <=> $b->[1] } @changelogs;
    my $latest = pop @changelogs;
    open my $fh, '<',
        File::Spec->catfile( $dir, 'docs', 'changelog', $latest->[0] )
        or WGDev::X::IO::Read->throw( path => "docs/changelog/$latest->[0]" );
    while ( my $line = <$fh> ) {
        if ( $line =~ /^(\d+[.]\d+[.]\d+)$/msx ) {
            $latest->[1] = $1;
            last;
        }
    }
    close $fh
        or WGDev::X::IO::Read->throw( path => "docs/changelog/$latest->[0]" );
    return @{$latest};
}

# returns ($upgrade_file, $from_version, $to_version, $to_version_file)
sub upgrade {
    my $dir = ${ +shift };
    require version;
    my @upgrades;
    opendir my $dh, File::Spec->catdir( $dir, 'docs', 'upgrades' )
        or WGDev::X::IO::Read->throw( path => 'docs/upgrades' );
    while ( my $file = readdir $dh ) {
        if ( $file =~ /^upgrade_ ([.\d]+) - ([.\d]+) \Q.pl\E$/msx ) {
            push @upgrades, [ $file, version->new($1), version->new($2) ];
        }
    }
    closedir $dh
        or WGDev::X::IO::Read->throw( path => 'docs/upgrades' );
    @upgrades = sort { $a->[2] <=> $b->[2] } @upgrades;
    my $latest = pop @upgrades;
    open my $fh, '<',
        File::Spec->catfile( $dir, 'docs', 'upgrades', $latest->[0] )
        or
        WGDev::X::IO::Read->throw( path => 'docs/upgrades/' . $latest->[0] );
    while ( my $line = <$fh> ) {
        if ( $line =~ /\$toVersion\s*=(.*)$/msx ) {
            ##no critic (ProhibitStringyEval RequireCheckingReturnValueOfEval)
            push @{$latest}, eval $1;
            last;
        }
    }
    close $fh
        or
        WGDev::X::IO::Read->throw( path => 'docs/upgrades/' . $latest->[0] );
    return @{$latest};
}

1;

=head1 SYNOPSIS

    my $wgv = WGDev::Version->new('/data/WebGUI');
    print "You have WebGUI " . $wgv->module . "\n";

=head1 DESCRIPTION

Extracts version information from various places in WebGUI: the change log,
the upgrade script, the WebGUI module, the database creation script, or a
live database.

=method C<new ( $webgui_root )>

Creates a new WGDev::Version object.  Needs a WebGUI directory to be specified.

=for :list
= C<$webgui_root>
The root of the WebGUI directory to use for finding each file.

=method C<module>

In scalar context, returns the version number from the F<lib/WebGUI.pm>
module.  In array context, returns the version number and the status
(beta/stable).

=method C<pm>

An alias for the L</module> method.

=method C<changelog>

Returns the most recent version number noted in the change log.

=method C<upgrade>

    my ($upgrade_file, $from_version, $to_version, $to_version_file) = $wgv->upgrade;

Finds the most recent upgrade script and returns an array of
information about it.  The array contains the script's file name,
the version number it will upgrade from and to based on its file name,
and the version it will upgrade to noted in the script itself.

=method C<database_script>

Returns the version noted in the F<create.sql> database script.

=method C<db_script>

An alias for the L</database_script> method.

=method C<database ( $dbh )>

Accepts a database handle, and returns the latest version from the
C<webguiVersion> table.

=method C<db>

An alias for the L</database> method.

=cut

