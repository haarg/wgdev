package WGDev::Command::Release;
use strict;
use warnings;

our $VERSION = '0.1.0';

use WGDev::Command::Base;
our @ISA = qw(WGDev::Command::Base);

use File::Spec;

sub process {
    my $self = shift;
    my $wgd = $self->wgd;
    my $summary = $self->get_summary;
    $self->post_advisory($summary);
    $self->post_freshmeat($summary);
    $self->post_sourceforge($summary);
}

sub post_advisory {
    my $self = shift;
    my $summary = shift;
    my $wgd = $self->wgd;
    require LWP::UserAgent;
    require URI;
    require HTML::Entities;
    my ($version, $status) = $wgd->version->module;
    my $content = "<p>" . HTML::Entities::encode($summary) . "</p>\n";

    $content .= "<h2>Gotchas:</h2>\n<ul>\n";
    for my $gotcha ( @{ $self->read_gotchas } ) {
        $content .= "<li><pre>" . HTML::Entities::encode($gotcha) . "</pre></li>\n";
    }
    $content .= "</ul>\n";

    $content .= "<h2>Changelog:</h2>\n<ul>";
    for my $change ( @{ $self->read_changelog } ) {
        $content .= "<li>" . HTML::Entities::encode($change) . "</li>\n";
    }
    my $submit = {
        func        => 'add',
        class       => 'WebGUI::Asset::Post::Thread',
        proceed     => 'showConfiguration',
        title       => "WebGUI $version ($status) Released" ,
        synopsis    => $summary,
        content     => $content,
        subscribe   => 0,
    };
    my $post_to = URI->new($wgd->my_config('advosory')->{url});
    my $ua = LWP::UserAgent->new;
    $ua->credentials($post_to->host_port, 'WebGUI',
        $wgd->my_config('advisory')->{username}, $wgd->my_config('advisory')->{password});
    my $response = $ua->post(
        $post_to->canonical,
        Content_Type    => 'form-data',
        Content         => $submit,
    );
    return $response->is_success;
}

sub post_freshmeat {
    my $self = shift;
    my $summary = shift;
    my $wgd = $self->wgd;
    require LWP::UserAgent;
    require URI;
    require HTML::Entities;
    my $version = '';
    my $submit = {
        version => '',
    };
}
sub post_sourceforge {
    require LWP;
    my $self = shift;
    my $summary = shift;
    my $wgd = $self->wgd;
}

sub read_changelog {
    my $self = shift;
    my $wgd = $self->wgd;
    my $changes = $self->{changes};
    return $changes
        if $changes;
    my $version = $wgd->version->module;
    my ($major_version) = split /\./, $version;
    my $change_file = File::Spec->catfile($wgd->root, 'docs', 'changelog', $major_version . '.x.x.txt');
    $changes = $self->{changes} = [];
    my $found;
    open my $fh, '<', $change_file;
    while (my $line = <$fh>) {
        $line =~ s/^\s+//;
        $line =~ s/\s+$//;
        if ($line eq $version) {
            $found = 1;
            next;
        }
        next
            unless $found;
        last
            if $line =~ /^\d+\.\d+\.\d+$/;
        if ($line =~ s/^[-*]\s+//) {
            push @$changes, $line;
        }
        elsif ($line) {
            $changes->[-1] .= " $line";
        }
    }
    close $fh;
    return $changes;
}

sub read_gotchas {
    my $self = shift;
    my $wgd = $self->{wgd};
    my $gotchas = $self->{gotchas};
    return $gotchas
        if $gotchas;
    my $version = $wgd->version->module;
    my $gotcha_file = File::Spec->catfile($wgd->root, 'docs', 'gotcha.txt');
    open my $fh, '<', $gotcha_file;
    $gotchas = $self->{gotchas} = [];
    my $found;
    my $header_length;
    while (my $line = <$fh>) {
        if ($line =~ /^\Q$version\E$/) {
            $found = 1;
            next;
        }
        next
            unless $found;
        next
            if $line =~ /^\s+$/;
        last
            if $line =~ /^\d+\.\d+\.\d+$/;
        next
            if $line =~ /^-+$/;
        if ($line =~ s/^(\s+[-*]\s+)//) {
            $header_length = length($1);
            push @$gotchas, $line;
        }
        elsif ($line) {
            $line = substr($line, $header_length);
            $gotchas->[-1] .= $line;
        }
    }
    s/\s+$//
        for @$gotchas;
    close $fh;
    return $gotchas;
}

sub get_summary {
    require File::Temp;
    my $self = shift;
    my $wgd = $self->{wgd};
    my $changes = $self->read_changelog;
    my $gotchas = $self->read_gotchas;
    my ($version, $status) = $wgd->version->module;
    my ($fh, $filename) = File::Temp::tempfile();
    my $info_file = File::Temp->new;
    print {$fh} <<END_TEXT;

# Enter a summary for this release
# Release $version - $status
#
# Gotchas:
END_TEXT
    for my $gotcha (@$gotchas) {
        my $gotcha_formatted = "#   - " . $gotcha;
        $gotcha_formatted =~ s/\n/\n#     /g;
        print {$fh} $gotcha_formatted, "\n";
    }
    print {$fh} <<END_TEXT;
#
# Changes:
END_TEXT
    for my $change (@$changes) {
        print {$fh} "#   - $change\n";
    }
    close $fh;

    my $editor = $ENV{EDITOR} || 'vi';
    system "$editor $filename";

    open $fh, '<', $filename;
    my $summary = '';
    while (my $line = <$fh>) {
        next
            if $line =~ /^#/;
        $summary .= $line;
    }
    return
        if $summary =~ /^\s+$/;
    return $summary;
}

1;


