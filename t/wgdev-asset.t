use strict;
use warnings;

use Test::More;
use Test::MockObject;
use Test::MockObject::Extends;
use Test::Exception;

use File::Spec::Functions qw(catdir catfile catpath rel2abs splitpath);
use Cwd qw(realpath cwd);

use constant TEST_DIR => catpath( ( splitpath(__FILE__) )[ 0, 1 ], '' );
use lib catdir( TEST_DIR, 'lib' );

use constant HAS_DONE_TESTING => Test::More->can('done_testing') ? 1 : undef;

# use done_testing if possible
if ( !HAS_DONE_TESTING ) {
    plan 'no_plan';
}

BEGIN {
    Test::MockObject->fake_module('WebGUI::Session');
    Test::MockObject->fake_module('WebGUI::Asset');
    Test::MockObject->fake_module('WebGUI::Asset::FakeAsset');
}

use WGDev::Asset ();

my $session = Test::MockObject->new;
$session->set_isa('WebGUI::Session');

my $id = Test::MockObject->new;
$session->set_always( 'id', $id );

my $wgda = WGDev::Asset->new($session);
isa_ok $wgda, 'WGDev::Asset';
$wgda = Test::MockObject::Extends->new($wgda);

{
    no warnings qw(redefine once);
    my @params;
    local *WebGUI::Asset::getRoot = sub {
        @params = @_;
        return 'magic';
    };
    is $wgda->root, 'magic', 'root method returns WebGUI::Asset->getRoot';
    is_deeply \@params, [ 'WebGUI::Asset', $session ],
        '... passing in session';
}

{
    no warnings qw(redefine once);
    my @params;
    local *WebGUI::Asset::getImportNode = sub {
        @params = @_;
        return 'magic';
    };
    is $wgda->import_node, 'magic',
        'import_node method returns WebGUI::Asset->getImportNode';
    is_deeply \@params, [ 'WebGUI::Asset', $session ],
        '... passing in session';
}

{
    no warnings qw(redefine once);
    my @params;
    local *WebGUI::Asset::getDefault = sub {
        @params = @_;
        return 'magic';
    };
    is $wgda->default_asset, 'magic',
        'default_asset method returns WebGUI::Asset->getDefault';
    is_deeply \@params, [ 'WebGUI::Asset', $session ],
        '... passing in session';
}

{
    no warnings qw(redefine once);
    my @params;
    local *WebGUI::Asset::newByUrl = sub {
        @params = @_;
        return 'magic';
    };
    is $wgda->by_url('url'), 'magic',
        'by_url method returns WebGUI::Asset->newByUrl';
    is_deeply \@params, [ 'WebGUI::Asset', $session, 'url' ],
        '... passing in session and url';
}

{
    no warnings qw(redefine once);
    my @params;
    local *WebGUI::Asset::new = sub {
        @params = @_;
        return 'magic';
    };
    is $wgda->by_id('asset-id'), 'magic',
        'by_id method returns WebGUI::Asset->new';
    is_deeply [@params[0..2]], [ 'WebGUI::Asset', $session, 'asset-id' ],
        '... passing in session and asset ID';
}

{
    no warnings qw(redefine once);
    my $by_url;
    local *WebGUI::Asset::newByUrl = sub {
        return $by_url;
    };
    my $by_id;
    local *WebGUI::Asset::new = sub {
        return $by_id;
    };

    $id->set_true('valid');
    $by_id = Test::MockObject->new;
    $by_id->set_isa('WebGUI::Asset');
    lives_and { is $wgda->find('asset'), $by_id }
    'find method finds valid asset by asset id';

    $by_id = Test::MockObject->new;
    throws_ok { $wgda->find('asset') } 'WGDev::X::AssetNotFound',
        'find method throws error if non-asset found';

    $by_id = 'scalar';
    throws_ok { $wgda->find('asset') } 'WGDev::X::AssetNotFound',
        'find method throws error if non-object found';

    undef $by_id;
    throws_ok { $wgda->find('asset') } 'WGDev::X::AssetNotFound',
        'find method throws error if nothing found';

    $by_url = Test::MockObject->new;
    $by_url->set_isa('WebGUI::Asset');
    lives_and { is $wgda->find('asset'), $by_url }
    'find method finds asset by url even if it appears to be an asset id';

    $id->set_false('valid');
    $by_id = Test::MockObject->new;
    $by_id->set_isa('WebGUI::Asset');
    lives_and { is $wgda->find('asset'), $by_url }
    q{find method doesn't try to find by id if it isn't a valid id};
}

lives_and {
    is $wgda->validate_class('WebGUI::Asset::Template'),
        'WebGUI::Asset::Template';
}
'validate_class accepts fully qualified class names';

lives_and { is $wgda->validate_class('Template'), 'WebGUI::Asset::Template' }
'validate_class accepts short class names';

lives_and {
    is $wgda->validate_class('::Template'), 'WebGUI::Asset::Template';
}
'validate_class accepts prefixed short class names';

lives_and {
    is_deeply [ $wgda->validate_class('WebGUI::Asset::Template') ],
        [ 'WebGUI::Asset::Template', 'Template' ];
}
'validate_class returns full class and short class in array context';

throws_ok { $wgda->validate_class('non-word characters') }
'WGDev::X::BadAssetClass',
    'validate_class rejects invalid class names';

is $wgda->_gen_serialize_header('My Header'),
    "==== My Header ===============================================================\n",
    'serialization headers generated correctly';

