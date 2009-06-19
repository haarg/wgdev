package WGDev::Command::Optimize;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.2.0';

use WGDev::Command::Base::Verbosity;
BEGIN { our @ISA = qw(WGDev::Command::Base::Verbosity) }

sub config_options {
    return qw(
        assets
        macros
        db
    );
}

sub process {
    my $self = shift;
    my $wgd  = $self->wgd;

    if ( $self->option('assets') ) {
        $self->optimise_assets();
    }

    if ( $self->option('macros') ) {
        $self->optimise_macros();
    }

    if ( $self->option('db') ) {
        $self->optimise_db();
    }
    return 1;
}

sub optimise_assets {
    my $self    = shift;
    my $wgd     = $self->wgd;
    my $session = $wgd->session();

    my @assets;
    for my $asset ( sort keys %{ $session->config->get('assets') } ) {
        if (
            !$session->db->quickScalar(
                'select count(*) from asset where className = ?', [$asset] ) )
        {
            push @assets, $asset;
        }
    }

    if (@assets) {
        $self->report(
            "The following Assets do not appear in your Asset table:\n");
        for my $asset (@assets) {
            $self->report("\t$asset\n");
        }
        my $config  = $wgd->config_file();
        my $message = <<"END_MESSAGE";
If you are sure any of these Assets are not being used on your site,
you can reduce memory usage by removing them from the "assets" section of
your site config file, which is located at:
\t$config

Keep in mind:
*) Some assets such as FilePile will not appear in your Assets table but
   are still used to provide funcitonality (in the case of FilePile 
   providing a way for users to upload multiple Files).
END_MESSAGE
        $self->report("$message");
    }

    return 1;
}

sub optimise_macros {
    my $self    = shift;
    my $wgd     = $self->wgd;
    my $session = $wgd->session();

    my @macros;
    for my $macro ( sort keys %{ $session->config->get('macros') } ) {
        if (
            !$session->db->quickScalar(
                'select count(*) from template where template like ? or template like ?',
                [ "%^$macro;%", "%^$macro(%" ] ) )
        {
            push @macros, $macro;
        }
    }

    if (@macros) {
        my $macros  = join q{}, map {"\t$_\n"} @macros;
        my $config  = $wgd->config_file();
        my $message = <<"END_MESSAGE";
The following Macros do not appear in the template field of the template table:
$macros

If you are sure any of these Macros are not being used on your site,
you can reduce memory usage by removing them from the "macros" section of
your site config file, which is located at:
\t$config

Keep in mind:
*) Macros can be references from lots of places other then just Templates, 
   for example the mailFooter setting in the Settings table 
END_MESSAGE
        $self->report($message);
    }

    return 1;
}

use constant OPTIMIZE_TABLES_LIMIT => 10;

sub optimise_db {
    my $self    = shift;
    my $wgd     = $self->wgd;
    my $session = $wgd->session();

    my $sth = $session->db->read('show table status');

    my @tables;
    while ( my $r = $sth->hashRef ) {
        push @tables, [ $r->{Name}, $r->{Data_length}, $r->{Rows} ];
    }

    $self->report("Top 10 Tables, sorted by Data_length\n");
    my $ctr;
    for my $table ( sort { $b->[1] <=> $a->[1] } @tables ) {
        ## no critic (ProhibitParensWithBuiltins)
        $self->report( sprintf( "%10d\t%s\n", $table->[1], $table->[0] ) );
        last
            if ++$ctr == OPTIMIZE_TABLES_LIMIT;
    }
    $self->report("\n");

    $self->report("Top 10 Tables, sorted by Rows\n");
    $ctr = 0;
    for my $table ( sort { $b->[2] <=> $a->[2] } @tables ) {
        ## no critic (ProhibitParensWithBuiltins)
        $self->report( sprintf( "%10d\t%s\n", $table->[2], $table->[0] ) );
        last
            if ++$ctr == OPTIMIZE_TABLES_LIMIT;
    }
    $self->report("\n");

    $self->report(<<'END_ADVICE');
To reduce row count, you may want to investigate deleting old/unused data.
To reduce row size, apart from deleting rows, you might want to investigate mysql's "optimize table" command.
END_ADVICE

    return 1;
}

1;

__END__

=head1 NAME

WGDev::Command::Optimize - Scans your site and suggests various optimizations

=head1 SYNOPSIS

    wgd optimize [--assets] [--macros]

=head1 DESCRIPTION

Scans your site and suggests various optimizations

=head1 OPTIONS

=over 8

=item C<--assets>

Suggests Assets that you might be able to disable to reduce memory consumption

=item C<--macros>

Suggests Macros that you might be able to disable to reduce memory consumption

=item C<--db>

Suggests database tables that may be able to be adjusted to increase speed.

=back

=head1 METHODS

=head2 C<optimise_assets>

Suggests Assets that you might be able to disable to reduce memory consumption

=head2 C<optimise_macros>

Suggests Macros that you might be able to disable to reduce memory consumption

=head2 C<optimise_db>

Suggests database tables that may be able to be adjusted to increase speed.

=head1 AUTHOR

Patrick Donelan <pat@patspam.com>

=head1 LICENSE

Copyright (c) Patrick Donelan.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

