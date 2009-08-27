package Test::WGDev;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.0.1';

use Exporter ();
BEGIN { our @ISA = qw(Exporter) }
use Scope::Guard ();
use Cwd qw(cwd);

our @EXPORT = qw(capture_output guard_chdir);

sub capture_output (&) {
    my $sub    = shift;

    my $output = q{};
    open my $out_fh, '>', \$output;
    my $orig_out = select $out_fh;

    my $guard = Scope::Guard->new(sub {
        select $orig_out;
        close $out_fh;
    });

    $sub->();
    return $output;
}

sub guard_chdir {
    my $cwd = cwd;
    my $guard = Scope::Guard->new(sub {
        chdir $cwd;
    });
    if (@_) {
        my $dir = shift;
        chdir $dir;
    }
    return $guard;
}

1;

__END__

=head1 NAME

Test::WGDev - Additional test functions for WGDev

=head1 AUTHOR

Graham Knop <haarg@haarg.org>

=head1 LICENSE

Copyright (c) Graham Knop

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut


