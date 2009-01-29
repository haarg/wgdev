package WGDev::Command::Base;
use strict;
use warnings;

our $VERSION = '0.0.1';

sub is_runnable {
    my $class = shift;
    return $class->can('process');
}

sub new {
    my $class = shift;
    my $wgd = shift;
    my $self = bless {
        wgd         => $wgd,
        options     => {},
        arguments   => [],
    }, $class;
    return $self
}

sub wgd { $_[0]->{wgd} }

sub parse_params {
    require Getopt::Long;
    my $self = shift;
    local @ARGV = @_;
    my %parsed;
    Getopt::Long::Configure('default', $self->option_parse_config);
    my $result = Getopt::Long::GetOptions($self->{options}, $self->option_config);
    @{ $self->{arguments} } = @ARGV;
    return $result;
}

sub option_parse_config { qw(gnu_getopt) };
sub option_config {}
sub option {
    my $self = shift;
    my $option = shift || return;
    if (@_) {
        return $self->{options}{$option} = shift;
    }
    return $self->{options}{$option};
}
sub option_default {
    my $self = shift;
    my $option = shift || return;
    if (!defined $self->option($option)) {
        return $self->option($option, @_);
    }
    return;
}

sub arguments {
    return @{ $_[0]->{arguments} };
}

sub run {
    my $self = shift;
    my @params = (@_ == 1 && ref $_[0] eq 'ARRAY') ? @{ +shift } : @_;
    local $| = 1;
    if ( ! $self->parse_params(@params) ) {
        my $usage = $self->usage(0);
        warn $usage;
        exit 1;
    }
    my $result = $self->process;
    exit ($result ? 0 : 1);
}

sub usage {
    my $class = shift;
    $class = ref $class
        if ref $class;
    my $verbosity = shift;
    require WGDev::Help;
    my $usage = WGDev::Help::package_usage($class, $verbosity);
    return $usage;
}

1;

