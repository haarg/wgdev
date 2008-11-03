package WGDev::Asset;
use strict;
use warnings;

our $VERSION = '0.0.1';


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
    return WebGUI::Asset->getRoot(shift->{session});
}
sub import {
    return WebGUI::Asset->getImportNode(shift->{session});
}
sub default { goto &home }
sub home {
    return WebGUI::Asset->getDefault(shift->{session});
}


sub by_url {
    return WebGUI::Asset->newByUrl(shift->{session}, @_);
}

sub by_id {
    return WebGUI::Asset->new(shift->{session}, @_);
}

sub serialize {
    my $self = shift;
    my $asset = shift;
    my $class = ref $asset;
    my $definition = $class->definition($asset->session);
    my %meta;
    my %text;
    #for my $def (@$definition) {
    #}
}

sub deserialize {
    my $self = shift;
    my $asset_data = shift;

}

1;

