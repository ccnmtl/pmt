#!/usr/bin/perl -wT

# File: searchForum.pl
# Time-stamp: <Mon Apr 26 15:25:32 2004>
#
# Copyright (C) 2004 by anders pearson
#
# Author: pojen deng
#
# Description:
#
use strict;
use lib qw(.);
use PMT;
use PMT::Common;
use Forum;

my $pmt = PMT->new();
my $cgi = new CGI();

eval {
    my $username = $cgi->cookie('pmtusername') || "";
    my $password = $cgi->cookie('pmtpassword') || "";

    my $user = new PMT::User($username);
    $user->validate($username,$password);
    my $forum = new Forum($username, $pmt);
    my $template = template("searchForum.tmpl");

    my $search = $cgi->param('searchWord') || "";

    my $sql = qq{select n.nid,n.subject,n.body,n.replies,
		 n.project,n.author,u.fullname,n.added,
		 n.modified
		 from nodes n, users u
		 where u.username = n.author
		 AND (upper(n.body) like upper(?) OR upper(n.subject) like
                 upper(?))
		 order by added desc;};
    my $result = $pmt->s($sql,["%$search%","%$search%"], ['nid','subject','body',
			      'replies','pid','project',
			      'author','author_fullname',
			      'added','modified']);
    $template->param(result => $result);
    $template->param(page_title => 'Search Forum');
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
