package WGDev::Asset;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.0.1';

use constant LINE_LENGTH => 78;

use WGDev;
use WGDev::X;

sub new {
    my $class   = shift;
    my $session = shift;
    my $self    = bless { session => $session, }, $class;
    require WebGUI::Asset;
    return $self;
}

sub root {
    my $self = shift;
    return WebGUI::Asset->getRoot( $self->{session} );
}

sub import_node {
    my $self = shift;
    return WebGUI::Asset->getImportNode( $self->{session} );
}

sub default_asset { goto &home }

sub home {
    my $self = shift;
    return WebGUI::Asset->getDefault( $self->{session} );
}

sub by_url {
    my $self = shift;
    return WebGUI::Asset->newByUrl( $self->{session}, @_ );
}

sub by_id {
    my $self = shift;
    if (WebGUI::Asset->can('newById')) {
        return WebGUI::Asset->newById( $self->{session}, @_ );
    }
    else {
        return WebGUI::Asset->new( $self->{session}, @_ );
    }
}

sub find {
    my ( $self, $asset_spec ) = @_;
    my $session = $self->{session};
    my $asset;
    if ( $session->id->valid($asset_spec) ) {
        $asset = $self->by_id($asset_spec);
    }
    if ( !$asset ) {
        $asset = WebGUI::Asset->newByUrl( $session, $asset_spec );
    }
    if ( $asset && ref $asset && $asset->isa('WebGUI::Asset') ) {
        return $asset;
    }
    WGDev::X::AssetNotFound->throw( asset => $asset_spec );
}

my $package_re = qr{
    [[:upper:]]\w+
    (?: ::[[:upper:]]\w+ )*
}msx;

sub validate_class {
    my $self = shift;
    my $in_class = my $class = shift;
    if (
        $class =~ s{\A
            # optionally starting with WebGUI::Asset:: or ::
            (?:(?:WebGUI::Asset)?::)?
            ( $package_re )
            \z
        }{WebGUI::Asset::$1}msx
        )
    {
        my $short_class = $1;
        return wantarray ? ( $class, $short_class ) : $class;
    }
    WGDev::X::BadAssetClass->throw( class => $in_class );
}

sub _gen_serialize_header {
    my $self        = shift;
    my $header_text = shift;
    my $header      = "==== $header_text ";
    $header .= ( q{=} x ( LINE_LENGTH - length $header ) ) . "\n";
    return $header;
}

sub serialize {
    my ( $self, $asset, $properties ) = @_;
    my $class = ref $asset || $asset;
    WGDev::X::BadParameter->throw('No asset or class specified')
        if not defined $class;
    if ( !ref $asset ) {
        ( my $module = $class . '.pm' ) =~ s{::}{/}msxg;
        require $module;
    }
    my $short_class = $class;
    $short_class =~ s/^WebGUI::Asset:://xms;

    my ( $asset_properties, $meta, $text )
        = $self->_asset_properties( $asset, $properties );

    my $basic_yaml = WGDev::yaml_encode( {
            'Asset ID'   => $asset_properties->{assetId},
            'Title'      => $asset_properties->{title},
            'Menu Title' => $asset_properties->{menuTitle},
            'URL'        => $asset_properties->{url},
            'Parent'     => (
                ref $asset
                ? $asset->getParent->get('url')
                : $self->import_node->get('url')
            ),
        } );

    # filter out unneeded YAML syntax
    $basic_yaml =~ s/\A---(?:\Q {}\E)?\n?//msx;

    # line up colons
    $basic_yaml =~ s/^([^:]+):/sprintf("%-12s:", $1)/msxeg;
    $basic_yaml =~ s/\n?\z/\n/msx;
    my $output = $self->_gen_serialize_header($short_class) . $basic_yaml;

    for my $field ( sort keys %{$text} ) {
        my $value = $text->{$field};
        if ( !defined $value ) {
            $value = q{~};
        }
        $value =~ s/\r\n?/\n/msxg;
        $output .= $self->_gen_serialize_header($field) . $value . "\n";
    }

    my $meta_yaml = WGDev::yaml_encode($meta);
    $meta_yaml =~ s/\A---(?:\Q {}\E)?\n?//msx;
    $output .= $self->_gen_serialize_header('Properties') . $meta_yaml . "\n";

    return $output;
}

sub _asset_properties {
    my $self       = shift;
    my $class      = shift;
    my $properties = shift;
    my $asset;
    if ( ref $class ) {
        $asset = $class;
        $class = ref $asset;
    }

    my $definition = $class->definition( $self->{session} );
    my %text;
    my %meta;

    my $asset_properties
        = { $asset ? %{ $asset->get } : (), $properties ? %{$properties} : (),
        };
    for my $def ( @{$definition} ) {
        while ( my ( $property, $property_def )
            = each %{ $def->{properties} } )
        {
            if (  !defined $asset_properties->{$property}
                && defined $property_def->{defaultValue} )
            {
                $asset_properties->{$property}
                    = $self->_get_property_default($property_def);
            }

            my $field_type = ucfirst ( $property_def->{fieldType} || '' );
            if (   $property eq 'title'
                || $property eq 'menuTitle'
                || $property eq 'url' )
            {
                next;
            }
            elsif ($field_type eq 'HTMLArea'
                || $field_type eq 'Textarea'
                || $field_type eq 'Codearea' )
            {
                $text{$property} = $asset_properties->{$property};
            }
            elsif ( $field_type eq 'Hidden' ) {
                next;
            }
            else {
                $meta{ $property_def->{tab} || 'properties' }{$property}
                    = $asset_properties->{$property};
            }
        }
    }
    return ( $asset_properties, \%meta, \%text );
}

