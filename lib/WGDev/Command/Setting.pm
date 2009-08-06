package WGDev::Command::Setting;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.2.0';

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

sub config_options {
    return qw();
}

sub process {
    my $self    = shift;
    my $wgd     = $self->wgd;
    my $session = $wgd->session;
    foreach my $setting ( $self->arguments ) {
        print sprintf "%s:%s\n", $setting, $session->setting->get($setting);
    }

    return 1;
}

1;

__END__

=head1 NAME

WGDev::Command::Setting - Returns WebGUI settings from the database.

=head1 SYNOPSIS

    wgd setting <setting> [<setting> ...]

=head1 DESCRIPTION

Prints settings from the WebGUI settings table.  This is handy for doing quick lookups,
or for using as part of other C<wgd> commands.

=head1 OPTIONS

=over 8

=item C<< <setting> >>

Displays the value of this setting.

=back

=head1 METHODS

No methods

=head1 AUTHOR

Colin Kuskie <colink@perldreamer.com>

=head1 LICENSE

Copyright (c) Graham Knop.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

