package Test::WGDev;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.0.1';

use Test::Builder::Module ();
BEGIN { our @ISA = qw(Test::Builder::Module) }
use Scope::Guard ();
use Cwd ();

our @EXPORT = qw(capture_output guard_chdir is_path);

use base 'Test::Builder::Module';

sub is_path ($$;$) {
    my ($got, $expected, $name) = @_;
    my $tb = __PACKAGE__->builder;
    if (defined $got) {
        $got = Cwd::realpath($got);
    }
    if (defined $expected) {
        $expected = Cwd::realpath($expected);
    }
    $tb->is_eq($got, $expected, $name);
}

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
    my $cwd = Cwd::cwd;
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

Copyright (c) 2009, Graham Knop

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl 5.10.0. For more details, see the
full text of the licenses in the directory LICENSES.

=cut


