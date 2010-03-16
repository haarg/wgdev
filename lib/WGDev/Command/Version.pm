package WGDev::Command::Version;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.2.0';

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

use WGDev::X   ();
use File::Spec ();

sub needs_config {
    return;
}

sub config_parse_options { return qw(no_getopt_compat) }

sub config_options {
    return qw(
        create|c
        bare|b
        dist|d
    );
}

sub process {
    my $self = shift;
    my $wgd  = $self->wgd;

    my ($ver) = $self->arguments;

    if ( $self->option('create') ) {
        $ver = $self->update_version($ver);
    }

    my $wgv = $wgd->version;
    my ( $perl_version, $perl_status ) = $wgv->module;
    if ( $self->option('dist') ) {
        print $perl_version, q{-}, $perl_status, "\n";
        return 1;
    }
    if ( $self->option('bare') ) {
        print $perl_version, "\n";
        return 1;
    }

    my $db_version = $wgv->database_script;
    my ( $change_file, $change_version ) = $wgv->changelog;
    my ( $up_file, undef, $up_file_ver, $up_version ) = $wgv->upgrade;
    my $db_live_version = eval { $wgv->database( $wgd->db->connect ) };

    my $err_count = 0;
    my $expect_ver = $ver || $perl_version;
    if ( $perl_version ne $expect_ver ) {
        $err_count++;
        $perl_version = _colored( $perl_version, 'red' );
    }
    if ( $db_version ne $expect_ver ) {
        $err_count++;
        $db_version = _colored( $db_version, 'magenta' );
    }
    if ( $change_version ne $expect_ver ) {
        $err_count++;
        $change_version = _colored( $change_version, 'red' );
    }
    if ( $up_version ne $expect_ver ) {
        $err_count++;
        $up_version = _colored( $up_version, 'red' );
    }
    if ( $up_file_ver ne $expect_ver ) {
        $err_count++;
        $up_file = _colored( $up_file, 'red' );
    }
    if ( !defined $db_live_version ) {
        $err_count++;
        $db_live_version = _colored( 'Not available', 'magenta' );
    }
    elsif ( $db_live_version ne $expect_ver ) {
        $err_count++;
        $db_live_version = _colored( $db_live_version, 'red' );
    }

    print <<"END_REPORT";
  Perl version:             $perl_version - $perl_status
  Database version:         $db_live_version
  Database script version:  $db_version
  Changelog version:        $change_version
  Upgrade script version:   $up_version
  Upgrade script filename:  $up_file
END_REPORT

    if ($err_count) {
        return 0;
    }
    return 1;
}

sub update_version {
    my $self        = shift;
    my $ver         = shift;
    my $wgd         = $self->wgd;
    my $root        = $wgd->root;
    my $wgv         = $wgd->version;
    my $old_version = $wgv->module;
    my $new_version = $ver || do {
        my @parts = split /[.]/msx, $old_version;
        $parts[-1]++;
        join q{.}, @parts;
    };

    open my $fh, '<', File::Spec->catfile( $root, 'lib', 'WebGUI.pm' )
        or WGDev::X::IO::Read->throw( path => 'WebGUI.pm' );
    my @pm_content = do { local $/; <$fh> };
    close $fh
        or WGDev::X::IO::Read->throw( path => 'WebGUI.pm' );
    open $fh, '>', File::Spec->catfile( $root, 'lib', 'WebGUI.pm' )
        or WGDev::X::IO::Write->throw( path => 'WebGUI.pm' );
    for my $line (@pm_content) {
        $line =~ s/(\$VERSION\s*=)[^\n]*;/$1 '$new_version';/msx;
        print {$fh} $line;
    }
    close $fh
        or WGDev::X::IO::Write->throw( path => 'WebGUI.pm' );

    my ($change_file) = $wgv->changelog;
    open $fh, '<',
        File::Spec->catfile( $root, 'docs', 'changelog', $change_file )
        or WGDev::X::IO::Read->throw( path => $change_file );
    my $change_content = do { local $/; <$fh> };
    close $fh
        or WGDev::X::IO::Read->throw( path => $change_file );

    open $fh, '>',
        File::Spec->catfile( $root, 'docs', 'changelog', $change_file )
        or WGDev::X::IO::Write->throw( path => $change_file );
    print {$fh} $new_version . "\n\n" . $change_content;
    close $fh
        or WGDev::X::IO::Write->throw( path => $change_file );

    open my $in, '<',
        File::Spec->catfile( $root, 'docs', 'upgrades', '_upgrade.skeleton' )
        or WGDev::X::IO::Read->throw( path => '_upgrade.skeleton' );
    open my $out, '>',
        File::Spec->catfile( $root, 'docs', 'upgrades',
        "upgrade_$old_version-$new_version.pl" )
        or WGDev::X::IO::Write->throw(
        path => "upgrade_$old_version-$new_version.pl" );
    while ( my $line = <$in> ) {
        $line =~ s/(\$toVersion\s*=)[^\n]*$/$1 '$new_version';/xms;
        print {$out} $line;
    }
    close $out
        or WGDev::X::IO::Write->throw(
        path => "upgrade_$old_version-$new_version.pl" );
    close $in
        or WGDev::X::IO::Read->throw( path => '_upgrade.skeleton' );
    return $new_version;
}

sub _colored {
    no warnings 'redefine';
    if ( eval { require Term::ANSIColor; 1 } ) {
        *_colored = \&Term::ANSIColor::colored;
    }
    else {
        *_colored = sub { $_[0] };
    }
    goto &_colored;
}

1;

__END__


=head1 NAME

WGDev::Command::Version - Reports and updates version numbers

=head1 SYNOPSIS

    wgd version [-b | -c | -d] [<version>]

=head1 DESCRIPTION

Reports the current versions of the F<WebGUI.pm> module, F<create.sql> database
script, change log, and upgrade file.  Non-matching versions will be noted
in red if possible.

=head1 OPTIONS

=over 8

=item C<-c> C<--create>

Adds a new section to the change log for the new version, updates the version
number in F<WebGUI.pm>, and creates a new upgrade script.  The version number
to update to can be specified on the command line.  If not specified, defaults
to incrementing the patch level by one.

=item C<-d> C<--dist>

Output the version number and status of the current WebGUI, joined by a dash.
If the version is passed as well, it will be ignored.

=item C<-b> C<--bare>

Outputs the version number taken from F<WebGUI.pm> only

=item C<< <version> >>

The version number to compare against or create

=back

=head1 METHODS

=head2 C<update_version ( $new_version )>

Updates WebGUI's version number to the specified version.  If not provided,
the patch level of the version number is incremented.  The version number in
F<WebGUI.pm> is changed, a new upgrade script is created, and a heading is
added to the change log.

=head1 AUTHOR

Graham Knop <haarg@haarg.org>

=head1 LICENSE

Copyright (c) 2009-2010, Graham Knop

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl 5.10.0. For more details, see the
full text of the licenses in the directory LICENSES.

=cut

