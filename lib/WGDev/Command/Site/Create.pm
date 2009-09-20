package WGDev::Command::Site::Create;
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
        uploads=s
    );
}

sub process {
    my $self = shift;
    require DBI;
    require Config::JSON;
    require File::Copy;
    require File::Path;

    my $wgd  = $self->wgd;

    my $mysql_admin = $wgd->wgd_config('mysql.admin');
    my $dbh = DBI->connect($mysql_admin->{dsn}, $mysql_admin->{user}, $mysql_admin->{password});

    my $spectre_port = Config::JSON->new(File::Spec->catfile($wgd->root, 'etc', 'spectre.conf'))->get('port');

    for my $site ($self->arguments) {
        my $uploads_path = $self->option('uploads');
        $uploads_path =~ s/%sitename%/$site/;
        $uploads_path = File::Spec->rel2abs($uploads_path);
        File::Path::mkpath($uploads_path);

        my $database = "webgui_${site}_" . $self->_random_string(10);
        my $dbuser = $database;
        my $dbpass = $self->_random_string(20, ['A'..'Z', 'a'..'z', 0..9]);

        my $quoted_db = $dbh->quote_identifier($database);

        $dbh->do(sprintf 'CREATE DATABASE %s', $quoted_db);
        $dbh->do(sprintf(q{GRANT ALL ON %s.* TO ?@? IDENTIFIED BY ?}, $quoted_db), $dbuser, 'localhost', $dbpass);

        my $config_file = File::Spec->catfile($wgd->root, 'etc', "$site.conf");
        File::Copy::copy(
            File::Spec->catfile($wgd->root, 'etc', 'WebGUI.conf.original'),
            $config_file,
        );

        my $config = Config::JSON->create($config_file);
        $config->set('dsn', 'dbi:mysql:' . $database);
        $config->set('dbuser', $dbuser);
        $config->set('dbpass', $dbpass);
        $config->set('uploadsPath', $uploads_path);
        $config->set('extrasPath', File::Spec->catdir($wgd->root, 'www', 'extras'));
        $config->set('spectrePort', $spectre_port);
        $config->set('sitename', [$site]);
        $config->set('cacheType', 'WebGUI::Cache::Database');
    }
    return 1;
}

sub _random_string {
    my $class = shift;
    my $length = shift;
    my $dict = shift || ['a'..'z'];

    my $string = '';
    for (1..$length) {
        $string .= $dict->[int(rand(scalar @{$dict}))];
    }
    return $string;
}

1;

__END__

=head1 NAME

WGDev::Command::Site::Create - Creates a new site

=head1 SYNOPSIS

    wgd site-create <sitename> [<sitename ...]

=head1 DESCRIPTION

Creates a new site.

=head1 OPTIONS

=over 8

=back

=head1 AUTHOR

Graham Knop <haarg@haarg.org>

=head1 LICENSE

Copyright (c) 2009, Graham Knop

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl 5.10.0. For more details, see the
full text of the licenses in the directory LICENSES.

=cut

