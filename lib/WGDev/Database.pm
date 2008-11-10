package WGDev::Database;
use strict;
use warnings;

our $VERSION = '0.0.1';

sub username    { shift->{username} }
sub password    { shift->{password} }
sub database    { shift->{database} }
sub hostname    { shift->{hostname} }
sub port        { shift->{port} }
sub dsn         { shift->{dsn} }

sub user    { goto &username }
sub pass    { goto &password }
sub host    { goto &hostname }
sub name    { goto &database }

sub new {
    my $class = shift;
    my $config = shift;
    my $self = bless {}, $class;

    my $dsn = $self->{dsn}  = $config->get('dsn');
    $self->{username}   = $config->get('dbuser');
    $self->{password}   = $config->get('dbpass');
    $self->{database}   = (split(/[:;]/, $dsn))[2];
    $self->{hostname}   = 'localhost';
    $self->{port}       = '3306';
    while ($dsn =~ /([^=;:]+)=([^;:]+)/g) {
        if ($1 eq 'host' || $1 eq 'hostname') {
            $self->{hostname} = $2;
        }
        elsif ($1 eq 'db' || $1 eq 'database' || $1 eq 'dbname') {
            $self->{database} = $2;
        }
        elsif ($1 eq 'port') {
            $self->{port} = $2;
        }
    }
    return $self;
}

sub command_line {
    my $self = shift;
    my @params = (
        '-h' . $self->hostname,
        '-P' . $self->port,
        $self->database,
        '-u' . $self->username,
        ($self->password ? '-p' . $self->password : ()),
        @_
    );
    return wantarray ? @params : join (' ', map {"'$_'"} @params);
}

sub connect {
    my $self = shift;
    require DBI;
    if ($self->{dbh}) {
        eval {
            $self->{dbh}->do('SELECT 1');
        };
        delete $self->{dbh}
            if $@;
    }
    return $self->{dbh} ||= DBI->connect(
        $self->dsn, $self->username, $self->password,
        {RaiseError => 1, PrintWarn => 0, PrintError => 0, mysql_enable_utf8 => 1}
    );
}
sub dbh         { shift->{dbh} }
sub open        { goto &connect }

sub disconnect {
    my $self = shift;
    if (my $dbh = delete $self->{dbh}) {
        $dbh->disconnect;
    }
}
sub close       { goto &disconnect }

sub clear {
    my $self = shift;
    my $dbh = $self->connect;
    my $sth = $dbh->table_info(undef, undef, '%');
    my @tables = map {@$_} @{$sth->fetchall_arrayref([2])};
    for my $table (@tables) {
        $dbh->do('DROP TABLE ' . $dbh->quote_identifier($table));
    }
    return 1;
}

sub load {
    my $self = shift;
    my $dumpfile = shift;
    $self->clear;
    system 'mysql', $self->command_line('-e' . 'source ' . $dumpfile)
        and die;
    return 1;
}

sub dump {
    my $self = shift;
    my $dumpfile = shift;
    system 'mysqldump', $self->command_line('-r' . $dumpfile)
        and die;
    return 1;
}

1;

