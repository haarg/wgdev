package WGDev::Help;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.1.0';

use WGDev::X   ();
use File::Spec ();

sub package_usage {
    my $package   = shift;
    my $verbosity = shift;
    require WGDev::Pod::Usage;
    if ( !defined $verbosity ) {
        $verbosity = 1;
    }
    my $parser = WGDev::Pod::Usage->new;
    $parser->verbosity($verbosity);
    my $pod = package_pod($package);
    return $parser->parse_from_string($pod);
}

sub package_perldoc {
    my $package  = shift;
    my $sections = shift;
    require Pod::Perldoc;
    require File::Temp;
    File::Temp->VERSION(0.19);
    require File::Path;
    my $pod = package_pod( $package, $sections );
    my $tmpdir = File::Temp::tempdir( TMPDIR => 1, CLEANUP => 1 );

    # perldoc may try to drop privs and the dir will be
    # readable by current user only
    chmod oct(755), $tmpdir;
    my @path_parts = split /::/msx, $package;
    my $filename   = pop @path_parts;
    my $path       = File::Spec->catdir( $tmpdir, 'perl', @path_parts );
    File::Path::mkpath($path);
    my $out_file = File::Spec->catfile( $path, $filename );
    open my $out, '>', $out_file
        or WGDev::X::IO->throw('Unable to create temp file');
    print {$out} $pod;
    close $out or return q{};

    my $pid = fork;
    if ( !$pid ) {
        local @ARGV = ( '-w', 'section:3', '-F', $out_file );
        exit Pod::Perldoc->run;
    }
    waitpid $pid, 0;

    # error status of subprocess
    if ($?) {
        WGDev::X->throw('Error displaying help!');
    }
    return;
}

my %pod;

sub package_pod {
    my $package  = shift;
    my $sections = shift;
    my $raw_pod = $pod{$package};
    if ( !$raw_pod ) {
        ( my $file = $package . '.pm' ) =~ s{::}{/}msxg;
        require $file;
        my $fh = do {
            no strict 'refs';
            \*{$package . '::DATA'};
        };
        if ( eof $fh ) {
            open $fh, '<', $INC{$file}
                or WGDev::X::IO->throw;
        }
        $raw_pod = do { local $/; <$fh> };
        $pod{$package} = $raw_pod;
    }

    return $raw_pod
        if !$sections;

    open my $pod_in, '<', \$raw_pod
        or WGDev::X::IO->throw;
    my @sections = ref $sections ? @{$sections} : $sections;
    require Pod::Select;
    my $parser = Pod::Select->new;
    $parser->select(@sections);
    my $pod = q{};
    open my $pod_out, '>', \$pod
        or WGDev::X::IO->throw;
    $parser->parse_from_filehandle( $pod_in, $pod_out );
    close $pod_out
        or WGDev::X::IO->throw;
    close $pod_in
        or WGDev::X::IO->throw;
    return $pod;
}

1;

__END__

=head1 NAME

WGDev::Help - Generate help text for WGDev

=head1 SYNOPSIS

    use WGDev::Help;

    my $usage = WGDev::Help::package_usage( 'My::Class' );

=head1 DESCRIPTION

Reads help information from modules but filters to only pick relevant
sections when multiple POD documents exist in a single file.

=head1 SUBROUTINES

=head2 C<package_usage ( $package [, $verbosity] )>

Returns usage information for a package, using L<Pod::Usage>.  Can be used on
packages that have been combined into a single file.

=head2 C<package_perldoc ( $package [, $sections] )>

Displays documentation for a package using L<Pod::Perldoc>.  Can be used on
packages that have been combined into a single file.

=head3 C<$sections>

Passed on to L</package_pod> to limit the sections output.

=head2 C<package_pod ( $package [, $sections] )>

Filters out the POD for a specific package from the module file for the package.

=head3 C<$sections>

Limits sections to include based on L<Pod::Select/SECTION SPECIFICATIONS|Pod::Select's rules>.
Can be either a scalar value or an array reference.

=head1 AUTHOR

Graham Knop <haarg@haarg.org>

=head1 LICENSE

Copyright (c) 2009-2010, Graham Knop

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl 5.10.0. For more details, see the
full text of the licenses in the directory LICENSES.

=cut
