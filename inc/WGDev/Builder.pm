package WGDev::Builder;
use strict;
use warnings;

use 5.008008;
our $VERSION = '0.0.2';

use Module::Build ();
BEGIN { our @ISA = qw(Module::Build) }

use File::Spec     ();
use File::Path     ();
use File::Basename ();
##no critic (RequireCarping ProhibitMagicNumbers)

sub new {
    my $class   = shift;
    my %options = @_;
    $options{get_options}{compact} = {};
    $options{test_types}{author}   = ['.at'];
    my $self = $class->SUPER::new(%options);
    if ( $self->args('compact') ) {
        $self->notes( compact => 1 );
    }
    return $self;
}

sub ACTION_testauthor {    ##no critic (Capitalization)
    return shift->generic_test( type => 'author' );
}

# we're overriding this to use Pod::Coverage::CountParent instead of the
# default
sub ACTION_testpodcoverage {    ##no critic (Capitalization)
    my $self = shift;

    $self->depends_on('docs');

    eval {
        require Test::Pod::Coverage;
        Test::Pod::Coverage->VERSION(1.0);
        }
        or die q{The 'testpodcoverage' action requires },
        q{Test::Pod::Coverage version 1.00};

    local @INC = @INC;
    my $p = $self->{properties};
    unshift @INC, File::Spec->catdir( $p->{base_dir}, $self->blib, 'lib' );

    Test::Pod::Coverage::all_pod_coverage_ok(
        { coverage_class => 'Pod::Coverage::CountParents' } );
    return;
}

sub ACTION_dist {    ##no critic (Capitalization)
    my $self = shift;
    if ( !$self->args('compact') && !$self->notes('compact') ) {
        return $self->SUPER::ACTION_dist(@_);
    }

    my $sign = $self->sign;
    $self->sign(0);

    $self->depends_on('distdir');
    $self->sign($sign);

    my $dist_dir = $self->dist_dir;
    my $dist_build;
    $self->_do_in_dir(
        $dist_dir,
        sub {
            $dist_build = Module::Build->new_from_context( compact => [] );
            $dist_build->dispatch('build');
        } );
    my $dist_blib = File::Spec->abs2rel(
        File::Spec->rel2abs( $dist_build->blib, $dist_dir ) );
    my $result = $self->copy_if_modified(
        from => File::Spec->catfile( $dist_blib, 'script', 'wgd' ),
        to   => 'wgd-' . $self->dist_version,
    );
    $self->delete_filetree($dist_dir);
    return;
}

sub process_pm_files {
    my $self = shift;
    if ( $self->args('compact') || $self->notes('compact') ) {
        return;
    }
    return $self->SUPER::process_pm_files(@_);
}

sub process_script_files {
    my $self = shift;
    if ( $self->args('compact') || $self->notes('compact') ) {
        my $files = $self->find_script_files;
        if ( delete $files->{'bin/wgd'} ) {
            my $script = 'bin/wgd';
            my $script_dir = File::Spec->catdir( $self->blib, 'script' );
            File::Path::mkpath($script_dir);
            my $filename = File::Basename::basename($script);
            my $to_path = File::Spec->catfile( $script_dir, $filename );
            my $need_update;
            my $libs = $self->find_pm_files;
            for my $file ( $script, keys %{$libs} ) {

                if ( !$self->up_to_date( $file, $to_path ) ) {
                    $need_update = 1;
                    last;
                }
            }
            if ($need_update) {
                unlink $to_path;
                my $result = $self->copy_if_modified(
                    from => $script,
                    to   => $to_path,
                );
                my $mode = ( stat $to_path )[2];
                chmod $mode | oct(222), $to_path;
                open my $fh, '>>', $to_path
                    or die "Can't modify $to_path : $!\n";

                $self->append_libs( $fh, $libs );

                close $fh or die "Unable to write $to_path : $!\n";
                chmod $mode, $to_path;
                if ( !$self->is_vmsish ) {
                    $self->fix_shebang_line($to_path);
                }
                $self->make_executable($to_path);
            }
        }
        $self->script_files($files);
    }
    return $self->SUPER::process_script_files;
}

sub append_libs {
    my $self = shift;
    my $fh   = shift;
    my $libs = shift;

    print {$fh} "BEGIN {\n";
    for my $pm_file ( sort keys %{$libs} ) {
        $pm_file =~ s{\Alib/}{}msx;
        print {$fh} "    \$INC{'$pm_file'} = __FILE__;\n";
    }
    print {$fh} "}\n\n";

    my $end_data = q{};
    for my $pm_file ( sort keys %{$libs} ) {
        my $past_end;
        print {$fh} "{\n";
        ##no critic (RequireBriefOpen)
        open my $in, q{<}, $pm_file or die "Unable to read $pm_file : $!\n";
        while ( my $line = <$in> ) {
            if ( $line =~ /^__(?:END|DATA)__$/msx ) {
                $past_end = 1;
                next;
            }
            if ($past_end) {
                $end_data .= $line;
            }
            else {
                print {$fh} $line;
            }
        }
        close $in or die "Unable to read $in : $!\n";
        print {$fh} "}\n";
    }
    if ($end_data) {
        print {$fh} "__END__\n" . $end_data;
    }
    return;
}

1;

