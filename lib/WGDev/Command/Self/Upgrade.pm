package WGDev::Command::Self::Upgrade;
# ABSTRACT: Upgrade WGDev script
use strict;
use warnings;
use 5.008008;

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }
use WGDev::X;
use WGDev::Command;

sub needs_root { return }
sub config_options { () }

sub is_runnable {
    # use the presence of fatpacker to detect single script install
    # this command is not meant for upgrading module install
    return $App::WGDev::PACKED;
}

sub process {
    my $self = shift;
    my $file = $0;
    require File::Temp;
    require LWP::UserAgent;
    if (! -w $file) {
        WGDev::X::IO::Write->throw( path => $file );
    }
    my $our_version = WGDev::Command->VERSION;
    print "Current version: $our_version\n";
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
        open my $fh, q{-|}, $^X, q{--}, $temp_script->filename, '-V'
            or WGDev::X::IO->throw;
        my $output = do { local $/; <$fh> };
        close $fh
            or WGDev::X::IO->throw;
        my ($script_version) = ($output =~ /(\d[\d.]+)/msx);
        $script_version;
    };
    print "New version: $new_version\n";
    if ($our_version eq $new_version) {
        print "Already up to date.\n";
        return 1;
    }
    print "Upgrading.\n";
    open my $fh, '>', $file
        or WGDev::X::IO->throw;
    print { $fh } $content;
    close $fh
        or WGDev::X::IO->throw;
    exec $^X, $file, '-V';
}

1;

=head1 SYNOPSIS

    wgd self-upgrade

=head1 DESCRIPTION

Upgrades the WGDev script.

=cut

