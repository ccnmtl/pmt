#!/usr/bin/perl -wT

# File: node.pl
# Time-stamp: <Fri May 17 14:44:01 2002>
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
    my $nid = $cgi->param('nid') || "";
    if($nid =~ /(\d+)/) {
	$nid = $1;
    } else {
	throw Error::NO_NID "no nid specified";
    }

    my $username = $cgi->cookie('pmtusername') || "";
    my $password = $cgi->cookie('pmtpassword') || "";

    my $user = new PMT::User($username);
    $user->validate($username,$password);

    my $forum = new Forum($username,$pmt);
    my $template = template("node.tmpl");
    $template->param($forum->node($nid));
    $template->param($user->menu());
    $template->param(page_title => "Forum Node: " . $template->param('subject'));
    print $cgi->header(-charset => 'utf-8'), $template->output();
};
if($@) {
    my $E = $@;
    if($E->isa('Error::Simple')) {
	if ($E->isa('Error::NO_USERNAME') || 
	    $E->isa('Error::NO_PASSWORD') ||
	    $E->isa('Error::AUTHENTICATION_FAILURE')) {
	    print $cgi->redirect('login.pl');
	} elsif ($E->isa('Error::NO_NID')) {
	    print $cgi->redirect('home.pl');
	} elsif ($E->isa('Error::NO_SUCH_NODE')) {
	    print $cgi->header(), "no nodes were found with that nid";
	} else {
	    print $cgi->header(), "<h1>error:</h1><p>$E->{-text}</p>";
	}
    } else {
	die "unknown error: $E";
    }
}

exit(0);
