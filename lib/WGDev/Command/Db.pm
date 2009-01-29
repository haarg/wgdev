package WGDev::Command::Db;
use strict;
use warnings;

our $VERSION = '0.1.0';

use WGDev::Command::Base;
our @ISA = qw(WGDev::Command::Base);

sub option_config { qw(
    print|p
    dump|d:s
    load|l=s
    clear|c
)}

sub option_parse_config { qw(gnu_getopt pass_through) }

sub process {
    my $self = shift;
    my $db = $self->wgd->db;
    my @command_line = $db->command_line($self->arguments);
    if (  (defined $self->option('print')   || 0)
        + (defined $self->option('dump')    || 0)
        + (defined $self->option('load')    || 0)
        + (defined $self->option('clear')   || 0) > 1) {
        die "Multiple database operations specified!\n";
    }

    if ($self->option('print')) {
        print join " ", map {"'$_'"} @command_line
    }
    elsif ($self->option('clear')) {
        $db->clear;
    }
    elsif (defined $self->option('load')) {
        if ($self->option('load') && $self->option('load') ne '-') {
            $db->load($self->option('load'));
        }
        else {
            exec {'mysql'} 'mysql', @command_line;
        }
    }
    elsif (defined $self->option('dump')) {
        if ($self->option('dump') && $self->option('dump') ne '-') {
            $db->dump($self->option('dump'));
        }
        else {
            exec {'mysqldump'} 'mysqldump', @command_line;
        }
    }
    else {
        exec {'mysql'} 'mysql', @command_line;
    }
}

1;

__END__

=head1 NAME

WGDev::Command::Db - Connect to database with mysql

=head1 SYNOPSIS

wgd db [-p | -d | -l | -c] [mysql options]

=head1 OPTIONS

Any arguments not recognized will be passed through to the mysql or mysqldump commands in applicable.

=over 8

=item B<-p --print>

Prints out the command options that would be passed to mysql

=item B<-d --dump>

Dumps the database as an SQL script.  If a file is specified,
dumps to that file.  Otherwise, dumps to standard out.

=item B<-l --load>

Loads a database script into the database.  Database script must be specified.

=item B<-c --clear>

Clears the database, removing all tables.

=back

=cut

