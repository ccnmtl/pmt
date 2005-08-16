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
my $user = PMT::User->retrieve("anonymous");
my $item = PMT::Item->retrieve($iid);

my $name    = $cgi->param('name')    || "anonymous";
my $email   = $cgi->param('email')   || "no email address given";
my $comment = $cgi->param('comment') || "";

if ("" eq $comment) {
    print $cgi->redirect("view.pl?iid=$iid");
    exit 0;
}

$comment .= "\n----\n\ncomment added by $name <$email>";

$item->add_comment($user,$comment);
$item->update_email("comment added to " . $item->type . " #" . $item->iid . " " . $item->title,
		    $comment,"anonymous");

print $cgi->redirect("view.pl?iid=$iid;message=comment%20added");
