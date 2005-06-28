#!/usr/bin/perl -w

# File: forum_feed.pl
# Time-stamp: <Thu Jun  5 17:12:57 2003>

use strict;
use lib qw(.);
use PMT;
use Data::Dumper;
use XML::RSS;
use Forum;

my $cgi = new CGI();
my $pmt = PMT->new();
eval {
    my $forum = new Forum('');

    my $nodes = $forum->all_recent();

    my $rss = new XML::RSS(version => '1.0');
    $rss->channel(
		  title        => "PMT Forum",
		  link         => "http://pmt.ccnmtl.columbia.edu/home.pl?mode=forum",
		  );
    for my $n (@{$nodes}) {
	$rss->add_item(title => "$n->{subject}",
		       link => "http://pmt.ccnmtl.columbia.edu/home.pl?mode=node;nid=$n->{nid}",
		       description => "<b>$n->{fullname}</b><br />$n->{body}");
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
