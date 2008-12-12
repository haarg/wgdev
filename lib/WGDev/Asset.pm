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

__END__


