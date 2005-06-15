#!/usr/bin/perl -wT

# File: forum.pl
# Time-stamp: <Mon May 20 17:47:15 2002>
#
# Copyright (C) 2002 by anders pearson
#
# Author: anders pearson
#
# Description:
# 
use strict;
use lib qw(.);
use PMT;
use Forum;
use PMT::Common;

my $pmt = PMT->new();
my $cgi = new CGI();

eval {
    my $username = $cgi->cookie('pmtusername') || "";
    my $password = $cgi->cookie('pmtpassword') || "";

    my $user = new PMT::User($username);
    $user->validate($username,$password);
    my $pid = $cgi->param('pid') || "";
    my $forum = new Forum($username,$pmt);
    my $template = template("forum.tmpl");
    if($pid) {
	$template->param(posts => $forum->recent_project_posts($pid));
	$template->param(logs => $forum->recent_project_logs($pid));
	$template->param(items => $forum->recent_project_items($pid));
	$template->param(pid => $pid);
    } else {
	$template->param(posts => $forum->recent_posts());
	$template->param(logs => $forum->recent_logs());
	$template->param(items => $forum->recent_items());
    }
    $template->param(page_title => 'forum');
    $template->param($user->menu());
    $template->param(forum_mode => 1);
    print $cgi->header(-charset => 'utf-8'), $template->output();
};

if($@) {
    my $E = $@;
    if($E->isa('Error::Simple')) {
	if ($E->isa('Error::NO_USERNAME') || 
	    $E->isa('Error::NO_PASSWORD') ||
	    $E->isa('Error::AUTHENTICATION_FAILURE')) {
	    print $cgi->redirect('login.pl');
	} else {
	    print $cgi->header(), "<h1>error:</h1><p>$E->{-text}</p>";
	}
    } else {
	die "unknown error: $E";
    }
}

exit(0);
