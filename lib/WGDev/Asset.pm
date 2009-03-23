package WGDev::Asset;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.0.1';

use constant LINE_LENGTH => 78;

use WGDev;
use Carp qw(croak);

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
    return WebGUI::Asset->new( $self->{session}, @_ );
}

sub find {
    my ( $self, $asset_spec ) = @_;
    my $session = $self->{session};
    my $asset;
    if ( $session->id->valid($asset_spec) ) {
        $asset = WebGUI::Asset->new( $session, $asset_spec );
    }
    if ( !$asset ) {
        $asset = WebGUI::Asset->newByUrl( $session, $asset_spec );
    }
    if ( $asset && ref $asset && $asset->isa('WebGUI::Asset') ) {
        return $asset;
    }
    croak "Not able to find asset $asset_spec";
}

sub validate_class {
    my $self = shift;
    my $in_class = my $class = shift;
    if ( $class =~ s/\A(?:(?:WebGUI::Asset)?::)?(.*)/WebGUI::Asset::$1/msx ) {
        my $short_class = $1;
        if ( $class =~ /\A[[:upper:]]\w+(?:::[[:upper:]]\w+)*\z/msx ) {
            return wantarray ? ( $class, $short_class ) : $class;
        }
    }
    croak "Invalid Asset class: $in_class";
}

sub _gen_serialize_header {
    my $header_text = shift;
    my $header      = "==== $header_text ";
    $header .= ( q{=} x ( LINE_LENGTH - length $header ) ) . "\n";
    return $header;
}

sub serialize {
    my ( $self, $asset, $properties ) = @_;
    my $class = ref $asset || $asset;
    my $short_class = $class;
    $short_class =~ s/^WebGUI::Asset:://xms;
    my $definition = $class->definition( $self->{session} );
    my %text;
    my %meta;

    my $asset_properties = {
        ref $asset  ? %{ $asset->get } : (),
        $properties ? %{$properties}   : () };

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

            my $field_type = ucfirst $property_def->{fieldType};
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
    my $output = _gen_serialize_header($short_class) . $basic_yaml;

    while ( my ( $field, $value ) = each %text ) {
        if ( !defined $value ) {
            $value = q{~};
        }
        $value =~ s/\r\n?/\n/msxg;
        $output .= _gen_serialize_header($field) . $value . "\n";
    }

    my $meta_yaml = WGDev::yaml_encode( \%meta );
    $meta_yaml =~ s/\A---(?:\Q {}\E)?\n?//msx;
    $output .= _gen_serialize_header('Properties') . $meta_yaml . "\n";

    return $output;
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
    shift @text_sections;
    my $class = shift @text_sections;
    $class =~ s/^(?:(?:WebGUI::Asset)?::)?/WebGUI::Asset::/msx;
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

1;

__END__

=head1 NAME

WGDev::Asset - Asset utility functions

=head1 SYNOPSIS

    my $root_node = $wgd->asset->root;

=head1 DESCRIPTION

Performs common actions on assets

=head1 AUTHOR

Graham Knop <graham@plainblack.com>

=head1 LICENSE

Copyright (c) Graham Knop.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

