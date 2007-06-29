#!/usr/bin/perl -w

# File: external_add_item.pl
# Time-stamp: <Mon Aug 22 16:50:17 2005>

use strict;
use lib qw(.);
use PMT;
use PMT::Common;

my $cgi = new CGI();

my $pid         = $cgi->param('pid');
my $title       = $cgi->param('title')       || "external issue report";
my $description = $cgi->param('description') || "no description";
my $email       = $cgi->param('email')       || "no email";
my $name        = $cgi->param('name')        || "anonymous";
my $type        = $cgi->param('type')        || "bug";
my $redirect_url= $cgi->param('redirect_url') || "";
my $debug_info  = $cgi->param('debug_info')  || "";
my $append_iid  = $cgi->param('append_iid') || "";

if ($debug_info) {
    $description .= "\n-----\n\nDEBUG INFO:\n$debug_info\n";
}

$description .= "\n-----\n\nsubmitted by $name <$email>\n";

my $project = PMT::Project->retrieve($pid);
my $mid     = $cgi->param('mid') || $project->upcoming_milestone();

my $assignee = $cgi->param('assigned_to') || $project->caretaker->username;
my $owner    = $cgi->param('owner')       || $project->caretaker->username;

my $priority     = $cgi->param('priority') || "1";
my $url          = escape($cgi->param('url')) || "";

my @tags     = $cgi->param('tags');
my @clients      = $cgi->param('clients');

my $target_date = $cgi->param('target_date') || "";
my $estimated_time = $cgi->param('estimated_time') || "";

if($target_date =~ /(\d{4}-\d{2}-\d{2})/) {
    $target_date = $1;
} else {
    my $milestone = PMT::Milestone->retrieve($mid);
    $target_date = $milestone->target_date;
}
if ($estimated_time =~ /^(\d+)$/) {
    $estimated_time .= "h";
}
if ($estimated_time eq "") {
    $estimated_time = "0h";
}

my @new_tags;
foreach my $k (@tags) {
    push @new_tags, $k unless $k eq "";
}

my @new_clients;
foreach my $client (@clients) {
    push @new_clients, $client unless $client eq "";
}

my %item = (type           => $type,
            pid            => $pid,
            mid            => $mid,
            title          => $title,
            assigned_to    => $assignee,
            owner          => $owner,
            priority       => $priority,
            target_date    => $target_date,
            url            => $url,
            description    => $description,
            tags           => \@new_tags,
            clients        => \@new_clients,
            estimated_time => $estimated_time);

my $pmt = new PMT();
my $iid = $pmt->add_item(\%item);

# since the PMT normally won't send an email to the assignee if the assignee and owner
# are the same, we have to override that here to ensure that the assignee is notified
if ($assignee eq $owner) {
    my $item    = PMT::Item->retrieve($iid);
    my $body    = $item->email_message_body();
    my $u       = PMT::User->retrieve($assignee);
    my $to      = $u->email;
    my $subject = $item->email_subject("new external item added");
    my $from    = $u->email;
    $item->send_email($body,$subject,$from,$to)
}

if ($redirect_url) {
    if ($append_iid) {
        $redirect_url .= "iid=$iid";
    }
    print $cgi->redirect($redirect_url);
} else {
    print $cgi->redirect("view.pl?iid=$iid");
}

