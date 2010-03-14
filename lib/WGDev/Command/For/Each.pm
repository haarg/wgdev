package WGDev::Command::For::Each;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.0.2';

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

sub needs_config {
    return;
}

sub needs_root {
    return 1;
}

sub config_options {
    return (
        shift->SUPER::config_options, qw(
            exec:s
            print0
            force|f
            ) );
}

sub process {
    my $self = shift;

    my $do;
    if ( $self->option('exec') ) {
        $do = sub {
            $_[0]->set_environment;
            my $return = ( system $self->option('exec') ) ? 0 : 1;
            $_[0]->reset_environment;
            return $return;
        };
    }
    elsif ( $self->option('print0') ) {
        $do = sub {
            print $_[0]->config_file . "\0";
        };
    }
    else {
        $do = sub {
            print $_[0]->config_file . "\n";
        };
    }

    my $root = $self->wgd->root;
    for my $config ( $self->wgd->list_site_configs ) {
        my $wgd = WGDev->new( $root, $config );
        if ( !eval { $do->($wgd) } && !$self->option('force') ) {
            WGDev::X->throw( 'Error processing ' . $config );
        }
    }

    return 1;
}

1;

__END__

=head1 NAME

WGDev::Command::For::Each - Run command for each available config file

=head1 SYNOPSIS

    wgd for-each [ --print0 | --exec=command ] [ -f ]

=head1 DESCRIPTION

Runs a command for each available WebGUI config file.  By default,
the names of the config files will be output.

=head1 OPTIONS

=over 8

=item C<-f> C<--force>

Continue processing config files if there is an error

=item C<--print0>

Prints the config file names followed by an ASCII NUL character
instead of a carriage return.

=item C<--exec=>

Runs the given command using the shell for each config file.  The
WEBGUI_ROOT and WEBGUI_CONFIG environment variables will be set
while this command is run, so wgd can be run as a bare command.

=back

=head1 AUTHOR

Graham Knop <haarg@haarg.org>

=head1 LICENSE

Copyright (c) 2010, Graham Knop

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl 5.10.0. For more details, see the
full text of the licenses in the directory LICENSES.

=cut

