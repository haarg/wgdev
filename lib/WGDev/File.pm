package WGDev::File;
# ABSTRACT: File utility functions
use strict;
use warnings;
use 5.008008;

use constant STAT_FILESIZE => 7;

use WGDev::X;
use File::Spec ();

sub sync_dirs {
    my $class = shift;
    my $from_dir = shift;
    my $to_dir = shift;

    require File::Copy;
    require File::Path;

    File::Path::mkpath($to_dir);

    # recurse through destination and delete files that don't exist in source
    $class->matched_find($to_dir, $from_dir, sub {
        my ($to_path, $from_path) = @_;
        return
            if -e $from_path;
        if ( -d $to_path ) {
            File::Path::rmtree($to_path);
        }
        else {
            unlink $to_path;
        }
    });

    # copy files that don't exist or are different
    $class->matched_find($from_dir, $to_dir, sub {
        my ($from_path, $to_path) = @_;
        return
            if -d $from_path;
        my $from_size = ( stat _ )[STAT_FILESIZE];
        return
            if -e $to_path && ( stat _ )[STAT_FILESIZE] == $from_size;

        my $to_parent = File::Spec->catpath(
            ( File::Spec->splitpath($to_path) )[ 0, 1 ] );
        File::Path::mkpath($to_parent);
        File::Copy::copy( $from_path, $to_path );
    });
}

sub matched_find {
    my $class = shift;
    my $from_dir = shift;
    my $to_dir = shift;
    my $cb = shift;

    require File::Find;

    my $matched_cb = sub {
        no warnings 'once';
        my $from_path = $File::Find::name;
        my ( undef, undef, $filename ) = File::Spec->splitpath($from_path);
        if ( $filename eq '.svn' || $filename eq 'temp' ) {
            $File::Find::prune = 1;
            return;
        }
        my $rel_path = File::Spec->abs2rel( $from_path, $from_dir );
        my $to_path = File::Spec->rel2abs( $rel_path, $to_dir );
        $cb->($from_path, $to_path);
    };
    File::Find::find( { no_chdir => 1, wanted => $matched_cb }, $from_dir );
}

1;

=head1 SYNOPSIS

    WGDev::File->sync_dirs($from, $to);

=head1 DESCRIPTION

Performs common actions on files.

=method C<sync_dirs ( $from_dir, $to_dir )>

Syncronises two directories.  Deletes any additional files in the
destination that don't exist in the source.  Checks for file
differences by size before copying.

=method C<matched_find ( $from_dir, $to_dir, $callback )>

Recurses through C<$from_dir>, calling C<$callback> for each file
or directory found.  The callback is passed two parameters, the
file found, and a filename relative to C<$to_dir> based on the found
file's path relative to C<$from_dir>.

=cut

