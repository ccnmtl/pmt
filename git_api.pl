#!/usr/bin/perl -w

# File: view.pl
# Time-stamp: <Tue Aug 16 16:14:04 2005>
#
# anonymous view of an item.
use strict;

use lib qw(.);
use PMT;
use PMT::Common;
use Data::Dumper;

my $cgi = new CGI();

my $iid  = $cgi->param('iid') || "";
my $email = $cgi->param('email');
if ($email !~ /\@/) {
    $email = $email . "\@columbia.edu";
}

my @users = PMT::User->search(email=>$email);
my $user = $users[2];
my $item = PMT::Item->retrieve($iid);

my $status = $cgi->param('status') || "";

my $resolve_time = $cgi->param('resolve_time') || "";
my $comment = $cgi->param('comment') || "";

if ($status eq "FIXED") {
    $item->status("RESOLVED");
    $item->r_status("FIXED");
    $item->add_event("RESOLVED",$comment,$user);
    $item->update_email($item->type . " #" . $item->iid . " " . $item->title . " updated",
			"$comment---------------\n" . dehtml($comment),
			$user->username);
} else {
    if ($comment ne "") {
	$item->add_comment($user,$comment);
	$item->update_email("comment added to " . $item->type . " #" . $item->iid . " " . $item->title,
			    $comment,$user->username);
    }
}
if ($resolve_time ne "") {
    $item->add_resolve_time($user,$resolve_time);
}
$item->touch();
print $cgi->header(), "OK";

