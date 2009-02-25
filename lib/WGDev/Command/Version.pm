package WGDev::Command::Version;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.1.0';

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

use Carp qw(croak);
use File::Spec ();

sub option_parse_config { return qw(no_getopt_compat) }

sub option_config {
    return qw(
        create|c
        bare|b
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
    if ( $self->option('bare') ) {
        print $perl_version, "\n";
        return 1;
    }

    my $db_version = $wgv->database_script;
    my ( $change_file, $change_version ) = $wgv->changelog;
    my ( $up_file, undef, $up_file_ver, $up_version ) = $wgv->upgrade;

    my $err_count = 0;
    my $expect_ver = $ver || $perl_version;
    if ( $perl_version ne $expect_ver ) {
        $err_count++;
        $perl_version = colored( $perl_version, 'bold red' );
    }
    if ( $db_version ne $expect_ver ) {
        $err_count++;
        $db_version = colored( $db_version, 'bold red' );
    }
    if ( $change_version ne $expect_ver ) {
        $err_count++;
        $change_version = colored( $change_version, 'bold red' );
    }
    if ( $up_version ne $expect_ver ) {
        $err_count++;
        $up_version = colored( $up_version, 'bold red' );
    }
    if ( $up_file_ver ne $expect_ver ) {
        $err_count++;
        $up_file = colored( $up_file, 'bold red' );
    }

    print <<"END_REPORT";
  Perl version:             $perl_version - $perl_status
  Database version:         $db_version
  Changelog version:        $change_version
  Upgrade script version:   $up_version
  Upgrade script filename:  $up_file
END_REPORT

    if ($err_count) {
        print colored( "\n  Version numbers don't match!\n", 'bold red' );
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
        or croak "Unable to read WebGUI.pm file: $!\n";
    my @pm_content = do { local $/ = undef; <$fh> };
    close $fh or croak "Unable to read WebGUI.pm file: $!";
    open $fh, '>', File::Spec->catfile( $root, 'lib', 'WebGUI.pm' )
        or croak "Unable to write to WebGUI.pm file: $!\n";
    for my $line (@pm_content) {
        $line =~ s/(\$VERSION\s*=)[^\n]*;/$1 '$new_version';/msx;
        print {$fh} $line;
    }
    close $fh or croak "Unable to write to WebGUI.pm file: $!\n";

    my ($change_file) = $wgv->changelog;
    open $fh, '<',
        File::Spec->catfile( $root, 'docs', 'changelog', $change_file )
        or croak "Unable to read changelog $change_file\: $!\n";
    my $change_content = do { local $/ = undef; <$fh> };
    close $fh or croak "Unable to read changelog $change_file\: $!\n";

    open $fh, '>',
        File::Spec->catfile( $root, 'docs', 'changelog', $change_file )
        or croak "Unable to write to changelog $change_file\: $!\n";
    print {$fh} $new_version . "\n\n" . $change_content;
    close $fh or croak "Unable to write to changelog $change_file\: $!\n";

    ##no critic (RequireBriefOpen)
    open my $in, '<',
        File::Spec->catfile( $root, 'docs', 'upgrades', '_upgrade.skeleton' )
        or croak "Unable to read upgrade skeleton: $!\n";
    open my $out, '>',
        File::Spec->catfile( $root, 'docs', 'upgrades',
        "upgrade_$old_version-$new_version.pl" )
        or croak "Unable to write to new upgrade script: $!\n";
    while ( my $line = <$in> ) {
        $line =~ s/(\$toVersion\s*=)[^\n]*$/$1 '$new_version';/xms;
        print {$out} $line;
    }
    close $out
        or croak "Unable to read upgrade skeleton: $!\n";
    close $in
        or croak "Unable to write to new upgrade script: $!\n";
    return $new_version;
}

sub colored {
    no warnings 'redefine';
    if ( eval { require Term::ANSIColor; 1 } ) {
        *colored = \&Term::ANSIColor::colored;
    }
    else {
        *colored = sub { $_[0] };
    }
    goto &colored;
}

1;

__END__


=head1 NAME

WGDev::Command::Version - Reports and updates version numbers

=head1 SYNOPSIS

wgd version [-b | -c] [<version>]

=head1 DESCRIPTION

Reports the current versions of the WebGUI.pm module, create.sql database
script, changelog, and upgrade file.  Non-matching versions will be noted
in red if possible.

=head1 OPTIONS

=over 8

=item B<--create>

Adds a new section to the changelog for the new version, updates the version
number in WebGUI.pm, and creates a new upgrade script.  The version number to
update to can be specified on the command line.  If not specified, defaults
to incrementing the patch level by one.

=item B<--bare>

Outputs the version number taken from WebGUI.pm only

=item B<E<lt>versionE<gt>>

version number to compare against or create

=back

=head1 AUTHOR

Graham Knop <graham@plainblack.com>

=head1 LICENSE

Copyright (c) Graham Knop.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

