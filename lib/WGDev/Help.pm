package WGDev::Help;
use strict;
use warnings;

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
    ##no critic (RequireCarping)
    open my $out, '>', \$output or die "Can't open file handle to scalar : $!";
    open my $in, '<', \$pod or croak "Unable to read documentation file : $!";
    my %params = (
        -input   => $in,
        -output  => $out,
        -exitval => 'NOEXIT',
        -verbose => $verbosity,
    );
    close $in  or return q{};
    close $out or return q{};
    Pod::Usage::pod2usage( \%params );
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
        =~ /^(=head1 NAME\s+^\Q$wanted\E\s.*?)(?:^=head1 NAME\s|\z)/msx )
    {
        return $1;
    }
    return q{};
}

1;