my %basic_translation = (
    'Title'      => 'title',
    'Asset ID'   => 'assetId',
    'Menu Title' => 'menuTitle',
    'URL'        => 'url',
    'Parent'     => 'parent',
);

sub deserialize {
    my $self          = shift;
    my $asset_data    = shift;
    my @text_sections = split m{
        ^====[ ]    # line start, plus equal signs
        ((?:\w|:)+) # word chars or colons (Perl namespace)
        [ ]=+       # space + equals
        (?:\n|\z)   # end of line or end of string
    }msx, $asset_data;

    # due to split, there is an extra empty entry at the beginning
    shift @text_sections;
    my $class      = $self->validate_class( shift @text_sections );
    my $basic_data = shift @text_sections;
    my %sections;
    my %properties;

    while ( my $section = shift @text_sections ) {
        my $section_data = shift @text_sections;
        chomp $section_data;
        if ( $section_data eq q{~} ) {
            $section_data = undef;
        }
        $sections{$section} = $section_data;
    }
    if ( my $prop_data = delete $sections{Properties} ) {
        my $tabs = WGDev::yaml_decode($prop_data);
        %properties = map { %{$_} } values %{$tabs};
    }

    @properties{ keys %sections } = values %sections;

    my $basic_untrans = WGDev::yaml_decode($basic_data);
    for my $property ( keys %{$basic_untrans} ) {
        if ( $basic_translation{$property} ) {
            $properties{ $basic_translation{$property} }
                = $basic_untrans->{$property};
        }
    }

    $properties{className} = $class;

    return \%properties;
}

sub _get_property_default {
    my $self         = shift;
    my $property_def = shift;
    my $default      = $property_def->{defaultValue};
    my $form_class   = $property_def->{fieldType};
    if ($form_class) {
        $form_class = "WebGUI::Form::\u$form_class";
        my $form_module = join q{/}, ( split /::/msx, $form_class . '.pm' );
        if ( eval { require $form_module; 1 } ) {
            my $form = $form_class->new( $self->{session},
                { defaultValue => $default } );
            $default = $form->getDefaultValue;
        }
    }
    return $default;
}

sub export_extension {
    my $self  = shift;
    my $asset = shift;
    my $class = ref $asset || $asset;
    return
        if !defined $class;
    my $short_class = $class;
    $short_class =~ s/.*:://msx;
    my $extension = lc $short_class;
    $extension =~ s/(?<!^)[aeiouy]//msxg;
    $extension =~ tr/a-z//s;
    return $extension;
}

1;

__DATA__

=head1 NAME

WGDev::Asset - Asset utility functions

=head1 SYNOPSIS

    my $root_node = $wgd->asset->root;

=head1 DESCRIPTION

Performs common actions on assets.

=head1 METHODS

=head2 C<new ( $session )>

Creates a new object.  Requires a single parameter of the WebGUI session to use.

=head2 C<by_id ( $asset_id )>

Finds an asset based on an asset ID.

=head2 C<by_url ( $asset_url )>

Finds an asset based on a URL.

=head2 C<find ( $asset_id_or_url )>

Finds an asset based on either an asset ID or a URL based on the format of
the input.

=head2 C<home>

An alias for the C<default_asset> method.

=head2 C<default_asset>

Returns the default WebGUI asset, as will be shown for the URL of C</>.

=head2 C<root>

Returns the root WebGUI asset.

=head2 C<import_node>

Returns the Import Node asset.

=head2 C<serialize ( $asset_or_class )>

Serializes an asset into a string that can be written out to a file.

=head2 C<deserialize ( $asset_data_text )>

Deserializes a string as generated by C<serialize> into either a hash
reference of properties that can be used to create or update an asset.

=head2 C<validate_class ( [ $class_name ] )>

Accepts a class name of an asset in either full (C<WebGUI::Asset::Template>) or
short (C<Template>) form.  In scalar context, returns the full class name.  In
array context, returns an array of the full and the short class name.  Will
throw an error if the provided class is not valid.

=head2 C<export_extension ( $asset_or_class )>

Returns a file extension to use for exporting the given asset or
class.  The extension will be the last segment of the class name,
lower cased, with repeated letters and vowels (except for an initial
vowel) removed.

=head1 AUTHOR

Graham Knop <haarg@haarg.org>

=head1 LICENSE

Copyright (c) 2009-2010, Graham Knop

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl 5.10.0. For more details, see the
full text of the licenses in the directory LICENSES.

=cut

