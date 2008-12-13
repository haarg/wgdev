package WGDev;
use strict;
use warnings;

use 5.008008;

our $VERSION = '0.1.0';

use File::Spec ();
use Cwd        ();
use Carp qw(croak);

sub new {
    my ( $class, $root, $config ) = @_;
    my $self = bless {}, $class;
    if ( $config && -e $config ) {

        # file exists as is, save absolute path
        $self->{config_file} = $config = File::Spec->rel2abs($config);
    }
    if ($root) {
        $self->{root} = $root;
    }
    else {
        if ( $config && -e $config ) {
            my $config_dir = File::Spec->catpath(
                ( File::Spec->splitpath($config) )[ 0, 1 ] );
            $self->{root} = Cwd::realpath(
                File::Spec->catdir( $config_dir, File::Spec->updir ) );
        }
        else {
            my $dir = Cwd::getcwd();
            while (1) {
                if (
                    -e File::Spec->catfile(
                        $dir, 'etc', 'WebGUI.conf.original'
                    ) )
                {
                    $self->{root} = $dir;
                    last;
                }
                my $parent = Cwd::realpath(
                    File::Spec->catdir( $dir, File::Spec->updir ) );
                last
                    if $dir eq $parent;
                $dir = $parent;
            }
        }
    }
    if ( $self->{root} ) {
        if ( !$config ) {
            opendir my $dh, File::Spec->catdir( $self->{root}, 'etc' );
            my @configs = readdir $dh;
            closedir $dh;
            @configs = grep { /\.conf$/msx && !/^(?:spectre|log).conf$/msx }
                @configs;
            if ( @configs == 1 ) {
                $config = $configs[0];
            }
        }
        if ($config) {
            $self->{config_file}
                ||= File::Spec->catfile( $self->{root}, 'etc', $config );
        }
        $self->{lib} = File::Spec->catdir( $self->{root}, 'lib' );
    }
    else {
        croak 'unable to determine webgui root!';
    }

    $self->set_environment;

    return $self;
}

sub set_environment {
    my $self = shift;
    $ENV{WEBGUI_ROOT}   = $self->root;
    $ENV{WEBGUI_CONFIG} = $self->config_file;
    unshift @INC, $self->lib;
    $ENV{PERL5LIB} = $ENV{PERL5LIB}
        ? do {
        require Config;
        $self->lib . $Config::Config{path_sep} . $ENV{PERL5LIB};
        }
        : $self->lib;
    return 1;
}

sub root        { return shift->{root} }
sub config_file { return shift->{config_file} }
sub lib         { return shift->{lib} }

sub config {
    my $self = shift;
    croak 'no config file available'
        if !$self->{config_file};
    return $self->{config} ||= do {
        require Config::JSON;
        Config::JSON->new( $self->config_file );
    };
}

sub config_file_relative {
    my $self = shift;
    return $self->{config_file_relative} ||= do {
        my $config_dir
            = Cwd::realpath( File::Spec->catdir( $self->root, 'etc' ) );
        File::Spec->abs2rel( Cwd::realpath( $self->config_file ),
            $config_dir );
    };
}

sub db {
    my $self = shift;
    require WGDev::Database;
    return $self->{db} ||= WGDev::Database->new( $self->config );
}

sub session {
    my $self = shift;
    require WebGUI::Session;
    if ( $self->{session} ) {
        my $dbh = $self->{session}->db->dbh;

        # evil, but we have to detect if the database handle died somehow
        if ( ! $dbh->ping ) {
            ( delete $self->{session} )->close;
        }
    }
    return $self->{session} ||= do {
        my $session
            = WebGUI::Session->open( $self->root, $self->config_file_relative,
            undef, undef, $self->{session_id} );
        $self->{session_id} = $session->getId;
        $session;
    };
}

sub asset {
    my $self = shift;
    require WGDev::Asset;
    return $self->{asset} ||= WGDev::Asset->new( $self->session );
}

sub version {
    my $self = shift;
    require WGDev::Version;
    return $self->{version} ||= WGDev::Version->new( $self->root );
}

sub wgd_config {
    my $self      = shift;
    my $namespace = shift;
    my $key       = shift;
    my $config    = $self->{wgd_config};
    if ( !$config ) {
        for my $config_file ( '.wgdevcfg', $ENV{HOME} . '/.wgdevcfg' ) {
            if ( -e $config_file ) {
                open my $fh, '<', $config_file or next;
                my $content = do { local $/ = undef; <$fh> };
                close $fh or next;
                $self->{wgd_config} = $config = yaml_decode($content);
            }
        }
    }
    if ( !$config ) {
        return;
    }
    if ($namespace) {
        my $ns_config = $config->{$namespace};
        if ( !$ns_config ) {
            return;
        }
        if ($key) {
            return $ns_config->{$key};
        }
        return $ns_config;
    }
    else {
        return $config;
    }
}

sub my_config {    ## no critic (RequireArgUnpacking)
    my ($self)   = shift;
    my ($caller) = caller;
    return $self->wgd_config( $caller, @_ );
}

sub yaml_decode {
    ## no critic (RequireFinalReturn ProhibitCascadingIfElse ProhibitNoWarnings)
    my $decode;
    if ( eval { require YAML::XS } ) {
        $decode = \&YAML::XS::Load;
    }
    elsif ( eval { require YAML::Syck } ) {
        $decode = \&YAML::Syck::Load;
    }
    elsif ( eval { require YAML } ) {
        $decode = \&YAML::Load;
    }
    elsif ( eval { require YAML::Tiny } ) {
        $decode = \&YAML::Tiny::Load;
    }
    else {
        $decode = sub {
            die "No YAML library available!\n";
        };
    }
    no warnings 'redefine';
    *yaml_decode = $decode;
    goto &{$decode};
}

sub DESTROY {
    my $self = shift;

    if ( $self->{session} ) {    # if we have a cached session
        my $session = $self->session;  # get the session, recreating if needed
        $session->var->end;            # close the session
        $session->close;
        delete $self->{session};
    }
    return;
}

1;

__END__

=head1 NAME

WGDev - WebGUI Developer Utilities

=head1 SYNOPSIS

    use WGDev;

    my $wgd = WGDev->new( $webgui_root, $config_file );

    my $webgui_session = $wgd->session;
    my $webgui_version = $wgd->version->module;

=head1 DESCRIPTION

Performs common actions needed by WebGUI developers, such as recreating their
site from defaults, checking version numbers, exporting packages, and more.

=head1 AUTHOR

Graham Knop <graham@plainblack.com>

=head1 LICENSE

Copyright (c) 2008 Graham Knop.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut



