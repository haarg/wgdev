package WGDev;
use strict;
use warnings;

our $VERSION = '0.1.0';

use File::Spec ();
use Cwd ();
use Carp qw(croak);

sub new {
    my $class = shift;
    my ($root, $config) = @_;
    my $self = bless {}, $class;
    if (-e $config) {
        # file exists as is, save absolute path
        $self->{config_file} = $config = File::Spec->rel2abs($config);
    }
    if ($root) {
        $self->{root} = $root;
    }
    else {
        if (-e $config) {
            my $config_dir = File::Spec->catpath( (File::Spec->splitpath($config))[0,1] );
            $self->{root} = Cwd::realpath(File::Spec->catdir($config_dir, File::Spec->updir));
        }
        else {
            my $dir = Cwd::getcwd();
            while (1) {
                if (-e File::Spec->catfile($dir, 'etc', 'WebGUI.conf.original')) {
                    $self->{config_file} = File::Spec->catfile($dir, 'etc', $config);
                    $self->{root} = $dir;
                    last;
                }
                my $parent = Cwd::realpath( File::Spec->catdir( $dir, File::Spec->updir ) );
                last
                    if $dir eq $parent;
                $dir = $parent;
            }
        }
    }
    if ($self->{root}) {
        $self->{config_file} ||= File::Spec->catfile($self->{root}, 'etc', $config);
        $self->{lib}    = File::Spec->catdir($self->{root}, 'lib');
    }
    else {
        croak "unable to determine webgui root!";
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
        ? do { require Config; $self->lib . $Config::Config{path_sep} . $ENV{PERL5LIB} }
        : $self->lib
        ;
    return 1;
}

sub root            { shift->{root} }
sub config_file     { shift->{config_file} }
sub lib             { shift->{lib} }
sub config {
    my $self = shift;
    croak "no config file available"
        unless $self->{config_file};
    return $self->{config} ||= do {
        require Config::JSON;
        Config::JSON->new($self->config_file);
    };
}

sub config_file_relative {
    my $self = shift;
    return $self->{config_file_relative} ||= do {
        my $config_dir = Cwd::realpath(File::Spec->catdir($self->root, 'etc'));
        File::Spec->abs2rel(Cwd::realpath($self->config_file), $config_dir);
    }
}

sub db {
    my $self = shift;
    require WGDev::Database;
    return $self->{db} ||= WGDev::Database->new($self->config);
}

sub session {
    my $self = shift;
    require WebGUI::Session;
    if ($self->{session}) {
        my $dbh = $self->{session}->db->dbh;
        local $dbh->{PrintWarn} = 0;
        local $dbh->{PrintError} = 0;
        local $dbh->{RaiseError} = 1;
        eval {
            $dbh->do('SELECT 1');
        };
        if ($@) {
            delete $self->{session};
        }
    }
    return $self->{session} ||= do {
        my $session = WebGUI::Session->open($self->root, $self->config_file_relative, undef, undef, $self->{session_id});
        # eeevil
        $self->{session_id} = $session->getId;
        $session;
    };
}

sub asset {
    my $self = shift;
    require WGDev::Asset;
    $self->{asset} ||= WGDev::Asset->new($self->session);
}

sub version {
    my $self = shift;
    require WGDev::Version;
    $self->{version} ||= WGDev::Version->new($self->root);
}

sub DESTROY {
    my $self = shift;
    if ($self->{session}) {
        my $session = $self->session;
        $session->var->end;
        $session->close;
        delete $self->{session};
    }
}

1;

