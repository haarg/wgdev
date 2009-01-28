package WGDev::Asset;
use strict;
use warnings;

our $VERSION = '0.0.1';

use WGDev;

sub new {
    my $class = shift;
    my $session = shift;
    my $self = bless {
        session => $session,
    }, $class;
    require WebGUI::Asset;
    return $self;
}

sub root {
    my $self = shift;
    return WebGUI::Asset->getRoot($self->{session});
}
sub import_node {
    my $self = shift;
    return WebGUI::Asset->getImportNode($self->{session});
}
sub default_asset { goto &home }
sub home {
    my $self = shift;
    return WebGUI::Asset->getDefault($self->{session});
}

sub by_url {
    my $self = shift;
    return WebGUI::Asset->newByUrl($self->{session}, @_);
}

sub by_id {
    my $self = shift;
    return WebGUI::Asset->new($self->{session}, @_);
}

sub serialize {
    my ($self, $asset) = @_;
    my $class = ref $asset;
    my $short_class = $class;
    $short_class =~ s/^WebGUI::Asset:://;
    my $definition = $class->definition($asset->session);
    my %text;
    my %meta;
    my $asset_properties = $asset->get;
    my $parent_url  = $asset->getParent->get('url');
    my $output = "==== $short_class "
        . ('=' x (78 - 6 - length($short_class))) . "\n"
        . <<END_COMMON;
Asset ID     : $asset_properties->{assetId}
Title        : $asset_properties->{title}
# Menu Title : $asset_properties->{menuTitle}
# URL        : $asset_properties->{url}
# Parent URL : $parent_url
END_COMMON
    for my $def (@$definition) {
        while ( my ($property, $property_def) = each %{$def->{properties}} ) {
            my $field_type = ucfirst($property_def->{fieldType});
            if ($property eq 'title' || $property eq 'menuTitle' || $property eq 'url') {
                next;
            }
            elsif ($field_type eq 'HTMLArea'
                || $field_type eq 'Textarea'
                || $field_type eq 'Codearea'
            ) {
                $text{$property} = $asset_properties->{$property};
            }
            elsif ($field_type eq 'Hidden') {
                next;
            }
            else {
                $meta{$property_def->{tab} || 'properties'}{$property} = $asset_properties->{$property};
            }
        }
    }
    while (my ($field, $value) = each %text) {
        $output
            .= "==== $field "
            . ('=' x (78 - 6 - length($field))) . "\n"
            . (defined $value ? $value : '~')
            . "\n"
            ;
    }
    $output .= "==== Properties ==============================================================\n";
    my $meta_yaml = WGDev::yaml_encode(\%meta);
    $meta_yaml =~ s/^---(?: \{\})?\n?//;
    $output .= $meta_yaml;
    return $output;
}

sub deserialize {
    my $self = shift;
    my $asset_data = shift;
    my @text_sections = split /^==== ((?:\w|:)+) =+(?:\n|\z)/m, $asset_data;
    shift @text_sections;
    my $class = shift @text_sections;
    my $basic_data = shift @text_sections;
    my %sections;
    my %properties;
    while (my $section = shift @text_sections) {
        my $section_data = shift @text_sections;
        chomp $section_data;
        $section_data = undef
            if $section_data eq '~';
        $sections{$section} = $section_data;
    }
    if (my $prop_data = delete $sections{Properties}) {
        my $tabs = WGDev::yaml_decode($prop_data);
        %properties = map { %{ $_ } } values %$tabs;
    }
    %properties = (%properties, %sections);
    for my $line (split /\n/, $basic_data) {
        next
            if $line =~ /^\s*#/;
        if ($line =~ /^\s*([^:]+?)\s*:\s*(.*?)\s*$/m) {
            my $prop
                = $1 eq 'Title'         ? 'title'
                : $1 eq 'Asset ID'      ? 'assetId'
                : $1 eq 'Menu Title'    ? 'menuTitle'
                : $1 eq 'URL'           ? 'url'
                : $1 eq 'Parent URL'    ? 'parent_url'
                : undef;
            $properties{$prop} = $2
                if $prop;
        }
    }

    return \%properties;
}

1;

__END__


