#!/usr/bin/perl -w

# File: forum_feed.pl

use strict;
use lib qw(.);
use PMT;
use Data::Dumper;
use XML::RSS;
use PMT::Common;
use URI::Escape;
use CGI;

my $cgi = new CGI();
my $pmt = PMT->new();
eval {
    my $tag          = $cgi->param('tag') || "";
    my $pid          = $cgi->param('pid') || "";
    my $only_items   = $cgi->param('items_only') || "";
    my $only_posts   = $cgi->param('posts_only') || "";

    my $escapedtag = uri_escape($tag);
    my $url = "tag/$escapedtag/";
    if ($pid ne "") {
        $url .= "user/project_$pid/";
    }
    my $r = tasty_get($url);

    my $rss = new XML::RSS(version => '1.0');
    $rss->channel(
	title => "PMT Tag feed for $tag",
	link => "http://$ENV{'SERVER_NAME'}/tag_feed.pl?tag=$escapedtag",
	);

    foreach my $el (@{$r->{items}}) {
        my $item = $el->{item};
        my @parts = split "_", $item;
        my $id = $parts[1];
        if ($parts[0] eq "item") {
	    if ($only_posts eq "") {
		my $i = PMT::Item->retrieve($id);
		if ($i) {
		    my ($type,$title,$project,
			$status,$target_date,$description) = ($i->type,$i->title,$i->mid->pid->name,
							      $i->status,$i->target_date,$i->description);
		    $rss->add_item(
			title => "$type: $title [$project]",
			link => "http://$ENV{'SERVER_NAME'}/item/$id/",
			description => "<b>status:</b> $status, <b>target date:</b> $target_date<br />$description",
			);
		}
	    }
        }
        if ($parts[0] eq "node") {
	    if ($only_items eq "") {
		my $n = PMT::Node->retrieve($id);
		if ($n) {
		    my ($subject,$author,$body) = ($n->subject,$n->author->fullname,$n->body);
		    $rss->add_item(
			title => "$subject",
			link => "http://$ENV{'SERVER_NAME'}/home.pl?mode=node;nid=$id",
			description => "<b>$author</b><br />$body"
			);
		}
	    }
        }
    }
    print $cgi->header('text/xml'), $rss->as_string();
};

if ($@) {
    print $cgi->header(), "<h1>error</h1><p>please report this.</p>";
}
