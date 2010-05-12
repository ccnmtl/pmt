#!/usr/bin/perl -w

# File: user_feed.pl
# Time-stamp: <Thu Jun  5 17:12:57 2003>

use strict;
use lib qw(.);
use PMT;
use Data::Dumper;
use XML::RSS;

my $cgi = new CGI();
eval {
    my $username = $cgi->param('username') || "";
    my $user = PMT::User->retrieve($username);

    my $items = $user->home()->{items};
    my $rss = new XML::RSS(version => '1.0');
    $rss->channel(
                  title        => "PMT user feed for $username",
                  link         => "http://$ENV{'SERVER_NAME'}/pmt2/",
                  description  => "the items that appear on your PMT homepage",
                  );
    for my $i (@{$items}) {
        $i->{description} ||= "";
        $rss->add_item(title => "$i->{type}: $i->{title} ($i->{project})",
                       link => "http://$ENV{'SERVER_NAME'}/item/$i->{iid}/",
                       description => "<b>status:</b> $i->{status}, <b>target date:</b> $i->{target_date}<br />$i->{description}");
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


