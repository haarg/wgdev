package WGDev::Command::User;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.2.0';

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

use WGDev::X ();

sub config_options {
    return qw(
        findByPassword=s
        findByDictionary=s
    );
}

sub process {
    my $self = shift;
    my $wgd  = $self->wgd;

    my $session = $wgd->session();

    if ( my $password = $self->option('findByPassword') ) {
        return $self->find_by_password($password);
    }

    if ( my $dictionary = $self->option('findByDictionary') ) {
        return $self->find_by_dictionary($dictionary);
    }
}

sub find_by_password {
    my $self     = shift;
    my $password = shift;
    my $session  = $self->wgd->session();

    require Digest::MD5;
    require Encode;
    my $hash = Digest::MD5::md5_base64( Encode::encode_utf8($password) );
    print "Password:\t$password\n";
    print "Hashes to:\t$hash\n";
    my @user_ids = $session->db->buildArray(
        'select userId from authentication where fieldName = ? and fieldData = ?',
        [ 'identifier', $hash ] );
    print "Matching users:\t";
    print @user_ids ? "\n" : "None\n";

    for my $user_id (@user_ids) {
        my $user = WebGUI::User->new( $session, $user_id );
        my $username = $user->username;
        print " * $user_id ($username)\n";
    }
    return;
}

sub find_by_dictionary {
    my $self    = shift;
    my $dict    = shift;
    my $session = $self->wgd->session();

    my @hashed_passwords
        = $session->db->buildArray(
        'select fieldData from authentication where fieldName = ?',
        ['identifier'] );
    my %hashed_passwords = map { $_ => 1 } @hashed_passwords;
    ##no critic (RequireBriefOpen)
    open my $d, '<', $dict
        or WGDev::X::IO::Read->throw(
        path    => $dict,
        message => 'Unable to open dictionary file'
        );
    while ( my $word = <$d> ) {
        chomp $word;
        my $hash = Digest::MD5::md5_base64( Encode::encode_utf8($word) );
        if ( $hashed_passwords{$hash} ) {
            print "\n*** HIT ***\n";
            $self->find_by_password($word);
        }
    }
    close $d
        or WGDev::X::IO::Read->throw(
        path    => $dict,
        message => 'Unable to open dictionary file'
        );
    return;
}

1;

__END__

=head1 NAME

WGDev::Command::User - Utilities for manipulating WebGUI Users

=head1 SYNOPSIS

    wgd user [--findByPassword <password>] [--findByDictionary <dictionary>]

=head1 DESCRIPTION

Utilities for manipulating WebGUI Users

=head1 OPTIONS

=over 8

=item C<--findByPassword>

Return a list of users that are using the given password (assumes
WebGUI authentication module).

=item C<--findByDictionary>

Use a dictionary file to do a brute-force search for users using
any password in the dictionary (assumes WebGUI authentication
module). For example, Linux distributions typically have a dictionary
file in C</usr/share/dict/> or C</var/lib/dict/>

=back

=head1 METHODS

=head2 find_by_password

Hashes the given password and sees if any user IDs in the C<authentication> table
match. This check will become less efficient once WebGUI implements password salting.

=head2 find_by_dictionary

Search through the given dictionary file, hashing words one by one and
checking them against all known hashed passwords.

Does not try to be efficient or clever - for common dictionary files it's
plenty fast enough.

=head1 AUTHOR

Patrick Donelan <pat@patspam.com>

=head1 LICENSE

Copyright (c) Patrick Donelan.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

