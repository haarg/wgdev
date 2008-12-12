package WGDev::Builder;
use strict;
use warnings;

our $VERSION = '0.0.1';

use Module::Build;
use File::Spec ();
use File::Path ();
our @ISA = qw(Module::Build);

sub new {
    my $class = shift;
    my %options = @_;
    $options{get_options}{compact} = {};
    my $self = $class->SUPER::new(%options);
    if ($self->args('compact')) {
        $self->notes(compact => 1);
        my $libs = $self->find_pm_files;
        $self->notes(merge_pm_files => $libs);
        $self->pm_files({});
    }
    return $self;
}

sub process_script_files {
    my $self = shift;
    if ($self->notes('compact')) {
        my $files = $self->find_script_files;
        if (delete $files->{'bin/wgd'}) {
            my $script = 'bin/wgd';
            my $script_dir = File::Spec->catdir($self->blib, 'script');
            File::Path::mkpath( $script_dir );
            my $to_path = File::Spec->catfile($script_dir, 'wgd');
            my $need_update;
            for my $file ( $script, keys %{ $self->notes('merge_pm_files') }) {
                if (!$self->up_to_date($file, $to_path)) {
                    $need_update = 1;
                    last;
                }
            }
            if ($need_update) {
                unlink $to_path;
                my $result = $self->copy_if_modified(from => $script, to => $to_path);
                my $mode = (stat($to_path))[2];
                chmod $mode | 0222, $to_path;
                open my $fh, '>>', $to_path or die "blaarg $result $to_path : $!\n";

                print {$fh} "BEGIN {\n";
                for my $pm_file ( sort keys %{ $self->notes('merge_pm_files') } ) {
                    $pm_file =~ s{^lib/}{};
                    print {$fh} "    \$INC{'$pm_file'} = __FILE__;\n";
                }
                print {$fh} "}\n\n";

                my $end_data = '';
                for my $pm_file ( sort keys %{ $self->notes('merge_pm_files') } ) {
                    my $past_end;
                    print {$fh} "{\n";
                    open my $in, '<', $pm_file;
                    while (my $line = <$in>) {
                        if ($line =~ /^__(?:END|DATA)__$/ms) {
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
                    close $in;
                    print {$fh} "}\n";
                }
                if ($end_data) {
                    print {$fh} "__END__\n" . $end_data;
                }
                close $fh;
                chmod $mode, $to_path;
                $self->fix_shebang_line($to_path) unless $self->is_vmsish;
                $self->make_executable($to_path);
            }
        }
        $self->script_files($files);
    }
    $self->SUPER::process_script_files;
}

1;

