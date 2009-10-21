package WGDev::Command::Group;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.2.0';

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

use WGDev::X ();
use Carp;

sub config_options {
    return qw(
        list|l
        format|f=s
        long
        hidden
    );
}

sub process {
    my $self = shift;
    my $wgd  = $self->wgd;

    my $session = $wgd->session();

    if ( $self->option('list') ) {
        my $format = $self->option('format');
        if ( $self->option('long') ) {
            $format = 'Name: %groupName% %%n Id: %groupId% %%n Description: %description% %%n';
        }
        elsif ( !$format ) {
            $format = '%groupName%';
        }
        my $showInForms = $self->option('hidden');
        my $groupIds = $session->db->buildArrayRef('select groupId from groups order by groupName');
        for my $groupId ( @$groupIds ) {
            my $group = WebGUI::Group->new($session, $groupId);
            if (!$group) {
                carp "Unable to instantiate group via groupId: $groupId";
                next;
            }
            next if !$showInForms && !$group->showInForms;
            
            my $output = $self->format_output( $format, $group );
            print $output . "\n";
        }
    }
}

sub format_output {
    my ( $self, $format, $group ) = @_;
    $format =~ s/%%n/\n/g;
    {
        no warnings 'uninitialized';
        $format =~ s{% (?: (\w+) (?: :(-?\d+) )? )? %}{
            my $replace;
            if ($1) {
                $replace = $group->get($1);
                if ($2) {
                    $replace = sprintf('%*2$s', $replace, $2);
                }
            }
            else {
                $replace = '%';
            }
            $replace;
        }msxeg;
    }
    return $format;
}

1;

__END__

=head1 NAME

WGDev::Command::Group - Utilities for manipulating WebGUI Groups

=head1 SYNOPSIS

    wgd group [--list [--long] [--hidden]]

=head1 DESCRIPTION

Utilities for manipulating WebGUI Groups

=head1 OPTIONS

=over 8

=item C<-l> C<--list>

List groups. This is currently the only supported action.

=item C<--long>

Use long list format, which includes group name, ID, and description.

=item C<-f> C<--format=>

Use arbitrary formatting.  Format looks like C<%description:30%>, where 'C<description>' is
the field to display, and 30 is the length to left pad/cut to.  Negative
lengths can be specified for right padding.  Percent signs can be included by
using C<%%>. Newlines can be included by using C<%%n>

=item C<--hidden>

Include groups that are normally hidden from WebGUI forms.

=back

=head1 METHODS

=head2 C<format_output ( $format, $group )>

Returns the formatted information about a group.  C<$format> is
the format to output as specified in the L<format option|/-f>.

=head1 AUTHOR

Patrick Donelan <pat@patspam.com>

=head1 LICENSE

Copyright (c) Patrick Donelan.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

