use strict;
use warnings;

use Test::More 'no_plan';
use Test::NoWarnings;
use Test::MockObject;
use Test::Exception;

use File::Spec::Functions qw(catdir catfile catpath rel2abs splitpath);
use Cwd qw(realpath cwd);

use constant TEST_DIR => catpath( ( splitpath(__FILE__) )[ 0, 1 ], '' );
use lib catdir( TEST_DIR, 'lib' );

BEGIN {
    Test::MockObject->fake_module('WebGUI::Session');
    Test::MockObject->fake_module('WebGUI::Asset');
    Test::MockObject->fake_module('WebGUI::Asset::FakeAsset');
}

use WGDev::Asset ();

my $session = Test::MockObject->new;
$session->set_isa('WebGUI::Session');

my $id = Test::MockObject->new;
$session->set_always('id', $id);

my $wgda = WGDev::Asset->new($session);
isa_ok $wgda, 'WGDev::Asset';

{
    no warnings qw(redefine once);
    my @params;
    local *WebGUI::Asset::getRoot = sub {
        @params = @_;
        return 'magic';
    };
    is $wgda->root, 'magic', 'root method returns WebGUI::Asset->getRoot';
    is_deeply \@params, ['WebGUI::Asset', $session], '... passing in session';
}

{
    no warnings qw(redefine once);
    my @params;
    local *WebGUI::Asset::getImportNode = sub {
        @params = @_;
        return 'magic';
    };
    is $wgda->import_node, 'magic', 'import_node method returns WebGUI::Asset->getImportNode';
    is_deeply \@params, ['WebGUI::Asset', $session], '... passing in session';
}

{
    no warnings qw(redefine once);
    my @params;
    local *WebGUI::Asset::getDefault = sub {
        @params = @_;
        return 'magic';
    };
    is $wgda->default_asset, 'magic', 'default_asset method returns WebGUI::Asset->getDefault';
    is_deeply \@params, ['WebGUI::Asset', $session], '... passing in session';
}

{
    no warnings qw(redefine once);
    my @params;
    local *WebGUI::Asset::newByUrl = sub {
        @params = @_;
        return 'magic';
    };
    is $wgda->by_url('url'), 'magic', 'by_url method returns WebGUI::Asset->newByUrl';
    is_deeply \@params, ['WebGUI::Asset', $session, 'url'], '... passing in session and url';
}

{
    no warnings qw(redefine once);
    my @params;
    local *WebGUI::Asset::new = sub {
        @params = @_;
        return 'magic';
    };
    is $wgda->by_id('asset-id'), 'magic', 'by_id method returns WebGUI::Asset->new';
    is_deeply \@params, ['WebGUI::Asset', $session, 'asset-id'], '... passing in session and asset ID';
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
    lives_and { is $wgda->find('asset'), $by_id } 'find method finds valid asset by asset id';

    $by_id = Test::MockObject->new;
    throws_ok { $wgda->find('asset') } 'WGDev::X::AssetNotFound', 'find method throws error if non-asset found';

    $by_id = 'scalar';
    throws_ok { $wgda->find('asset') } 'WGDev::X::AssetNotFound', 'find method throws error if non-object found';

    undef $by_id;
    throws_ok { $wgda->find('asset') } 'WGDev::X::AssetNotFound', 'find method throws error if nothing found';

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

lives_and { is $wgda->validate_class('WebGUI::Asset::Template'), 'WebGUI::Asset::Template' }
    'validate_class accepts fully qualified class names';

lives_and { is $wgda->validate_class('Template'), 'WebGUI::Asset::Template' }
    'validate_class accepts short class names';

lives_and { is $wgda->validate_class('::Template'), 'WebGUI::Asset::Template' }
    'validate_class accepts prefixed short class names';

lives_and { is_deeply [$wgda->validate_class('WebGUI::Asset::Template')], ['WebGUI::Asset::Template', 'Template'] }
    'validate_class returns full class and short class in array context';

throws_ok { $wgda->validate_class('non-word characters') } 'WGDev::X::BadAssetClass',
    'validate_class rejects invalid class names';


