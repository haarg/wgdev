package WGDev::Command::Test;
use strict;
use warnings;

our $VERSION = '0.0.1';

use WGDev::Command::Base;
our @ISA = qw(WGDev::Command::Base);

use File::Spec;

sub process {
    require Cwd;
    require App::Prove;
    my $self = shift;
    my $wgd = $self->wgd;
    if ($self->option('slow')) {
        $ENV{CODE_COP}      = 1;
        $ENV{TEST_SYNTAX}   = 1;
        $ENV{TEST_POD}      = 1;
    }
    my $prove = App::Prove->new;
    my @args = @_;
    my $orig_dir;
    if ($self->option('slow')) {
        $orig_dir = Cwd::cwd();
        chdir File::Spec->catdir($wgd->root, 't');
        unshift @args, '-r';
    }
    $prove->process_args(@args);
    my $result = $prove->run;
    chdir $orig_dir
        if $orig_dir;
    return $result;
}

sub option_parse_config { qw(gnu_getopt pass_through) }

sub option_config {qw(
    all|A
    slow|S
)}

1;

__END__

=head1 NAME

WGDev::Command::Test - Does things

=cut

