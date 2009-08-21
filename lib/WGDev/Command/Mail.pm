package WGDev::Command::Mail;
use strict;
use warnings;
use 5.008008;

our $VERSION = '0.2.0';

use WGDev::Command::Base;
use Carp;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

sub config_options {
    return qw(
        queue|q
        toUser=s
        toGroup=s
        subject|s=s
        from=s
        cc=s
        bcc=s
        replyTo=s
        returnPath=s
        contentType=s
        messageId=s
        inReplyTo=s
        isInbox
        verbose|v
    );
}

sub process {
    my $self = shift;
    my $wgd  = $self->wgd;

    my $session = $wgd->session();
    my $verbose = $self->option('verbose');

    if (!$self->arguments) {
        my $count = $session->db->quickScalar('select count(*) from mailQueue');
        print "Mail queue has @{[ $count || 'no' ]} messages\n";
        return 1;
    }
    
    my $to = join q{,}, $self->arguments;
    my $body;
    while (my $line = <STDIN>) {
        last if $line eq ".\n";
        $body .= $line;
    }
    
    # We are going to pass pretty much all options into WebGUI::Mail::Send::create
    my $options = $self->{options};
    $options->{to} = $to;
    
    # Pull out the non-api options (or short-hands)
    if (my $s = delete $options->{s}) {
        $options->{subject} = $s;
    }
    my $queue = delete $options->{q} || delete $options->{queue};
    
    if ($verbose) {
        print $queue ? "Queueing" : "Sending", " message:\n";
        print $body;
        print "Using the following options:\n";
        print Data::Dumper::Dumper($self->{options});
        print "SMTP Server: " . $session->setting->get("smtpServer") . "\n";
        print "emailToLog: 1\n" if $session->config->get('emailToLog');
    }
    require WebGUI::Mail::Send;
    my $msg = WebGUI::Mail::Send->create($session, $options );
    croak "Unable to instantiate message" unless $msg;
    
    $msg->addText($body);
    
    my $status;
    if ($queue) {
        $status = $msg->queue;
    } else {
        $status = $msg->send;
    }
    print "Status: $status\n" if $verbose;
    return 1;
}

1;

__END__

=head1 NAME

WGDev::Command::Mail - Sends emails via the L<WebGUI::Mail::Send> API

=head1 SYNOPSIS

    wgd mail
    wgd mail -s test pat@patspam.com

=head1 DESCRIPTION

Sends emails via the L<WebGUI::Mail::Send> API

If run with no arguments, displays the number of messages currently in the mail queue.

Accepts all options supported by L<WebGUI::Mail::Send::create>, plus the following additional items:

=head1 OPTIONS

=over 8

=item C<-q> C<--queue>

Add the message to the queue rather than sending it immediately

=item C<-s>

Short-hand for C<--subject>

=back

=head1 AUTHOR

Patrick Donelan <pat@patspam.com>

=head1 LICENSE

Copyright (c) Patrick Donelan.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

