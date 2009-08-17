use lib 'inc';
use WGDev::Builder;
my $build = WGDev::Builder->new(
    module_name        => 'WGDev',
    license            => 'perl',
    dynamic_config     => 0,
    create_license     => 1,
    create_makefile_pl => 'traditional',
    create_readme      => 1,
    sign               => 1,
    requires           => {
        'perl'             => '5.8.8',
        'App::Prove'       => 0,
        'Config::JSON'     => 0,
        'Cwd'              => 0,
        'DBI'              => 0,
        'File::Copy'       => 0,
        'File::Find'       => 0,
        'File::Path'       => 0,
        'File::Spec'       => 0,
        'File::Temp'       => 0,
        'Getopt::Long'     => 0,
        'JSON'             => '2.00',
        'Pod::Html'        => 0,
        'Pod::Perldoc'     => 0,
        'Pod::Usage'       => 0,
        'Text::ParseWords' => 0,
        'version'          => 0,
        'Exception::Class' => 0,
    },
    recommends          => {
        'Term::ANSIColor'  => 0,
    },
);
$build->create_build_script;

