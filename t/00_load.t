use strict;
use warnings;

use Test::More;
use File::Spec;
use File::Find;

my $lib_dir = -d 'blib/lib' ? 'blib/lib' : 'lib';
unshift @INC, $lib_dir;
my @modules = find_modules($lib_dir);

plan tests => 2 * (scalar @modules);

foreach my $library (@modules) {
    my $warnings = '';
    local $^W = 1;
    local $SIG{__WARN__} = sub {
        $warnings .= shift;
    };
    eval {
        require $library;
    };
    chomp $warnings;
    is($@, '', "$library compiles successfully");
    is($warnings, '', "$library compiles without warnings");
}

sub find_modules {
    my $lib_dir = shift;
    my @modules;
    File::Find::find( {
        no_chdir => 1,
        wanted => sub {
            return
                unless $File::Find::name =~ /\.pm$/;
            my $lib = File::Spec->abs2rel($File::Find::name, $lib_dir);
            push @modules, $lib;
        },
    }, $lib_dir);
    return @modules;
}

