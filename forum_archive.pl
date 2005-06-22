#!/usr/bin/perl -wT

# File: forum_archive.pl
# Time-stamp: <Tue Jun 18 14:33:44 2002>

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
    my $primary_user = PMT::User->retrieve($username);
    $primary_user->validate($username,$password);
    my $pid = $cgi->param('pid') || "";
    my $user = $cgi->param('username') || "";
    my $type = $cgi->param('type') || "posts";

    my $limit = $cgi->param('limit') || 20;
    my $offset = $cgi->param('offset') || 0;

    $limit = ($limit > 0) ? $limit : 20;
    $offset = ($offset >= 0) ? $offset : 0;

    my $forum = new Forum($username,$pmt);
    my $template = template("forum_archive.tmpl");
    my $total;
    if($pid) {
	$template->param(posts => $forum->project_posts($pid,$limit,$offset));
	$total = $forum->num_project_posts($pid);
    } elsif ($user) {
        my $u = PMT::User->retrieve($user);
        my @logs = reverse(PMT::Node->user_log_entries($user));
	$total = scalar @logs;
        my $real_limit = $limit;
        if (($offset+$limit) > $total) {
            $real_limit = $total - $offset;
        }
	$template->param(logs => [map {$_->data()}
            @logs[$offset..$offset+$real_limit-1]]);
	$type = 'logs';
    } elsif ($type eq 'logs') {
	$template->param(logs => $forum->logs($limit,$offset));
	$total = $forum->num_logs();
    } else {
	$template->param(posts => $forum->posts($limit,$offset));
	$total = $forum->num_posts();
    }

    my $next_offset = $offset + $limit;
    my $next_limit  = $limit;
    my $prev_offset = $offset - $limit;
    my $last        = 0;
    my $first       = 0;

    if($next_offset > $total) {
	$last = 1;
    }
    if($offset == 0) {
	$first = 1;
    }
    if(($next_offset + $next_limit) > $total) {
	$next_limit = $total - $next_offset;
    }

    $template->param(offset      => $offset,
		     limit       => $limit,
		     last        => $last,
		     first       => $first,
		     total       => $total,
		     type        => $type,
		     pid         => $pid,
		     user        => $user,
		     next_limit  => $next_limit,
		     next_offset => $next_offset,
		     prev_offset => $prev_offset);
	  
    $template->param(page_title => 'forum archive');
    $template->param($primary_user->menu());
    print $cgi->header(), $template->output();
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
