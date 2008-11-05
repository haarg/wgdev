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
        'd|dump'            => \(my $opt_dump),
    );
    my $db = $wgd->db;
    my @command_line = $db->command_line(@_);

    if ($opt_print) {
        print join " ", map {"'$_'"} @command_line
    }
    elsif ($opt_dump) {
        exec {'mysqldump'} 'mysqldump', @command_line;
    }
    else {
        exec {'mysql'} 'mysql', @command_line;
    }
}

1;

