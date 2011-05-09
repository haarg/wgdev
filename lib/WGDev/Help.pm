package WGDev::Help;
# ABSTRACT: Generate help text for WGDev
use strict;
use warnings;
use 5.008008;

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

    my $pid = fork;
    if ( !$pid ) {
        # perldoc will try to drop privs anyway, so do it ourselves so the
        # temp file has the correct owner
        Pod::Perldoc->new->drop_privs_maybe;

        # Make a path that plays nice with Perldoc internals.  Will format nicer.
        my $tmpdir = File::Temp->newdir( TMPDIR => 1 );

        # construct a path that Perldoc will interperet as a package name
        my @path_parts = split /::/msx, $package;
        my $filename   = pop @path_parts;
        my $path       = File::Spec->catdir( $tmpdir->dirname, 'perl', @path_parts );
        File::Path::mkpath($path);
        my $out_file = File::Spec->catfile( $path, $filename );

        open my $out, '>', $out_file
            or WGDev::X::IO->throw('Unable to create temp file');
        print {$out} $pod;
        close $out or return q{};

        # perldoc doesn't understand darwin's stty output.
        # copy and paste but it seems to work
        my @extra_args;
        if ($^O eq 'darwin') {
            if (`stty -a` =~ /(\d+) columns;/) {
                my $cols = $1;
                my $c = $cols * 39 / 40;
                $cols = $c > $cols - 2 ? $c : $cols -2;
                if ( $cols > 80 ) {
                    push @extra_args, '-n', 'nroff -rLL=' . (int $c) . 'n';
                }
            }
        }

        local @ARGV = ( @extra_args, '-w', 'section:3', '-F', $out_file );
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

=head1 SYNOPSIS

    use WGDev::Help;

    my $usage = WGDev::Help::package_usage( 'My::Class' );

=head1 DESCRIPTION

Reads help information from modules but filters to only pick relevant
sections when multiple POD documents exist in a single file.

=func C<package_usage ( $package [, $verbosity] )>

Returns usage information for a package, using L<Pod::Usage>.  Can be used on
packages that have been combined into a single file.

=func C<package_perldoc ( $package [, $sections] )>

Displays documentation for a package using L<Pod::Perldoc>.  Can be used on
packages that have been combined into a single file.

=for :list
= C<$sections>
Passed on to L</package_pod> to limit the sections output.

=func C<package_pod ( $package [, $sections] )>

Filters out the POD for a specific package from the module file for the package.

=for :list
= C<$sections>

Limits sections to include based on L<Pod::Select/SECTION SPECIFICATIONS|Pod::Select's rules>.
Can be either a scalar value or an array reference.

=cut
