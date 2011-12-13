package WGDev::Config;
# ABSTRACT: WGDev's config file
use strict;
use warnings;
use 5.008008;

use Cwd ();
use WGDev::X ();
use Try::Tiny;

sub new {
    my $class = shift;
    my $filename = shift
        or WGDev::X::BadParameter->throw(
            parameter => 'filename',
            message => 'No filename provided.'
        );
    my $self = bless {
        filename => Cwd::realpath($filename),
    }, $class;
    return $self;
}

sub get {
    my $self = shift;
    my $key = shift;
    return $self->_walk_config($key);
}

sub set {
    my $self = shift;
    my $key = shift;
    my $value = shift;
    return $self->_walk_config($key, $value);
}

sub get_my {
    my $self = shift;
    my $key = shift;
    return $self->_my_config($key);
}

sub set_my {
    my $self = shift;
    my $key = shift;
    my $value = shift;
    return $self->_my_config($key, $value);
}

sub _walk_config {    ##no critic (ProhibitExcessComplexity)
    my ( $self, $key_list, $value ) = @_;
    my $config = \( $self->{wgd_config} );
    if ( !${$config} ) {
        $config = \( $self->read_wgd_config );
    }
    my @keys;
    if ( ref $key_list && ref $key_list eq 'ARRAY' ) {
        @keys = @{$key_list};
    }
    else {
        @keys = split /[.]/msx, $key_list;
    }

    if ( !${$config} ) {
        $config = \( $self->{wgd_config} = {} );
    }
    while (@keys) {
        my $key     = shift @keys;
        my $numeric = $key ne q{} && $key =~ /^[+]?-?\d*$/msx;
        my $type    = ref ${$config};
        if (   ( !$type && !defined $value )
            || $type eq 'SCALAR'
            || ( $type eq 'ARRAY' && !$numeric ) )
        {
            return;
        }
        elsif ( $type eq 'ARRAY' or ( !$type && $numeric ) ) {
            if ( !$type ) {
                ${$config} = [];
            }
            my ($insert) = $key =~ s/^([+])//msx;
            if ( !defined $value
                && ( $insert || !defined ${$config}->[$key] ) )
            {
                return;
            }
            if ($insert) {
                if ( $key ne q{} ) {
                    if ( $key < 0 ) {
                        $key += @{ ${$config} };
                    }
                    splice @{ ${$config} }, $key, 0, undef;
                }
                else {
                    $key = @{ ${$config} };
                }
            }
            $config = \( ${$config}->[$key] );
        }
        else {
            if ( !$type ) {
                ${$config} = {};
            }
            if ( !defined ${$config}->{$key} && !defined $value ) {
                return;
            }
            $config = \( ${$config}->{$key} );
        }
        if (@keys) {
            next;
        }
        if ($value) {
            return ${$config} = $value;
        }
        return ${$config};
    }
    return;
}

my $json;

sub read_config {
    my $self = shift;
    my $config_file = $self->{filename};
    if ( -e $config_file ) {
        my $config;
        open my $fh, '<', $config_file
            or WGDev::X::IO::Read->throw(
            message => 'Unable to read config file',
            path    => $config_file,
            );
        my $content = do { local $/; <$fh> };
        close $fh
            or WGDev::X::IO::Read->throw(
            message => 'Unable to read config file',
            path    => $config_file,
            );
        if ( $content eq q{} ) {
            $config = {};
        }
        else {
            if ( !$json ) {
                require JSON;
                $json = JSON->new;
                $json->utf8;
                $json->relaxed;
                $json->canonical;
                $json->pretty;
            }
            try {
                $config = $json->decode($content);
            }
            catch {
                warn "Malformed config file: $_";
                $config = {};
            };
        }
        return $self->{wgd_config} = $config;
    }
    return $self->{wgd_config} = {};
}

sub write_config {
    my $self        = shift;
    my $config_path = $self->{filename};
    my $config = $self->{wgd_config} || {};
    if ( !$json ) {
        require JSON;
        $json = JSON->new;
        $json->utf8;
        $json->relaxed;
        $json->canonical;
        $json->pretty;
    }
    my $encoded = $json->encode($config);
    $encoded =~ s/\n?\z/\n/msx;
    open my $fh, '>', $config_path
        or WGDev::X::IO::Write->throw(
        message => 'Unable to write config file',
        path    => $config_path,
        );
    print {$fh} $encoded;
    close $fh
        or WGDev::X::IO::Write->throw(
        message => 'Unable to write config file',
        path    => $config_path,
        );
    return 1;
}

sub _my_config {
    my $self = shift;
    my $key  = shift;
    my @keys;
    if ( ref $key && ref $key eq 'ARRAY' ) {
        @keys = @{$key};
    }
    else {
        @keys = split /[.]/msx, $key;
    }
    # currently this will always be called by get_my or set_my
    my $caller = caller 2;
    my $remove = ( ref $self ) . q{::};
    $caller =~ s/^\Q$remove//msx;
    unshift @keys, map { lcfirst $_ } split /::/msx, $caller;
    return $self->wgd_config( \@keys, @_ );
}

1;


=head1 SYNOPSIS

    use WGDev::Config;

    my $wgd_config = WGDev::Config->new( $config_file );

    my $value = $wgd_config->get('command.reset.profiles.bisect');
    $wgd_config->set('command.reset.profiles.buildtest', '--build --no-starter');

=head1 DESCRIPTION

Loads and saves settings from a WGDev config file.

=method C<get ( $config_param )>

Get a WGDev config file parameter.  Accepts one parameter, the
config directive.  The config directive is the path in a data
structure specified either as an array reference of keys or a period
separated string of keys.

=method C<set ( $config_param, $value )>

Sets a WGDev config file parameter.  Accepts a config directive and
the value to set.

=method C<get_my ( $config_param )>

Similar to get, but prefixes the specified path with keys based on the
caller's package.  For example, a package of C<WGDev::Command::Reset> becomes
C<command.reset>.

=method C<set_my ( $config_param, $value )>

Similar to set, but prefixes the specified path with keys based on the
caller's package.  For example, a package of C<WGDev::Command::Reset> becomes
C<command.reset>.

=method C<read_config>

Reads and parses the WGDev config file into memory, losing any
unsaved changes.  Will be called automatically when a value is first
requested.

=method C<write_config>

Saves the current configuration back to the WGDev config file.

=cut

