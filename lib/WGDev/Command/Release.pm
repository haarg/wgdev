package WGDev::Command::Release;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.1.0';

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

use File::Spec;

sub process {
    my $self = shift;
    my $wgd = $self->wgd;
    my $summary = $self->get_summary;
#    $self->upload_sourceforge($summary);
#    $self->post_advisory($summary);
#    $self->post_freshmeat($summary);
    $self->post_sourceforge($summary);
    return 1;
}

sub post_advisory {
    my $self = shift;
    my $summary = shift;
    my $wgd = $self->wgd;
    require LWP::UserAgent;
    require URI;
    require HTML::Entities;
    my ($version, $status) = $wgd->version->module;
    my $content = '<p>' . HTML::Entities::encode($summary) . "</p>\n";

    $content .= "<h2>Gotchas:</h2>\n<ul>\n";
    for my $gotcha ( @{ $self->read_gotchas } ) {
        $content .= '<li><pre>' . HTML::Entities::encode($gotcha) . "</pre></li>\n";
    }
    $content .= "</ul>\n";

    $content .= "<h2>Changelog:</h2>\n<ul>";
    for my $change ( @{ $self->read_changelog } ) {
        $content .= '<li>' . HTML::Entities::encode($change) . "</li>\n";
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
    my $post_to = URI->new($wgd->my_config('advisory.url'));
    my $ua = LWP::UserAgent->new;
    $ua->credentials($post_to->host_port, 'WebGUI',
        $wgd->my_config('advisory.username'), $wgd->my_config('advisory.password'));
    my $response = $ua->post(
        $post_to->canonical,
        Content_Type => 'form-data',
        Content      => $submit,
    );
    return $response->is_success;
}

sub post_freshmeat {
    my $self = shift;
    my $summary = shift;
    require URI;
    require LWP::UserAgent;
    require HTML::Entities;
    my $wgd = $self->wgd;
    my ($version, $status) = $wgd->version->module;
    my $submit = {
        version => '',
    };
    return 1;
}

sub upload_sourceforge {
    my $self = shift;
    require Net::OpenSSH;
    my $wgd = $self->wgd;
    my ($version, $status) = $wgd->version->module;
    my $ssh = Net::OpenSSH->new('frs.sourceforge.net');
    if ($ssh->error) {
        die 'Error connecting to SourceForge: ' . $ssh->error;
    }
    my $file = File::Spec->catfile($wgd->root, "webgui-$version-$status.tar.gz");
    $ssh->rsync_put($file, 'uploads');
    if ($ssh->error) {
        die 'Error uploading to SourceForge: ' . $ssh->error;
    }
    return 1;
}

sub post_sourceforge {
    my $self = shift;
    my $summary = shift;
    my $wgd = $self->wgd;

    my ($version, $status) = $wgd->version->module;
    my $release_date = POSIX::strftime('%F', localtime);
    my $filename = "webgui-$version-$status.tar.gz";

    require URI;
    require URI::QueryParam;
    require LWP::UserAgent;
    require POSIX;
    my $ua = LWP::UserAgent->new;
    $ua->cookie_jar( {} );

    # first, log in
    my $username = $wgd->my_config('sourceforge.username');
    my $password = $wgd->my_config('sourceforge.password');

    my $group_id = $wgd->my_config('sourceforge.release_group');
    my $package_id = $wgd->my_config('sourceforge.release_package');
    my $response = $ua->post('https://sourceforge.net/account/login.php', Content => {
        form_loginname  => $username,
        form_pw         => $password,
        form_rememberme => 'yes',
        form_securemode => 'yes',
        login           => 'Log in',
        return_to       => q{},
        ssl_status      => q{},
    });
    # will always redirect on success
    if (! $response->header('Location')) {
        die "Unable to log in to SourceForge.\n";
    }

    # next, create release
    $response = $ua->post(
        'https://sourceforge.net/project/admin/newrelease.php',
        Content => {
            group_id     => $group_id,
            package_id   => $release_id,
            release_name => "$version ($status)",
            newrelease   => 'yes',
            submit       => 'Create This Release',
        },
    );
    if (! $response->header('Location')) {
        die "Unable to create new release.\n";
    }
    my $release_url = URI->new($response->header('Location'));
    my $release_id = $release_url->query_param('release_id');

    my $notes = $summary;
    my @gotchas = @{ $self->read_gotchas };
    if (@gotchas) {
        $notes = "\n\nGotchas:\n";
        for my $gotcha (@gotchas) {
            $notes .= " * $gotcha\n";
        }
    }
    my $changelog = q{};
    for my $change ( @{ $self->read_changelog } ) {
        $changelog .= " - $change\n";
    }

    $response = $ua->post(
        'https://sourceforge.net/project/admin/editreleases.php',
        Content_Type => 'form-data',
        Content => {
            group_id         => $group_id,
            package_id       => $package_id,
            release_id       => $release_id,
            step1            => 1,
            release_date     => $release_date,
            release_name     => "$release ($status)",
            status_id        => 1,
            new_package_id   => $release_id,
            release_notes    => $notes,
            release_changes  => $changelog,
            submit           => 'Submit/Refresh',
        },
    );

    if ( $response->is_error ) {
        die "Unable to set release information\n";
    }

    $response = $ua->post(
        'https://sourceforge.net/project/admin/editreleases.php',
        Content => {
            group_id      => $group_id,
            package_id    => $package_id,
            release_id    => $release_id,
            step2         => 1,
            'file_list[]' => $filename,
            submit        => 'Add Files and/or Refresh View',
        },
    );

    if ( $response->is_error ) {
        die "Unable to attach file\n";
    }

    if ( ! $response->content =~ m{
        <input \s+
        name="file_id" \s+
        value="(\d+)"
        .*?
        >$filename<}msx ) {
    }
    my $file_id = $1;

    $response = $ua->post(
        'https://sourceforge.net/project/admin/editreleases.php',
        Content => {
            group_id       => $group_id,
            release_id     => $release_id,
            package_id     => $package_id,
            file_id        => $file_id,
            step3          => 1,
            processor_id   => 8500,
            type_id        => 5002,
            new_release_id => $release_id,
            release_time   => $release_date,
            submit         => 'Update/Refresh',
        },
    );
    if ( $response->is_error ) {
        die "Unable to set file information\n";
    }

    $response = $ua->post(
        'https://sourceforge.net/project/admin/editreleases.php',
        Content => {
            group_id       => $group_id,
            release_id     => $release_id,
            package_id     => $package_id,
            file_id        => $file_id,
            step4          => 'Email Release',
            sure           => 1,
        },
    );

    return 1;
}

sub read_changelog {
    my $self = shift;
    my $wgd = $self->wgd;
    my $changes = $self->{changes};
    return $changes
        if $changes;
    my $version = $wgd->version->module;
    my ($major_version) = split /[.]/msx, $version;
    my $change_file = File::Spec->catfile($wgd->root, 'docs', 'changelog', $major_version . '.x.x.txt');
    $changes = $self->{changes} = [];
    my $found;
    open my $fh, q{<}, $change_file;
    while (my $line = <$fh>) {
        $line =~ s/^\s+//msx;
        $line =~ s/\s+$//msx;
        if ($line eq $version) {
            $found = 1;
            next;
        }
        next
            if ! $found;
        last
            if $line =~ /^\d+[.]\d+[.]\d+$/msx;
        if ($line =~ s/^[-*]\s+//msx) {
            push @{$changes}, $line;
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
    open my $fh, q{<}, $gotcha_file;
    $gotchas = $self->{gotchas} = [];
    my $found;
    my $header_length;
    while (my $line = <$fh>) {
        if ($line =~ /^\Q$version\E$/msx) {
            $found = 1;
            next;
        }
        next
            if ! $found;
        next
            if $line =~ /^\s+$/msx;
        last
            if $line =~ /^\d+\.\d+\.\d+$/msx;
        next
            if $line =~ /^-+$/msx;
        if ($line =~ s/^(\s+[-*]\s+)//msx) {
            $header_length = length $1;
            push @{$gotchas}, $line;
        }
        elsif ($line) {
            $line = substr $line, $header_length;
            $gotchas->[-1] .= $line;
        }
    }
    s/\s+$//msx
        for @{$gotchas};
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
    print {$fh} <<"END_TEXT";

# Enter a summary for this release
# Release $version - $status
#
# Gotchas:
END_TEXT
    for my $gotcha (@{$gotchas}) {
        my $gotcha_formatted = '#   - ' . $gotcha;
        $gotcha_formatted =~ s/\n/\n#     /msxg;
        print {$fh} $gotcha_formatted, "\n";
    }
    print {$fh} <<"END_TEXT";
#
# Changes:
END_TEXT
    for my $change (@{$changes}) {
        print {$fh} "#   - $change\n";
    }
    close $fh;

    my $editor = $ENV{EDITOR} || 'vi';
    system "$editor $filename";

    open $fh, '<', $filename;
    my $summary = q{};
    while (my $line = <$fh>) {
        next
            if $line =~ /^#/msx;
        $summary .= $line;
    }
    return
        if $summary =~ /^\s+$/msx;
    return $summary;
}

1;

