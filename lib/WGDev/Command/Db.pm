package WGDev::Command::Db;
use strict;
use warnings;

our $VERSION = '0.1.0';

use Getopt::Long ();

sub run {
    my $class = shift;
    my $wgd = shift;
    Getopt::Long::Configure(qw(default gnu_getopt));
    Getopt::Long::GetOptionsFromArray(\@_,
        'p|print'           => \(my $opt_print),
        'd|dump:s'          => \(my $opt_dump),
        'l|load=s'          => \(my $opt_load),
        'c|clear'           => \(my $opt_clear),
    );
    my $db = $wgd->db;
    my @command_line = $db->command_line(@_);
    if (  (defined $opt_print || 0)
        + (defined $opt_dump || 0)
        + (defined $opt_load || 0)
        + (defined $opt_clear || 0) > 1) {
        die "Multiple database operations specified!\n";
    }

    if ($opt_print) {
        print join " ", map {"'$_'"} @command_line
    }
    elsif (defined $opt_dump) {
        if ($opt_dump && $opt_dump ne '-') {
            $db->dump($opt_dump);
        }
        else {
            exec {'mysqldump'} 'mysqldump', @command_line;
        }
    }
    else {
        exec {'mysql'} 'mysql', @command_line;
    }
}

sub usage {
    my $class = shift;
    my $message = __PACKAGE__ . "\n" . <<'END_HELP';

arguments:
    -p
    --print         Prints out the command options that would be passed to mysql
    -d[file]
    --dump[=file]   Dumps the database as an SQL script.  If a file is specified,
                    dumps to that file.  Otherwise, dumps to standard out.
    -c
    --clear         Clears the database, removing all tables.

Any other options will be passed through to the mysql or mysqldump commands if applicable.

END_HELP
    return $message;
}

1;

