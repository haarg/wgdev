package WGDev::Command::Config;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.1.0';

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

use WGDev          ();
use WGDev::Command ();

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
        warn $usage;    ##no critic (RequireCarping)
        return;
    }

    my ( $config_param, $value ) = @args;
    my @config_path = split /[.]/msx, $config_param;

    if ( defined $value ) {
        if ( $value =~ s/\A@//msx ) {
            my $file = $value;
            my $fh;
            ##no critic (RequireBriefOpen)
            if ( $file eq q{-} ) {
                ##no critic (ProhibitTwoArgOpen)
                open $fh, q{-} or die "Unable to read STDIN: $!\n";
            }
            else {
                open $fh, '<', $file
                    or die "Unable to read from $file\: $!\n";
            }
            $value = do { local $/ = undef; <$fh> };
            close $fh or die "Unable to read from $file\: $!\n";
        }
        if ( $self->option('struct') ) {
            $value =~ s/\A \s* ( [[{] ) /--- $1/msx;
            $value .= "\n";
            eval {
                $value = WGDev::yaml_decode($value);
                1;
            } or die "Invalid or unsupported format.\n";
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

__END__

=head1 NAME

WGDev::Command::Config - Report WGDev configuration parameters

=head1 SYNOPSIS

    wgd config [--struct] <config path> [<value>]

=head1 DESCRIPTION

Reports WGDev configuration parameters.

=head1 OPTIONS

=over 8

=item C<--struct> C<-s>

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

Graham Knop <graham@plainblack.com>

=head1 LICENSE

Copyright (c) Graham Knop.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

