package WGDev::Command::Site::Remove;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.0.1';

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

use File::Spec ();

sub config_options {
    return qw(
    );
}

sub process {
    my $self = shift;
    require Config::JSON;
    my $wgd  = $self->wgd;

    my $mysql_admin = $wgd->wgd_config('mysql.admin');
    my $dbh = DBI->connect($mysql_admin->{dsn}, $mysql_admin->{user}, $mysql_admin->{password});

    my $uploads_path = $wgd->config->get('uploadsPath');
    my $database = $wgd->db->name;
    my $user = $wgd->db->user;

    File::Path::rmtree($uploads_path);
    $dbh->do(sprintf 'DROP DATABASE %s', $dbh->quote_identifier($database));
    $dbh->do('DROP USER ?@?', {}, $user, 'localhost');

    unlink $wgd->config_file;

    return 1;
}

1;

__END__

=head1 NAME

WGDev::Command::Site::Remove - Removes a site

=head1 SYNOPSIS

    wgd site-remove

=head1 DESCRIPTION

Removes a site

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

