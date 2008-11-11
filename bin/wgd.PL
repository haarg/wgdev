use strict;
use warnings;

use Module::Build;
use Module::Find ();
use File::Spec;
use File::Copy ();

my $build = Module::Build->resume;

my $outfile = shift;
open my $fh, '>', $outfile or die "Unable to open $outfile - $!!\n";
if (!$build->notes('compact')) {
    print {$fh} <<'END_FILE';
#!/usr/bin/env perl
use WGDev::Command ();
WGDev::Command->run(@ARGV);
END_FILE
}
else {
    print {$fh} <<'END_FILE';
#!/usr/bin/env perl
WGDev::Command->run(\@ARGV);
BEGIN {
END_FILE

    my @module_files;
    open my $man_fh, '<', 'MANIFEST' or die "Unable to open MANIFEST - $!!\n";
    while (my $line = <$man_fh>) {
        next
            unless $line =~ /^\s*([^\s#]\S*)/;
        my $file = $1;
        next
            unless $file =~ m{^lib/};
        push @module_files, $file;
        $file =~ s{^lib/}{};
        print {$fh} "    \$INC{'$file'} = __FILE__;\n";
    }
    close $man_fh;
    print {$fh} "}\n\n";

    for my $module (@module_files) {
        print {$fh} "{\n";
        open my $in, '<', $module;
        while (my $line = <$in>) {
            next
                if $line =~ /^__(?:END|DATA)__$/ms;
            print {$fh} $line;
        }
        close $in;
        print {$fh} "}\n";
    }
    close $fh;
}

chmod 0755, $outfile;

1;

