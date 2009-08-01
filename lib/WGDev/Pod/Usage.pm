package WGDev::Pod::Usage;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.0.1';

use constant OPTION_INDENT      => 4;
use constant OPTION_TEXT_INDENT => 24;

sub new {
    my $proto = shift;

    # This is really ugly, but delay loading parent modules until first use.
    require Pod::PlainText;
    require Pod::Select;
    if ( !our @ISA ) {
        @ISA = qw(Pod::PlainText Pod::Select);
    }

    my $self = $proto->SUPER::new( indent => 0 );
    $self->verbosity(1);
    return $self;
}

sub verbosity {
    my $self      = shift;
    my $verbosity = shift;
    if ($verbosity) {
        $self->select(qw(NAME SYNOPSIS OPTIONS/!.+));
    }
    else {
        $self->select(qw(NAME SYNOPSIS));
    }
    return;
}

sub cmd_head1 {
    my $self = shift;
    my $head = shift;
    my $para = shift;
    $head =~ s/\s+$//msx;
    $self->{_last_head1} = $head;
    if ( $head eq 'NAME' ) {
        return;
    }
    elsif ( $head eq 'SYNOPSIS' ) {
        $head = 'USAGE';
    }
    $head = lc $head;
    $head =~ s/\b(.)/uc($1)/msxe;
    $head .= q{:};
    my $output = $self->interpolate( $head, $para );
    $self->output( $output . "\n" );
    return;
}

sub textblock {
    my $self = shift;
    my $text = shift;
    my $para = shift;
    if ( $self->{_last_head1} eq 'NAME' ) {
        $text =~ s/^[\w:]+\Q - //msx;
    }
    return $self->SUPER::textblock( $text, $para );
}

sub item {
    my $self   = shift;
    my $item   = shift;
    my $tag    = delete $self->{ITEM};
    my $margin = $self->{MARGIN};
    local $self->{MARGIN} = 0;    ## no critic (ProhibitLocalVars)

    $tag = $self->reformat($tag);
    $tag =~ s/\n*\z//msx;

    $item =~ s/[.].*//msx;
    {
        ## no critic (ProhibitLocalVars)
        local $self->{width} = $self->{width} - OPTION_TEXT_INDENT;
        $item = $self->reformat($item);
    }
    $item =~ s/\n*\z//msx;
    my $option_indent_string = q{ } x OPTION_TEXT_INDENT;
    $item =~ s/\n/\n$option_indent_string/msxg;

    my $indent_string = q{ } x OPTION_INDENT;
    if ( $item eq q{} ) {
        $self->output( $indent_string . $tag . "\n" );
    }
    else {
        my $option_name_length = OPTION_TEXT_INDENT - OPTION_INDENT - 1;
        $self->output( $indent_string . sprintf "%-*s %s\n", $option_name_length,
            $tag, $item );
    }
    return;
}

sub seq_c {
    return $_[1];
}

sub parse_from_string {
    my $self   = shift;
    my $pod    = shift;
    my $output = q{};
    open my $out_fh, '>', \$output
        or die "Can't open file handle to scalar : $!";
    open my $in_fh, '<', \$pod
        or die "Can't open file handle to scalar : $!";
    $self->parse_from_filehandle( $in_fh, $out_fh );
    close $in_fh  or return q{};
    close $out_fh or return q{};
    return $output;
}

1;

