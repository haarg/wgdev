package WGDev::Command::Example;
# ABSTRACT: Example WGDev Command
use strict;
use warnings;
use 5.008008;

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

sub config_options {
    return qw(
        all|A
    );
}

sub process {
    my $self = shift;
    my $wgd  = $self->wgd;
    if ( $self->option('all') ) {
        print "Doing everything.\n";
    }
    else {
        print "Doing something.\n";
    }
    return 1;
}

1;

=head1 SYNOPSIS

    wgd example [-A]

=head1 DESCRIPTION

This is a sample command.

=head1 OPTIONS

=over 8

=item C<-A> C<--all>

Does everything.

=back

=cut

