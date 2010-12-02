#!/usr/bin/perl -w

# File: milestone_feed.pl

use strict;
use lib qw(.);
use PMT;
use PMT::Milestone;
use Data::Dumper;
use XML::RSS;

my $cgi = new CGI();

eval {
    my $mid = $cgi->param('mid') || "";
    my $milestone = PMT::Milestone->retrieve($mid);

    my $items = $milestone->recent_events();

    my $rss = new XML::RSS(version => '1.0');
    $rss->channel(
                  title        => "PMT milestone feed: $milestone->{name}",
                  link         => "http://$ENV{'SERVER_NAME'}/home.pl?mode=milestone;mid=$mid",
                  description  => "all changes to this milestone",
                  );
    for my $i (@{$items}) {
        $i->{event_date_time} =~ /^(\d.*?)\./;
        my $date = $1;
        $rss->add_item(title => "$i->{title} ($i->{status})",
                       link => "http://$ENV{'SERVER_NAME'}/item/$i->{iid}/",
                       description => "<small>$date</small><br />$i->{comment}<br />" .
                                      "<small>owner: <a href=\"" . 
                                      "http://$ENV{'SERVER_NAME'}/home.pl?mode=user;" .
                                      "username=$i->{owner}\">$i->{owner}</a></small>" .
                                      "<small> / assigned to: <a href=\"" .
                                      "http://$ENV{'SERVER_NAME'}/home.pl?mode=user;" .
                                      "username=$i->{assigned_to}\">$i->{assigned_to}" .
                                      "</a></small>"
                      );
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


