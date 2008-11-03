package WGDev::Command;
use strict;
use warnings;

our $VERSION = '0.1.1';

use Getopt::Long ();
use File::Spec ();
use Cwd ();
use Carp qw(croak);

sub run {
    my $class = shift;
    Getopt::Long::Configure(qw(default gnu_getopt pass_through));
    Getopt::Long::GetOptionsFromArray(\@_,
        'h|?|help'          => \(my $opt_help),
        'V|ver|version'     => \(my $opt_ver),
        'man'               => \(my $opt_man),

        'F|config-file=s'   => \(my $opt_config),
        'R|webgui-root=s'   => \(my $opt_root),
    );

    $opt_config ||= $ENV{WEBGUI_CONFIG};
    $opt_root ||= $ENV{WEBGUI_ROOT};

    my $command_name = shift @_;

    die "no command specified!\n"
        unless $command_name;

    my $command_module;
    if ($command_name =~ /^[a-zA-Z0-9-]+$/) {
        (my $module = "WGDev::Command::\u$command_name") =~ s/-(.)/::\u$1/g;
        (my $module_file = "$module.pm") =~ s{::}{/}g;
        eval { require $module_file };
        if ( $module->can('run') ) {
            $command_module = $module;
        }
    }
    if (!$command_module) {
        for my $path (File::Spec->path) {
            my $execpath = File::Spec->catfile($path, "wgd-$command_name");
            if (-x $execpath) {
                require WGDev;
                my $wgd = WGDev->new($opt_root, $opt_config);
                exec {$execpath} $execpath, @_;
            }
        }
    }

    if (!$command_module) {
        die "unable to find command $command_name\n";
    }

    require WGDev;
    my $wgd = WGDev->new($opt_root, $opt_config);
    eval {
        $command_module->run($wgd, @_);
    };
    if ($@) {
        die $@;
    }
}

1;

