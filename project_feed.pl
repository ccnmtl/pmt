#!/usr/bin/perl -wT

# File: project_feed.pl
# Time-stamp: <Fri Jun  6 13:39:23 2003>

use strict;
use lib qw(.);
use PMT;
use PMT::Project;
use Data::Dumper;
use XML::RSS;

my $cgi = new CGI();

eval {
    my $pid = $cgi->param('pid') || "";
    my $project = PMT::Project->retrieve($pid);
    
    my $items = $project->recent_events();

    my $rss = new XML::RSS(version => '1.0');
    $rss->channel(
		  title        => "PMT project feed",
		  link         => "http://pmt.ccnmtl.columbia.edu/home.pl?mode=project;pid=$pid",
		  );
    for my $i (@{$items}) {
	$rss->add_item(title => "$i->{title} ($i->{status})",
		       link => "http://pmt.ccnmtl.columbia.edu/item.pl?iid=$i->{iid}",
		       description => "$i->{comment}");
    }

    print $cgi->header('text/xml'), $rss->as_string();

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
