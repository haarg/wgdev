package WGDev::Command::Config;
use strict;
use warnings;
use 5.008008;

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

use WGDev          ();
use WGDev::X       ();
use WGDev::Command ();

sub needs_root {
    return;
}

sub config_options {
    return qw(
        struct|s
    );
}

sub config_parse_options { return qw(gnu_getopt pass_through) }

sub process {
    my $self = shift;
    my $wgd  = $self->wgd;
    my @args = $self->arguments;

    if ( !@args ) {
        my $usage = $self->usage(0);
        warn $usage;
        return;
    }

    my ( $config_param, $value ) = @args;
    my @config_path = split /[.]/msx, $config_param;

    if ( defined $value ) {
        if ( $value =~ s/\A@//msx ) {
            my $file = $value;
            my $fh;
            if ( $file eq q{-} ) {
                open $fh, '<&=', \*STDIN
                    or WGDev::X::IO::Read->throw;
            }
            else {
                open $fh, '<', $file
                    or WGDev::X::IO::Read->throw( path => $file );
            }
            $value = do { local $/; <$fh> };
            close $fh
                or WGDev::X::IO::Read->throw( path => $file );
        }
        if ( $self->option('struct') ) {
            $value =~ s/\A \s* ( [[{] ) /--- $1/msx;
            $value .= "\n";
            eval {
                $value = WGDev::yaml_decode($value);
                1;
            } or WGDev::X->throw('Invalid or unsupported format.');
        }
    }
    my $param
        = $wgd->wgd_config( \@config_path, defined $value ? $value : () );
    if ( defined $value && defined $param ) {
        $wgd->write_wgd_config;
        return 1;
    }
    if ( ref $param ) {
        $param = WGDev::yaml_encode($param);
        $param =~ s/\A---(?:\Q {}\E)?\n?//msx;
    }
    elsif ( !defined $param ) {
        return 0;
    }
    $param =~ s/\n?\z/\n/msx;
    print $param;
    return 1;
}

1;

__DATA__

=head1 NAME

WGDev::Command::Config - Report or set WGDev configuration parameters

=head1 SYNOPSIS

    wgd config [--struct] <config path> [<value>]

=head1 DESCRIPTION

Report or set WGDev configuration parameters.

=head1 OPTIONS

=over 8

=item C<-s> C<--struct>

When setting a config value, specifies that the value should be treated as a
data structure formatted as YAML or JSON.

=item C<< <config path> >>

Path of the the config variable to retrieve.  Sub-level options are specified
as a period separated list of keys.  Complex options will be returned formatted
as YAML.

=item C<< <value> >>

The value to set the config option to.

=back

=head1 CONFIGURATION

The WGDev config file is a JSON formatted file existing as either
F</etc/wgdevcfg> or F<.wgdevcfg> in the current user's home directory.

A simple config file looks like:

 {
    "command" : {
       "webgui_root" : "/data/WebGUI",
       "webgui_config" : "dev.localhost.localdomain.conf"
    }
 }

=head1 AUTHOR

Graham Knop <haarg@haarg.org>

=head1 LICENSE

Copyright (c) 2009-2010, Graham Knop

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl 5.10.0. For more details, see the
full text of the licenses in the directory LICENSES.

=cut

