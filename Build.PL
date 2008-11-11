use Module::Build;
my $build = Module::Build->new(
    module_name     => 'WGDev',
    license         => 'perl',
    create_readme   => 1,
    sign            => 1,
    requires => {
        'perl'          => '5.8.8',
        'File::Spec'    => 0,
        'File::Path'    => 0,
        'File::Copy'    => 0,
        'Cwd'           => 0,
        'Carp'          => 0,
        'version'       => 0,
        'DBI'           => 0,
    },
    add_to_cleanup => [
        'bin/wgd',
    ],
    PL_files => {
        'bin/wgd.PL'   => 'bin/wgd',
    },
    get_options => {
        compact => {},
    },
    script_files => [
        'bin/wgd',
    ],
);
if ($build->args('compact')) {
    $build->notes(compact => 1);
    $build->pm_files({});
}
$build->create_build_script;

