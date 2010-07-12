package WGDev::Command::Self::Upgrade;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.0.1';

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }
use WGDev::X;
use WGDev::Command;
use File::Temp ();

sub config_options { () }

sub process {
    my $self = shift;
    my $file = $0;
    if (! -w $file) {
        WGDev::X::IO::Write->throw( path => $file );
    }
    my $our_version = WGDev::Command->VERSION;
    print "Current version: $our_version\n";
    require LWP::UserAgent;
    my $ua = LWP::UserAgent->new;
    my $res = $ua->get('http://haarg.org/wgd');
    if (! $res->is_success) {
        WGDev::X->throw('Unable to download new version');
    }
    my $content = $res->decoded_content;
    my $new_version = do {
        my $temp_script = File::Temp->new;
        $temp_script->autoflush(1);
        print { $temp_script } $content;
        open my $fh, '-|', $^X, '--', $temp_script->filename, '-V';
        my $output = do { local $/; <$fh> };
        close $fh;
        my ($script_version) = ($output =~ /(\d[\d.]+)/);
        $script_version;
    };
    print "New version $new_version\n";
    if ($our_version eq $new_version) {
        print "Already up to date.\n";
        return 1;
    }
    print "Upgrading.\n";
    open my $fh, '>', $file;
    print { $fh } $content;
    close $fh;
    exec $^X, $file, '-V';
}

1;

__DATA__

=head1 NAME

WGDev::Command::Self::Upgrade - Upgrade WGDev script

=head1 SYNOPSIS

    wgd upgrade

=head1 DESCRIPTION

Upgrades the WGDev script.

=head1 AUTHOR

Graham Knop <haarg@haarg.org>

=head1 LICENSE

Copyright (c) 2009-2010, Graham Knop

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl 5.10.0. For more details, see the
full text of the licenses in the directory LICENSES.

=cut

