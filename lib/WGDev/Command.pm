package WGDev::Command;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.1.1';

use Getopt::Long ();
use File::Spec   ();
use Cwd          ();
use Carp qw(croak carp);

sub run {    ##no critic (RequireArgUnpacking)
    my $class = shift;
    local @ARGV = @_;
    Getopt::Long::Configure(qw(default gnu_getopt pass_through));
    Getopt::Long::GetOptions(
        'h|?|help'      => \( my $opt_help ),
        'V|ver|version' => \( my $opt_version ),

        'F|config-file=s' => \( my $opt_config = $ENV{WEBGUI_CONFIG} ),
        'R|webgui-root=s' => \( my $opt_root   = $ENV{WEBGUI_ROOT} ),
    ) || carp $class->usage && exit 1;
    my @params = @ARGV;

    my $command_name = shift @params;

    my $command_module = _find_cmd_module($command_name);
    if ( $command_name && !$command_module ) {
        my $command_exec = _find_cmd_exec($command_name);
        if ($command_exec) {
            require WGDev;
            WGDev->new( $opt_root, $opt_config )->set_environment;
            exec {$execpath} $execpath, $opt_help ? '--help' : (),
                $opt_version ? '--version' : (), @_;
        }
        else {
            carp $class->usage(
                message          => "Can't find command $command_name!\n",
                include_cmd_list => 1
            );
            exit 2;
        }
    }

    if ($opt_version) {
        $class->report_version( $command_name, $command_module );
    }
    elsif ($opt_help) {
        $class->report_help( $command_name, $command_module );
    }
    elsif ( !$command_name ) {
        carp $class->usage(
            message          => "No command specified!\n",
            include_cmd_list => 1
        );
        exit 1;
    }
    else {
        require WGDev;
        my $wgd = WGDev->new( $opt_root, $opt_config );
        if (
            !eval {
                my $command = $command_module->new($wgd);
                $command->run(@params);
                1;
            } )
        {
            carp $@;
            exit 1;
        }
    }
    exit;
}

sub report_version {
    my ( $class, $name, $module ) = @_;
    if ( ref $class ) {
        $class = ref $class;
    }
    print "$class version " . $class->VERSION;
    if ($module) {
        print " - $module version " . $module->VERSION;
    }
    print "\n";
    return 1;
}

sub report_help {
    my ( $class, $name, $module ) = @_;
    if ( ref $class ) {
        $class = ref $class;
    }
    if ($module) {
        if ( $module->can('usage') ) {
            print $module->usage;
        }
        else {
            carp "No documentation for $name command.\n";
        }
    }
    else {
        print $class->usage;
    }
    return 1;
}

sub _find_cmd_module {
    my $command_name = shift;
    if ( $command_name && $command_name =~ /^[-\w]+$/mxs ) {
        my $module = join q{::}, __PACKAGE__, map {ucfirst} split /-/msx,
            $command_name;
        ( my $module_file = "$module.pm" ) =~ s{::}{/}mxsg;
        if (   eval { require $module_file; 1 }
            && $module->can('run')
            && $module->can('is_runnable')
            && $module->is_runnable )
        {
            return $module;
        }
    }
    return;
}

sub _find_cmd_exec {
    my ( $command_name, $root, $config ) = @_;
    if ($command_name) {
        for my $path ( File::Spec->path ) {
            my $execpath = File::Spec->catfile( $path, "wgd-$command_name" );
            if ( -x $execpath ) {
                return $execpath;
            }
        }
    }
    return;
}

sub usage {
    my $class = shift;
    require WGDev::Help;
    my $message = WGDev::Help::package_usage( $class, 2 );

    $message .= "\nsubcommands available:\n";
    for my $command ( $class->command_list ) {
        $message .= "    $command\n";
    }
    $message .= "\n";
    return $message;
}

sub command_list {
    my $class = shift;
    my %commands;
    ( my $fn_prefix = $class ) =~ s{::}{/}msxg;

    require File::Find;
    for my $inc_path (@INC) {
        ##no critic (ProhibitParensWithBuiltins)
        my $command_root
            = File::Spec->catdir( $inc_path, split( /::/msx, $class ) );
        next
            if !-d $command_root;
        my $find_callback = sub {
            return
                if !/\Q.pm\E$/msx;

            #no warnings;
            my $lib_path
                = File::Spec->abs2rel( $File::Find::name, $inc_path );
            my $package = $lib_path;
            $package =~ s/\Q.pm\E$//msx;
            $package = join q{::}, File::Spec->splitdir($package);
            my $command_name = $package;
            $command_name =~ s/^\Q$class\E:://msx;
            $command_name = join q{-}, map {lcfirst} split /::/msx,
                $command_name;

            if ( eval { require $lib_path; $package->can('process') } ) {
                $commands{$command_name} = 1;
            }
        };
        File::Find::find( { no_chdir => 1, wanted => $find_callback },
            $command_root );
    }
    for my $module ( grep {m{^$fn_prefix/}msx} keys %INC ) {
        ( my $command = $module ) =~ s/\Q.pm\E$//msx;
        $command =~ s{^$fn_prefix/}{}msx;
        $command = join q{-}, map {lcfirst} split m{/}msx, $command;
        $commands{$command} = 1;
    }
    for my $command ( map { glob "$_/wgd-*" } File::Spec->path ) {
        next
            if !-x $command;
        my $file = ( File::Spec->splitpath($command) )[2];
        $file =~ s/^wgd-//msx;
        $commands{$file} = 1;
    }
    my @commands = sort keys %commands;
    return @commands;
}

1;

__END__

=head1 NAME

WGDev::Command - Run WGDev commands

=head1 SYNOPSIS

wgd [arguments] <subcommand> [subcommand arguments]

=head1 DESCRIPTION

Runs subcommands from the WGDev::Command namespace, or standalone scripts starting with wgd-

=head1 OPTIONS

=over 8

=item B<-h -? --help>

Display help for any command.

=item B<-V --version>

Display version information

=item B<-F --config-file>

Specify WebGUI config file to use.  Can be absolute, relative to
the current directory, or relative to WebGUI's config directory.
If not specified, it will try to use the WEBGUI_CONFIG environment
variable.  If that is not set and there is only one config file
in WebGUI's config directory, that file will be used.

=item B<-R --webgui-root>

Specify WebGUI's root directory.  Can be absolute or relative.
If not specified, first the WEBGUI_ROOT environment variable will
be checked, then will search upward from the current path for a
WebGUI installation.

=item B<E<lt>subcommandE<gt>>

Subcommand to run or get help for.

=cut

=head1 AUTHOR

Graham Knop <graham@plainblack.com>

=head1 LICENSE

Copyright (c) 2008 Graham Knop.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

