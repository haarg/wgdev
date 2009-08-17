package WGDev::Command::Db;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.2.0';

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

use WGDev::X ();

sub config_options {
    return qw(
        print|p
        dump|d:s
        load|l=s
        clear|c
        show
    );
}

sub config_parse_options { return qw(gnu_getopt pass_through) }

sub process {
    my $self         = shift;
    my $db           = $self->wgd->db;
    my @command_line = $db->command_line( $self->arguments );
    if (  ( defined $self->option('print') || 0 )
        + ( defined $self->option('dump')  || 0 )
        + ( defined $self->option('load')  || 0 )
        + ( defined $self->option('clear') || 0 ) > 1 )
    {
        WGDev::X->throw('Multiple database operations specified!');
    }

    if ( $self->option('print') ) {
        print join q{ }, map {"'$_'"} @command_line;
        return 1;
    }
    if ( $self->option('clear') ) {
        $db->clear;
        return 1;
    }
    if ( defined $self->option('load') ) {
        if ( $self->option('load') && $self->option('load') ne q{-} ) {
            $db->clear;
            $db->load( $self->option('load') );
            return 1;
        }
    }
    if ( defined $self->option('dump') ) {
        if ( $self->option('dump') && $self->option('dump') ne q{-} ) {
            $db->dump( $self->option('dump') );
            return 1;
        }
        else {
            my $return = system {'mysqldump'} 'mysqldump', @command_line;
            return $return ? 0 : 1;
        }
    }
    if ( defined $self->option('show') ) {
        my $return = system {'mysqlshow'} 'mysqlshow', @command_line;
        return $return ? 0 : 1;
    }
    my $return = system {'mysql'} 'mysql', @command_line;
    return $return ? 0 : 1;
}

1;

__END__

=head1 NAME

WGDev::Command::Db - Connect to database with the MySQL client

=head1 SYNOPSIS

    wgd db [-p | -d | -l | -c | --show] [mysql options]

=head1 DESCRIPTION

Opens the C<mysql> client to your WebGUI database, loads or dumps a database
script, or displays database information, or clears a database's contents.

=head1 OPTIONS

Any arguments not recognized will be passed through to the C<mysql> or
C<mysqldump> commands as applicable.

=over 8

=item C<-p> C<--print>

Prints out the command options that would be passed to C<mysql>

=item C<-d> C<--dump=>

Dumps the database as an SQL script.  If a file is specified, dumps to that
file.  Otherwise, dumps to standard out.

=item C<-l> C<--load=>

Loads a database script into the database.  Database script must be specified.

=item C<-c> C<--clear>

Clears the database, removing all tables.

=item C<--show>

Shows database information via C<mysqlshow>.

For example, to display a summary of the number of columns and rows in each table,
use C<mysqlshow>'s C<--count> option:

 wgd db --show --count

=back

=head1 AUTHOR

Graham Knop <graham@plainblack.com>

=head1 LICENSE

Copyright (c) Graham Knop.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

