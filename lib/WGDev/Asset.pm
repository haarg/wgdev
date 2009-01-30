package WGDev::Asset;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.0.1';

use constant LINE_LENGTH => 78;

use WGDev;

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

sub by_url {    ## no critic (RequireArgUnpacking)
    my $self = shift;
    return WebGUI::Asset->newByUrl( $self->{session}, @_ );
}

sub by_id {     ## no critic (RequireArgUnpacking)
    my $self = shift;
    return WebGUI::Asset->new( $self->{session}, @_ );
}

sub serialize {
    my ( $self, $asset ) = @_;
    my $class       = ref $asset;
    my $short_class = $class;
    $short_class =~ s/^WebGUI::Asset:://xms;
    my $definition = $class->definition( $asset->session );
    my %text;
    my %meta;
    my $asset_properties = $asset->get;
    my $parent_url       = $asset->getParent->get('url');
    my $header           = "==== $short_class ";
    $header .= ( q{=} x ( LINE_LENGTH - length $header ) ) . "\n";
    my $output = $header . <<"END_COMMON";
Asset ID     : $asset_properties->{assetId}
Title        : $asset_properties->{title}
# Menu Title : $asset_properties->{menuTitle}
# URL        : $asset_properties->{url}
# Parent URL : $parent_url
END_COMMON

    for my $def ( @{$definition} ) {
        while ( my ( $property, $property_def )
            = each %{ $def->{properties} } )
        {
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
    while ( my ( $field, $value ) = each %text ) {
        $header = "==== $field ";
        $header .= ( q{=} x ( LINE_LENGTH - length $header ) ) . "\n";
        $output .= $header . ( defined $value ? $value : q{~} ) . "\n";
    }
    $header = '==== Properties ';
    $header .= ( q{=} x ( LINE_LENGTH - length $header ) ) . "\n";
    $output .= $header;
    my $meta_yaml = WGDev::yaml_encode( \%meta );
    $meta_yaml =~ s/\A---(?:\Q {}\E)?\n?//msx;
    $output .= $meta_yaml;
    return $output;
}

sub deserialize {
    my $self          = shift;
    my $asset_data    = shift;
    my @text_sections = split m{
        ^\Q==== \E  # line start, plus equal signs
        ((?:\w|:)+) # word chars or colons (Perl namespace)
        [ ]=+       # space + equals
        (?:\n|\z)   # end of line or end of string
    }msx, $asset_data;
    shift @text_sections;
    my $class      = shift @text_sections;
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
    %properties = ( %properties, %sections );
    for my $line ( split /\n/msx, $basic_data ) {
        next
            if $line =~ /\A\s*#/msx;
        if (
            $line =~ m{
            ^\s*
            ([^:]+?)
            \s*:\s*
            (.*?)
            \s*$
        }msx
            )
        {
            my $prop
                = $1 eq 'Title'      ? 'title'
                : $1 eq 'Asset ID'   ? 'assetId'
                : $1 eq 'Menu Title' ? 'menuTitle'
                : $1 eq 'URL'        ? 'url'
                : $1 eq 'Parent URL' ? 'parent_url'
                :                      undef;
            if ($prop) {
                $properties{$prop} = $2;
            }
        }
    }

    return \%properties;
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

