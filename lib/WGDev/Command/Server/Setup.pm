package WGDev::Command::Server::Setup;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.0.1';

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

use File::Spec ();

sub needs_config { return }

sub config_options {
    return qw(
        logfile
        spectrepid
    );
}

sub process {
    my $self = shift;
    require File::Path;
    require File::Copy;
    require Config::JSON;

    my $wgd  = $self->wgd;
    my $logfile = File::Spec->rel2abs($self->option('logfile') || 'webgui.log');
    my $logdir = File::Spec->catpath((File::Spec->splitpath($logfile))[0,1], '');
    File::Path::mkpath($logdir);
    open my $fh, '>', File::Spec->catfile($wgd->root, 'etc', 'log.conf');
    print {$fh} sprintf <<'END_LOGCONF', $logfile;
log4perl.logger = WARN, mainlog
log4perl.appender.mainlog = Log::Log4perl::Appender::File
log4perl.appender.mainlog.filename = %s
log4perl.appender.mainlog.layout = PatternLayout
log4perl.appender.mainlog.layout.ConversionPattern = %%d - %%p - %%c - %%M[%%L] - %m%n

END_LOGCONF
    close $fh;

    my $pidfile = File::Spec->rel2abs($self->option('spectrepid') || 'spectre.pid');
    my $piddir = File::Spec->catpath((File::Spec->splitpath($pidfile))[0,1], '');
    File::Path::mkpath($piddir);

    my $spectre_config_file = File::Spec->catfile($wgd->root, 'etc', 'spectre.conf');
    File::Copy::copy(
        File::Spec->catfile($wgd->root, 'etc', 'spectre.conf.original'),
        $spectre_config_file,
    );
    my $spectre_conf = Config::JSON->new($spectre_config_file);
    $spectre_conf->set(port => 30000 + int(rand(20000)));
    $spectre_conf->set(pidFile => $pidfile);

    return 1;
}

1;

__END__

=head1 NAME

WGDev::Command::Server::Setup - Sets up a WebGUI directory for use

=head1 SYNOPSIS

    wgd server-create [--logfile=<logfile>] [--spectrepid=<spectrepid>]

=head1 DESCRIPTION

Sets up a WebGUI directory for use.  Creates the needed spectre and
log configuration files.

=head1 OPTIONS

=over 8

=item C<--logfile=>

Specify the WebGUI log file to use.  If not specified, uses
F<webgui.log> in the current directory.  If the specified file is
in a non-existant directory, that directory is created.

=item C<--spectrepid=>

Specify the PID file to use for spectre.  If not specified, uses
F<spectre.pid> in the current directory.  If the specified file is
in a non-existant directory, that directory is created.

=back

=head1 AUTHOR

Graham Knop <haarg@haarg.org>

=head1 LICENSE

Copyright (c) 2009, Graham Knop

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl 5.10.0. For more details, see the
full text of the licenses in the directory LICENSES.

=cut

