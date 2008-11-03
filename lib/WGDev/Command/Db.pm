package WGDev::Command::Db;
use strict;
use warnings;

our $VERSION = '0.1.0';

use Getopt::Long ();

sub run {
    my $class = shift;
    my $wgd = shift;
    Getopt::Long::Configure(qw(default gnu_getopt));
    Getopt::Long::GetOptions(
        'e|echo'            => \(my $opt_echo),
        'd|dump'            => \(my $opt_dump),
    );
    my $db = $wgd->db;

    exec {'mysql'} 'mysql', $db->command_line(@ARGV);
}

1;

