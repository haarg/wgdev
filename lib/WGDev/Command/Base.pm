package WGDev::Command::Base;
# ABSTRACT: Super-class for implementing WGDev commands
use strict;
use warnings;
use 5.008008;

use WGDev::X ();

sub is_runnable {
    my $class = shift;
    return $class->can('process');
}

sub new {
    my ( $class, $wgd ) = @_;
    my $self = bless {
        wgd       => $wgd,
        options   => {},
        arguments => [],
    }, $class;
    return $self;
}

sub wgd { return $_[0]->{wgd} }

sub parse_params {
    my $self = shift;
    local @ARGV = @_;

    require Getopt::Long;
    Getopt::Long::Configure( 'default', $self->config_parse_options );

    my %getopt_params = (
        '<>' => sub {
            $self->argument( map {"$_"} @_ );
        },
    );

    for my $option ( $self->config_options ) {

        # for complex options, name is first word segment
        ( my $option_name ) = ( $option =~ /([\w-]+)/msx );
        my $method = 'option_' . $option_name;
        $method =~ tr/-/_/;
        if ( $self->can($method) ) {
            $getopt_params{$option} = sub {
                $self->$method( @_[ 1 .. $#_ ] );
            };
        }
        else {
            $getopt_params{$option} = \( $self->{options}{$option_name} );
        }
    }
    my $result = Getopt::Long::GetOptions(%getopt_params);
    push @{ $self->{arguments} }, @ARGV;
    return $result;
}

sub parse_params_string {
    my $self         = shift;
    my $param_string = shift;
    require Text::ParseWords;
    return $self->parse_params( Text::ParseWords::shellwords($param_string) );
}

sub config_parse_options { return qw(gnu_getopt) }
sub config_options       { }

sub option {
    my $self = shift;
    my $option = shift || return;
    if (@_) {
        return $self->{options}{$option} = shift;
    }
    return $self->{options}{$option};
}

sub set_option_default {
    my $self = shift;
    my $option = shift || return;
    if ( !defined $self->option($option) ) {
        return $self->option( $option, @_ );
    }
    return;
}

sub argument {
    my $self = shift;
    if (@_) {
        push @{ $self->{arguments} }, @_;
        return wantarray ? @_ : $_[-1];
    }
    return;
}

sub arguments {
    my $self = shift;
    if ( @_ && ref $_[0] eq 'ARRAY' ) {
        my $arguments = shift;
        @{ $self->{arguments} } = @{$arguments};
    }
    return @{ $self->{arguments} };
}

sub run {
    my $self = shift;
    WGDev::X::NoWebGUIRoot->throw
        if $self->needs_root && !$self->wgd->root;
    WGDev::X::NoWebGUIConfig->throw
        if $self->needs_config && !$self->wgd->config_file;
    my @params = ( @_ == 1 && ref $_[0] eq 'ARRAY' ) ? @{ +shift } : @_;
    local $| = 1;
    if ( !$self->parse_params(@params) ) {
        my $usage = $self->usage(0);
        WGDev::X::CommandLine::BadParams->throw( usage => $usage );
    }
    return $self->process;
}

sub usage {
    my $class     = shift;
    my $verbosity = shift;
    if ( ref $class ) {
        $class = ref $class;
    }
    require WGDev::Help;
    my $usage = WGDev::Help::package_usage( $class, $verbosity );
    return $usage;
}

sub help {
    my $class = shift;
    if ( ref $class ) {
        $class = ref $class;
    }
    require WGDev::Help;
    WGDev::Help::package_perldoc( $class,
        '!AUTHOR|LICENSE|METHODS|SUBROUTINES' );
    return 1;
}

sub needs_root {
    return 1;
}

sub needs_config {
    my $class = shift;
    return $class->needs_root;
}

1;

=head1 SYNOPSIS

    package WGDev::Command::Mine;
    use parent qw(WGDev::Command::Base);

    sub process {
        my $self = shift;
        print "Running my command\n";
        return 1;
    }

=head1 DESCRIPTION

A super-class useful for implementing L<WGDev> command modules.  Includes
simple methods to override for parameter parsing and provides help text via
Pod::Usage.

While using WGDev::Command::Base is not required to write a command module,
it is the recommended way to do so.

=method C<is_runnable>

This is a class method that must be implemented and return true for all
command modules.  This method will return true for any subclass that
implements the C<process> method.

=method C<new ( $wgd )>

Instantiate a new command object.  Requires a L<WGDev> object as the first
parameter.

=method C<wgd>

Returns the L<WGDev> object used to instantiate the object.

=method C<config_parse_options>

Returns an array of parameters used to configure command line parsing.  These
options are passed directly to L<Getopt::Long>.  See
L<Getopt::Long/Configuring_Getopt::Long> for details on the available options.
By default, returns C<gnu_getopt> and can be overridden to return others.

=method C<config_options>

Returns an array of command line options to be parsed.  Should be overridden
to set which options will be parsed.  Should be specified in the syntax
accepted by L<Getopt::Long>.  Each option will be saved as the the first
group of word characters in the option definition.  Alternately, if a method
with the name C<< option_<name> >> exists, it will be called to set the
option instead.

=method C<option ( $option [, $value] )>

Sets or returns a command line option.  Accepts the option name as the first
parameter.  If specified, the option will be set the the value of the second
parameter.

=method C<argument ( $argument )>

Adds an argument to the argument list.  Any parameters specified will be added
to the argument list.  Can be overridden to provide alternate behavior.

=method C<arguments ( [ \@arguments ] )>

Sets or returns the arguments list.  If specified, the first parameter
must be an array reference whose values will be set as the arguments list.

=method C<parse_params ( @parameters )>

Sets options based on an array of command line parameters.

=method C<parse_params_string ( $parameters )>

Sets options based on a string of command line parameters.  The string will be
processed with L<Text::ParseWords> C<shellwords> sub then passed on to
C<parse_params>.

=method C<set_option_default ( $option, $value )>

Sets an option only if it is not currently defined.  First parameter is the
option to set, second parameter is the value to set it to.

=method C<needs_root>

Should be overridden in subclasses to set whether a command needs a WebGUI root directory to run.  Returns true if not overridden.

=method C<needs_config>

Should be overridden in subclasses to set whether a command needs a WebGUI config file directory to run.  Returns the same value as L</needs_root> if not overridden.

=method C<usage ( [ $verbosity ] )>

Returns the usage information for the command.  The optional first parameter
is the verbosity to use.

=method C<help>

Display help information for this command using L<perldoc>.  Excludes AUTHOR
and LICENSE sections.

=method C<run ( @arguments )>

Runs the command.  Parameters should be the command line parameters
to use for running the command.  This sub should return a true value
on success and either die or return a false value on failure.  The
default method will first call C<process_params> with the given
parameters, call C<usage> if there was a problem with parsing the
parameters, or call C<process> if there was not.  It will return
C<process>'s return value to the caller.

=method C<process>

Needs to be subclasses to provide the main functionality of the command.  This
method will be called as part of the run method.  Should return a true value
on success.

=cut