{
    throws_ok {
        $wgda->serialize;
    }
    'WGDev::X::BadParameter',
        'serialize throws error if not given asset or class';

    Test::MockObject->fake_module(
        'WebGUI::Asset::Test::WGDev',
        definition => sub {
            return [ {
                    properties => {
                        title       => { fieldType    => 'Text' },
                        menuTitle   => { fieldType    => 'Text' },
                        url         => { fieldType    => 'Text' },
                        hiddenField => { fieldType    => 'Hidden' },
                        HTMLField   => { fieldType    => 'HTMLArea' },
                        TextField   => { fieldType    => 'Textarea' },
                        CodeField   => { fieldType    => 'Codearea' },
                        OtherField  => { defaultValue => 'default' },
                        LastField   => { tab          => 'security' },
                    },
                } ];
        },
    );

    my $import_mocked = Test::MockObject->new;
    $import_mocked->set_always( get => 'import_node_url' );
    $wgda->set_always( _get_property_default => 'default value' );
    $wgda->set_always( import_node           => $import_mocked );
    my $serialized_class = $wgda->serialize( 'WebGUI::Asset::Test::WGDev',
        { LastField => 'last field value' } );
    is $serialized_class, <<'END_ASSET', 'serializes classes correctly';
==== Test::WGDev =============================================================
Asset ID    : ~
Menu Title  : ~
Parent      : import_node_url
Title       : ~
URL         : ~
==== CodeField ===============================================================
~
==== HTMLField ===============================================================
~
==== TextField ===============================================================
~
==== Properties ==============================================================
properties:
  OtherField: default value
security:
  LastField: last field value

END_ASSET

    my $parent = Test::MockObject->new;
    $parent->set_always( get => 'parent_node_url' );
    my $asset = Test::MockObject::Extends->new('WebGUI::Asset::Test::WGDev');
    $asset->set_always( getParent => $parent );
    $asset->set_always(
        get => {
            assetId   => 'assetId',
            TextField => "Text\nField\nValue",
        } );
    my $serialized_asset   = $wgda->serialize($asset);
    my $original_header    = $wgda->_gen_serialize_header( ref $asset ),
        my $replace_header = $wgda->_gen_serialize_header('Test::WGDev');
    $serialized_asset =~ s/\Q$original_header/$replace_header/;
    is $serialized_asset, <<'END_ASSET', 'serializes assets correctly';
==== Test::WGDev =============================================================
Asset ID    : assetId
Menu Title  : ~
Parent      : parent_node_url
Title       : ~
URL         : ~
==== CodeField ===============================================================
~
==== HTMLField ===============================================================
~
==== TextField ===============================================================
Text
Field
Value
==== Properties ==============================================================
properties:
  OtherField: default value
security:
  LastField: ~

END_ASSET

    $wgda->unmock( '_get_property_default', 'import_node' );
}

{
    is $wgda->export_extension('Class::With::Vowels::Layout'), 'lt',
        'export_extension strips vowels';
    is $wgda->export_extension('Class::Starts::With::A::Vowel::Image'), 'img',
        '... except initial vowel';
    is $wgda->export_extension('Class::Has::Repeated::Chars::Collaboration'),
        'clbrtn', '... and collapses repeated characters';

    my $asset = bless \( my $var ), 'Class::With::Vowels::Layout';
    is $wgda->export_extension($asset), 'lt',
        'export_extension works on objects';

    is $wgda->export_extension, undef,
        'export_extension returns undef if not given class or asset';
}

{
    my $serialized_asset = <<'END_ASSET';
==== Test::WGDev =============================================================
Asset ID    : assetId
Menu Title  : ~
Parent      : parent_node_url
Title       : ~
URL         : ~
other thing : ~
==== TextField ===============================================================
Text
Field
Value
==== HTMLField ===============================================================
~
==== CodeField ===============================================================
~
==== Properties ==============================================================
properties:
  OtherField: default value
security:
  LastField: ~

END_ASSET
    my $properties = $wgda->deserialize($serialized_asset);
    is_deeply $properties,
        {
        'parent'     => 'parent_node_url',
        'menuTitle'  => undef,
        'LastField'  => undef,
        'HTMLField'  => undef,
        'CodeField'  => undef,
        'className'  => 'WebGUI::Asset::Test::WGDev',
        'TextField'  => "Text\nField\nValue",
        'OtherField' => 'default value',
        'url'        => undef,
        'assetId'    => 'assetId',
        'title'      => undef
        },
        'asset data deserializes correctly';
    $serialized_asset = <<'END_ASSET';
==== Test::WGDev =============================================================
Asset ID    : assetId
END_ASSET
    $properties = $wgda->deserialize($serialized_asset);
    is_deeply $properties,
        {
        assetId   => 'assetId',
        className => 'WebGUI::Asset::Test::WGDev',
        },
        'asset data deserializes correctly when missing most data';
}

{
    my $called_new;
    my $passed_prop;
    Test::MockObject->fake_module(
        'WebGUI::Form::WGDevTest',
        new => sub {
            my $class   = shift;
            my $session = shift;
            $called_new  = 1;
            $passed_prop = shift;
            my $self = Test::MockObject->new;
            $self->set_always( 'getDefaultValue', 'returned default' );
            return $self;
        },
    );
    my $returned_default = $wgda->_get_property_default( {
            defaultValue => 'passed default',
            fieldType    => 'wGDevTest',
    } );
    ok $called_new, '_get_property_default constructed correct form object';
    is $passed_prop->{defaultValue}, 'passed default',
        '... passing form correct default';
    is $returned_default, 'returned default',
        '... and returns value from ->getDefaultValue';

    lives_and {
        is $wgda->_get_property_default( { defaultValue => 'raw default' } ),
            'raw default';
    }
    '_get_property_default returns raw default for invalid field types';
    lives_and {
        is $wgda->_get_property_default( { fieldType => 'Nonexistant' } ),
            undef;
    }
    '_get_property_default returns raw default for invalid field types';
}

if (HAS_DONE_TESTING) {
    done_testing;
}

