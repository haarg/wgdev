package WGDev::Command::Run;
use strict;
use warnings;

our $VERSION = '0.0.1';

use WGDev::Command::Base;
our @ISA = qw(WGDev::Command::Base);

sub process {
    my $self = shift;
    exec $self->arguments;
}

sub parse_params {
    my $self = shift;
    @{ $self->{arguments} } = @_;
    return 1;
}

1;

__END__

=head1 NAME

WGDev::Command::Run - Does things

=cut

