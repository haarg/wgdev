package WGDev::Database;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.0.1';

use WGDev::X ();

sub username { return shift->{username} }
sub password { return shift->{password} }
sub database { return shift->{database} }
sub hostname { return shift->{hostname} }
sub port     { return shift->{port} }
sub dsn      { return shift->{dsn} }

sub user { goto &username }
sub pass { goto &password }
sub host { goto &hostname }
sub name { goto &database }

sub new {
    my $class  = shift;
    my $config = shift;
    my $self   = bless {}, $class;

    my $dsn = $self->{dsn} = $config->get('dsn');
    $self->{username} = $config->get('dbuser');
    $self->{password} = $config->get('dbpass');
    $self->{database} = ( split /[:;]/msx, $dsn )[2];
    $self->{hostname} = 'localhost';
    $self->{port}     = '3306';
    while ( $dsn =~ /([^=;:]+)=([^;:]+)/msxg ) {
        if ( $1 eq 'host' || $1 eq 'hostname' ) {
            $self->{hostname} = $2;
        }
        elsif ( $1 eq 'db' || $1 eq 'database' || $1 eq 'dbname' ) {
            $self->{database} = $2;
        }
        elsif ( $1 eq 'port' ) {
            $self->{port} = $2;
        }
    }
    return $self;
}

sub command_line {
    my $self   = shift;
    my @params = (
        '-h' . $self->hostname,
        '-P' . $self->port,
        $self->database,
        '-u' . $self->username,
        ( $self->password ? '-p' . $self->password : () ),
        '--default-character-set=utf8',
        @_,
    );
    return wantarray ? @params : join q{ }, map {"'$_'"} @params;
}

sub connect {    ## no critic (ProhibitBuiltinHomonyms)
    my $self = shift;
    require DBI;
    if ( $self->{dbh} && !$self->{dbh}->ping ) {
        delete $self->{dbh};
    }
    return $self->{dbh} ||= DBI->connect(
        $self->dsn,
        $self->username,
        $self->password,
        {
            RaiseError        => 1,
            PrintWarn         => 0,
            PrintError        => 0,
            mysql_enable_utf8 => 1
        } );
}
sub dbh  { return shift->{dbh} }
sub open { goto &connect }         ## no critic (ProhibitBuiltinHomonyms)

sub disconnect {
    my $self = shift;
    if ( my $dbh = delete $self->{dbh} ) {
        $dbh->disconnect;
    }
    return;
}

sub close {    ## no critic (ProhibitBuiltinHomonyms ProhibitAmbiguousNames)
    goto &disconnect;
}

sub clear {
    my $self   = shift;
    my $dbh    = $self->connect;
    my $sth    = $dbh->table_info( undef, undef, q{%} );
    my @tables = map { @{$_} } @{ $sth->fetchall_arrayref( [2] ) };
    for my $table (@tables) {
        $dbh->do( 'DROP TABLE ' . $dbh->quote_identifier($table) );
    }
    return 1;
}

sub load {
    my $self     = shift;
    my $dumpfile = shift;
    system 'mysql', $self->command_line( '-e' . 'source ' . $dumpfile )
        and WGDev::X::System->throw('Error running mysql');
    return 1;
}

sub dump {    ## no critic (ProhibitBuiltinHomonyms)
    my $self     = shift;
    my $dumpfile = shift;
    system 'mysqldump', $self->command_line( '-r' . $dumpfile )
        and WGDev::X::System->throw('Error running mysqldump');
    return 1;
}

1;

__END__

=head1 NAME

WGDev::Database - Database connectivity and DSN parsing for WGDev

=head1 SYNOPSIS

    my $dsn = $wgd->database->connect;
    my $username = $wgd->database->username;

=head1 DESCRIPTION

Has methods to access various parts of the DSN that can be used for other
programs such as command line C<mysql>.  Also has methods to easily connect
and reuse a database connection.

=head1 METHODS

=head2 C<new ( $wgd )>

Creates a new WGDev::Database object.

=head3 C<$wgd>

An instantiated WGDev object.

=head2 C<dsn>

Returns the DSN for the database.

=head2 C<database>

Returns the name of the database.

=head2 C<name>

Alias for the L</database> method.

=head2 C<hostname>

Returns the host name for the database connection.

=head2 C<host>

Alias for the L</hostname> method.

=head2 C<password>

Returns the password for the database connection.

=head2 C<pass>

Alias for the L</password> method.

=head2 C<port>

Returns the port for the database connection.

=head2 C<username>

Returns the user name for the database connection.

=head2 C<user>

Alias for the L</username> method.

=head2 C<command_line>

Returns command line options suitable for passing to the F<mysql>
or F<mysqldump> command line programs to connect to the database.

=head2 C<connect>

Connects to the database if it hasn't been connected to yet and
returns the database handle for the connection.

=head2 C<open>

Alias for the L</connect> method.

=head2 C<dbh>

Returns the database handle of the current connection, or C<undef> if
there is no active connection.

=head2 C<disconnect>

Closes the active database connection.  If there is no active
connection, does nothing.

=head2 C<close>

Alias for the L</disconnect> method.

=head2 C<clear>

Removes all tables from the database, leaving it empty.

=head2 C<dump ( $dumpfile )>

Dumps the database content to the specified file.

=head2 C<load ( $dumpfile )>

Loads the specified database script into the database.

=head1 AUTHOR

Graham Knop <graham@plainblack.com>

=head1 LICENSE

Copyright (c) Graham Knop.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

