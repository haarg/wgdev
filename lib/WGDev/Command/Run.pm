package WGDev::Command::Run;
# ABSTRACT: Run arbitrary shell command
use strict;
use warnings;
use 5.008008;

use parent qw(WGDev::Command::Base);

sub process {
    my $self = shift;
    $self->wgd->set_environment;
    my @arguments = $self->arguments;
    my $command   = shift @arguments;
    my $result    = system {$command} $command, @arguments;
    return $result ? 0 : 1;
}

sub parse_params {
    my ( $self, @args ) = @_;
    $self->arguments( \@args );
    return 1;
}

1;

=head1 SYNOPSIS

    wgd run <command>

=head1 DESCRIPTION

Runs an arbitrary command, but sets the C<WEBGUI_CONFIG>, C<WEBGUI_ROOT>, and
C<PERL5LIB> environment variables first.

=head1 OPTIONS

Has no options of its own.  All options are passed on to specified command.

=cut

