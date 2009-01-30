package WGDev::Help;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.0.1';

use Carp qw(croak);

sub package_usage {
    my $package   = shift;
    my $verbosity = shift;
    require Pod::Usage;
    if ( !defined $verbosity ) {
        $verbosity = 1;
    }
    ( my $file = $package . '.pm' ) =~ s{::}{/}msxg;
    require $file;
    my $actual_file = $INC{$file};
    my $pod         = filter_pod( $actual_file, $package );
    my $output      = q{};
    ##no critic (RequireCarping RequireBriefOpen
    open my $out, '>', \$output
        or die "Can't open file handle to scalar : $!";
    open my $in, '<', \$pod or croak "Unable to read documentation file : $!";
    my $params = {
        -input   => $in,
        -output  => $out,
        -exitval => 'NOEXIT',
        -verbose => $verbosity,
    };
    Pod::Usage::pod2usage($params);
    close $in  or return q{};
    close $out or return q{};
    return $output;
}

# naive pod filter.  looks for =head1 NAME section that has the correct
# package listed, and returns the text from there to the next =head1 NAME
sub filter_pod {
    my $file   = shift;
    my $wanted = shift;
    open my $fh, '<', $file or return q{};
    my $content = do { local $/ = undef; <$fh> };
    close $fh or return q{};
    if ( $content
        =~ /^(\Q=head1 NAME\E\s+^\Q$wanted\E\s.*?)(?:^\Q=head1 NAME\E\s|\z)/msx
        )
    {
        return $1;
    }
    return q{};
}

1;

__END__

=head1 AUTHOR

Graham Knop <graham@plainblack.com>

=head1 LICENSE

Copyright (c) Graham Knop.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
