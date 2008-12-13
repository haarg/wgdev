package WGDev::Command::Base::Verbosity;
use strict;
use warnings;

our $VERSION = '0.1.0';

use WGDev::Command::Base;
our @ISA = qw(WGDev::Command::Base);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{verbosity} = 1;
    return $self;
}

sub option_config {qw(
    verbose|v+
    quiet|q+
)}

sub parse_params {
    my $self = shift;
    my $result = $self->SUPER::parse_params(@_);
    $self->{verbosity} += ($self->option('verbose') || 0) - ($self->option('quiet') || 0);
    return $result;
}

sub verbosity {
    my $self = shift;
    if (@_) {
        return $self->{verbosity} = shift;
    }
    return $self->{verbosity};
}

sub report {
    my $self = shift;
    my $message = pop;
    my $verbose_limit = shift;
    $verbose_limit = 1
        if !defined $verbose_limit;
    return
        if $verbose_limit > $self->verbosity;
    print $message;
    return 1;
}

1;

__END__

