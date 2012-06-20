package WGDev::Command::Ls;
# ABSTRACT: List WebGUI assets
use strict;
use warnings;
use 5.008008;

use parent qw(WGDev::Command::Base);

sub config_options {
    return qw(
        format|f=s
        long|l
        recursive|r
        excludeClass=s@
        includeOnlyClass=s@
        limit=n
        isa=s
        filter=s
    );
}

sub option_filter {
    my $self   = shift;
    my $filter = shift;

    my ( $filter_prop, $filter_sense, $filter_match )
        = $filter =~ m{%(\w+)% \s* ([~!])~ \s* (.*)}msx;
    if (   !defined $filter_prop
        || !defined $filter_sense
        || !defined $filter_match )
    {
        WGDev::X->throw("Invalid filter specified: $filter");
    }
    if ( $filter_match =~ m{\A/(.*)/\Z}msx ) {
        do { $filter_match = qr/$1/msx; }
            || WGDev::X->throw(
            "Specified filter is not a valid regular expression: $1");
    }
    else {
        $filter_match = qr/\A\Q$filter_match\E\z/msx;
    }
    $self->{filter_property} = $filter_prop;
    $self->{filter_sense}    = $filter_sense eq q{~};
    $self->{filter_match}    = $filter_match;
    return;
}

sub process {
    my $self = shift;
    my $wgd  = $self->wgd;

    my $format = $self->option('format');
    if ( $self->option('long') ) {
        $format = '%assetId% %url:-35% %title%';
    }
    elsif ( !$format ) {
        $format = '%url%';
    }

    my $relatives   = $self->option('recursive') ? 'descendants' : 'children';
    my @parents     = $self->arguments;
    my $show_header = @parents > 1;
    my $exclude_classes      = $self->option('excludeClass');
    my $include_only_classes = $self->option('includeOnlyClass');
    my $limit                = $self->option('limit');
    my $isa                  = $self->option('isa');

    my $error;
    PARENT:
    while ( my $parent = shift @parents ) {
        my $asset;
        if ( !do { $asset = $wgd->asset->find($parent) } ) {
            warn "wgd ls: $parent: No such asset\n";
            $error++;
            next;
        }
        if ($show_header) {
            print "$parent:\n";
        }
        my $child_iter = $asset->getLineageIterator(
            [$relatives],
            {
                $exclude_classes ? ( excludeClasses => $exclude_classes )
                : (),
                $include_only_classes
                ? ( includeOnlyClasses => $include_only_classes )
                : (),
                defined $limit
                    && !defined $self->{filter_match} ? ( limit => $limit )
                : (),
                $isa ? ( isa => $isa ) : (),
            } );
        while ( my $child = $child_iter->() ) {
            next
                if !$self->pass_filter($child);

            # Handle limit ourselves because smartmatch filtering happens
            # *after* getLineage returns its results
            last PARENT
                if defined $limit && $limit-- <= 0;

            my $output = $self->format_output( $format, $child );
            print $output . "\n";
        }
        if (@parents) {
            print "\n";
        }
    }
    return (! $error);
}

sub pass_filter {
    my ( $self, $asset ) = @_;
    my $filter_prop  = $self->{filter_property};
    my $filter_sense = $self->{filter_sense};
    my $filter_match = $self->{filter_match};

    return 1
        if !defined $filter_match;

    {
        no warnings 'uninitialized';
        if ($filter_sense) {
            return $asset->get($filter_prop) =~ $filter_match;
        }
        else {
            return $asset->get($filter_prop) !~ $filter_match;
        }
    }
}

sub format_output {
    my ( $self, $format, $asset ) = @_;
    {
        no warnings 'uninitialized';
        $format =~ s{% (?: (\w+) (?: :(-?\d+) )? )? %}{
            my $replace;
            if ($1) {
                $replace = $asset->get($1);
                if ($2) {
                    $replace = sprintf('%*2$s', $replace, $2);
                }
            }
            else {
                $replace = '%';
            }
            $replace;
        }msxeg;
    }
    return $format;
}

1;

=head1 SYNOPSIS

    wgd ls [-l] [--format=<format>] [-r] <asset> [<asset> ...]

=head1 DESCRIPTION

Lists children of WebGUI assets

=head1 OPTIONS

=over 8

=item C<-l> C<--long>

Use long list format, which includes asset ID, URL, and title.

=item C<-f> C<--format=>

Use arbitrary formatting.  Format looks like C<%url:30%>, where 'C<url>' is
the field to display, and 30 is the length to left pad/cut to.  Negative
lengths can be specified for right padding.  Percent signs can be included by
using C<%%>.

=item C<-r> C<--recursive>

Recursively list all descendants (by default we only list children).

=item C<--includeOnlyClass=>

Specify one or more times to limit the results to a certain set of asset classes.

=item C<--excludeClass=>

Specify one or more times to filter out certain asset class(es) from the results.

=item C<--limit=>

The maximum amount of entries to return

=item C<--isa=>

A class name where you can look for classes of a similar base class.
For example, if you're looking for Donations, Subscriptions, Products
and other subclasses of L<WebGUI::Asset::Sku>, then specify the
parameter C<--isa=WebGUI::Asset::Sku>.

=item C<--filter=>

Apply smart match filtering against the results. Format looks like
C<%url% ~~ smartmatch>, where C<url> is the field to filter against,
and C<smartmatch> is either a Perl regular expression such as
C</(?i:partial_match)/> or a string such as C<my_exact_match>.

=back

=method C<format_output ( $format, $asset )>

Returns the formatted information about an asset.  C<$format> is
the format to output as specified in the L<format option|/-f>.

=method C<option_filter ( $filter )>

Takes a filter specification, verifies that it is specified properly, and saves it.

=method C<pass_filter ( $asset )>

Checks if a given asset passes the saved filter.  Returns true or false.

=cut

