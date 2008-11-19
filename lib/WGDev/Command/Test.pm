package WGDev::Command::Test;
use strict;
use warnings;

our $VERSION = '0.0.1';

sub run {
    require App::Prove;
    require Cwd;
    my $class = shift;
    my $wgd = shift;
    Getopt::Long::Configure(qw(default gnu_getopt pass_through));
    Getopt::Long::GetOptionsFromArray(\@_,
        'S'     => \(my $opt_slow),
        'A'     => \(my $opt_all),
    );
    if ($opt_slow) {
        $ENV{CODE_COP}      = 1;
        $ENV{TEST_SYNTAX}   = 1;
        $ENV{TEST_POD}      = 1;
    }
    my $prove = App::Prove->new;
    my @args = @_;
    my $orig_dir;
    if ($opt_all) {
        $orig_dir = Cwd::cwd;
        chdir File::Spec->catdir($wgd->root, 't');
        push @args, '-r';
    }
    $prove->process_args(@args);
    my $result = $prove->run;
    chdir $orig_dir
        if $orig_dir;
    return $result;
}

sub usage {
    my $class = shift;
    return <<END_HELP;
this command is not very helpful
END_HELP
}

1;

