package WGDev::Command::Page::Load;

# ABSTRACT: List WebGUI assets
use strict;
use warnings;
use 5.008008;
use Time::HiRes;
use Exception::Class;

use constant HEADER_FORMAT => "%-22s\t%12s\t%s\n";
use constant ASSET_FORMAT  => "%22s\t%12.4f\t%s\n";

use constant STAT_MODE => 2;
use constant STAT_UID  => 4;
use constant STAT_GID  => 5;

use parent qw(WGDev::Command::Base);

sub config_options {
    return qw(
    );
}

sub process {
    my $self    = shift;
    my $wgd     = $self->wgd;
    my $session = $wgd->session;
    open( my $null, ">:utf8", "/dev/null" );
    $session->output->setHandle($null);

    my $cache_dir = $self->find_cache_dir;
    my ($cache_mode, $cache_uid, $cache_gid);
    if ($cache_dir && -e $cache_dir) {
        ( $cache_mode, $cache_uid, $cache_gid )
            = ( stat $cache_dir )[ STAT_MODE, STAT_UID, STAT_GID ];
    }
    else {
        $cache_mode = oct 755;
        $cache_uid = $>;
        $cache_gid = $);
    }
    my $permissive_umask = oct 7777 & ~$cache_mode;
    my $initial_umask = umask $permissive_umask;

    # set effective UID and GID, fail silently
    local ( $>, $) ) = ( $cache_uid, $cache_gid );

    my $error;

    my @parents = $self->arguments;
    PARENT:
    while ( my $parent = shift @parents ) {
        my $asset;
        if ( !eval { $asset = $wgd->asset->find($parent) } ) {
            warn "wgd page-load: $parent: No such asset\n";
            $error++;
            next;
        }
        my %hidden;
        if ( $asset->get('assetsToHide') ) {
            %hidden = map { $_ => 1 } split "\n", $asset->get('assetsToHide');
        }
        printf HEADER_FORMAT, 'Asset ID', 'Render Time', 'URL';
        my $child_iter = $asset->getLineageIterator(
            ['children'],
            {
                $self->option('notPage')
                ? ()
                : ( excludeClasses => ['WebGUI::Asset::Wobject::Layout'] ),
            } );
        my $children_time = 0;
        $session->asset($asset);
        CHILD:
        while ( 1 ) {
            my $child = eval { $child_iter->(); };
            if ( my $e = Exception::Class->caught() ) {
                print "\tbad asset: ".$e->full_message ."\n";
                next CHILD;
            }
            if (! defined $child) {
                last CHILD;
            }
            next CHILD if $hidden{ $child->getId };
            my $t = [Time::HiRes::gettimeofday];
            eval { my $junk = $child->view };
            my $rendering = Time::HiRes::tv_interval($t);
            printf ASSET_FORMAT, $child->getId, $rendering,
                $child->get('url');
            $children_time += $rendering;
        }
        eval { my $junk = $asset->prepareView };
        my $t = [Time::HiRes::gettimeofday];
        eval { my $junk = $asset->view };
        my $parent_time = Time::HiRes::tv_interval($t);
        printf "%22s\t%12.4f\t%s\n", $asset->getId, $children_time,
            "children time, total";
        printf "%22s\t%12.4f\t%s\n", $asset->getId, $parent_time,
            $asset->get('url');
        printf "%22s\t%12.4f\t%s\n", $asset->getId,
            $parent_time - $children_time,
            $asset->get('url') . " (exclusive)";
        $t = [Time::HiRes::gettimeofday];
        eval { my $junk = $asset->www_view };
        my $page_time = Time::HiRes::tv_interval($t);
        printf "%22s\t%12.4f\t%s\n", $asset->getId, $page_time,
            $asset->get('url') . " (inclusive)";
        printf "%22s\t%12.4f\t%s\n", $asset->get('styleTemplateId'),
            $page_time - $parent_time,
            'style template';
    }
    close($null);
    umask $initial_umask;
    return ( !$error );
}

sub find_cache_dir {
    my $self = shift;
    my $wgd  = $self->wgd;
    my $cache_type = $wgd->config->get('cacheType');
    if ( $cache_type && $cache_type eq 'WebGUI::Cache::FileCache' ) {
        my $cache_dir = $wgd->config->get('fileCacheRoot')
            || '/tmp/WebGUICache';
        return $cache_dir;
    }
    # Assume WebGUI 8 / CHI if no cache type, but with cache config
    elsif ( ( ! $cache_type || $cache_type eq 'WebGUI::Cache::CHI' )
        && ( my $cache_config = $wgd->config->get('cache') ) ) {
        # If there is a root dir, just wipe it so we don't have to load CHI
        my $cache_dir = $cache_config->{root_dir};
        return $cache_dir;
    }
    return undef;
}

=head1 SYNOPSIS

    wgd page-load <asset> [<asset> ...]

=head1 DESCRIPTION

Measure the performance of rendering assets that are children of an asset.

    Asset ID                 Render Time    URL
    OhdaFLE7sXOzo_SIP2ZUgA        0.0003    home/welcome
    IWFxZDyGhQ3-SLZhELa3qw        0.0003    home/key-benefits
    68sKwDgf9cGH58-NZcU4lg        0.0006    children time, total
    68sKwDgf9cGH58-NZcU4lg        0.0043    home
    68sKwDgf9cGH58-NZcU4lg        0.0037    home (exclusive)
    68sKwDgf9cGH58-NZcU4lg        0.0797    home (inclusive)
    Qk24uXao2yowR6zxbVJ0xA        0.0754    style template

(exclusive) includes the asset and its children

(inclusive) includes only the asset

For very small numbers, the math on "children time, total", "exclusive"
"inclusive", and style template can be off.

=cut

1;
