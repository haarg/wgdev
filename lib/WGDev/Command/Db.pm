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
    my @command_line = $db->command_line(@_);
    if (  (defined $self->option('print')   || 0)
        + (defined $self->option('dump')    || 0)
        + (defined $self->option('load')    || 0)
        + (defined $self->option('clear')   || 0) > 1) {
        die "Multiple database operations specified!\n";
    }

    if ($self->option('print')) {
        print join " ", map {"'$_'"} @command_line
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

=head1 DESCRIPTION

arguments:
    -p
    --print         Prints out the command options that would be passed to mysql
    -d[file]
    --dump[=file]   Dumps the database as an SQL script.  If a file is specified,
                    dumps to that file.  Otherwise, dumps to standard out.
    -c
    --clear         Clears the database, removing all tables.

Any other options will be passed through to the mysql or mysqldump commands if applicable.

=cut

