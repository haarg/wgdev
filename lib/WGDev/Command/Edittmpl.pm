package WGDev::Command::Edittmpl;
use strict;
use warnings;

our $VERSION = '0.1.0';

use WGDev::Command::Base;
our @ISA = qw(WGDev::Command::Base);

sub option_config {qw(
    command=s
)}

sub process {
    require WebGUI::Asset;
    require File::Temp;
    my $self = shift;
    my $wgd = $self->wgd;

    my @files;
    for my $url (@_) {
        my $template = WebGUI::Asset->newByUrl($wgd->session, $url);
        unless ($template && $template->isa('WebGUI::Asset::Template')) {
            warn "$url is not a valid template!\n";
            next;
        }
        my $tmpl_data = $template->get;
        $tmpl_data->{headBlock} =~ s/\r\n?/\n/g;
        $tmpl_data->{template} =~ s/\r\n?/\n/g;
        my ($fh, $filename) = File::Temp::tempfile();
        binmode $fh, ':utf8';
        print {$fh} <<END_FILE;
~~~META~~~
Title:      $tmpl_data->{title}
URL:        $tmpl_data->{url}
Namespace:  $tmpl_data->{namespace}
Asset ID:   $tmpl_data->{assetId}
~~~HEAD~~~
$tmpl_data->{headBlock}
~~~BODY~~~
$tmpl_data->{template}
END_FILE
        close $fh;
        push @files, {
            template    => $template,
            filename    => $filename,
            mtime       => (stat($filename))[9],
        };
    }
    unless (@_) {
        die "No templates to edit!\n";
    }

    my $command = $self->option('command') || $ENV{EDITOR} || 'vi';
    system($command . ' ' . join(' ', map { $_->{filename} } @files));

    my $versionTag;
    for my $file (@files) {
        if ((stat($file->{filename}))[9] <= $file->{mtime}) {
            warn "Skipping " . $file->{template}->get('url') . ", not changed.\n";
            unlink $file->{filename};
            next;
        }
        $versionTag ||= do {
            my $vt = WebGUI::VersionTag->getWorking($wgd->session);
            $vt->set({name=>"Template Filter"});
            $vt;
        };
        open my $fh, '<', $file->{filename} || next;
        my $tmpl_text = do { local $/; <$fh> };
        close $fh;
        unlink $file->{filename};
        if ($tmpl_text =~ /\n~~~HEAD~~~\n(.*)\n~~~BODY~~~\n(.*)\n\z/ms) {
            my ($head, $body) = ($1, $2);
            if ($head && $body) {
                $file->{template}->addRevision({
                    headBlock   => $head,
                    template    => $body,
                });
            }
        }
    }

    if ($versionTag) {
        $versionTag->commit;
    }
    return 1;
}

1;

__END__

=head1 NAME

WGDev::Command::Edittmpl - Edits templates by URL

=head1 DESCRIPTION

Exports templates to temporary files, then opens them in your prefered editor.
If modifications are made, the templates are updated.  Only changes to the
template and head block are used - any modifications to the other fields are
ignored.

arguments:
    <template urls> list of template urls
    --command       Command to be executed.  If not specified, uses the EDITOR
                    environment variable.  If that is not specified, uses vi.

=cut

