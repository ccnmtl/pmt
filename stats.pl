#!/usr/bin/perl -w

use strict;
use lib qw(.);
use PMT::Common;
use CGI;
use PMT::Item;
use PMT::Client;
use Data::Dumper;

my $cgi = new CGI();

my $autoconfig = $cgi->param('autoconfig') || "";
my $config = $cgi->param('config') || "";
my $metric = $cgi->param('metric') || "clients";


my $dispatch = {
    items => \&items_stats,
    clients => \&clients_count,
    hours => \&hours_count,
};

print $cgi->header();
if ($autoconfig ne "") {
    print "yes";
} else {
    my $r = $dispatch->{$metric}();
    my @results = @{$r->{rows}};
    if ($config ne "") {
	print $r->{config}, "\n";
	my @results = @{$r->{rows}};
	foreach my $row (@results) {
	    print $row->[0] . ".label " . $row->[0] . "\n";
	}
    } else {
	foreach my $row (@results) {
	    print $row->[0] . " " . $row->[1] . "\n";
	}
    }
}

sub items_stats {
    my $config = qq{graph_title PMT Items
graph_vlabel items
graph_category PMT
};
    my @counts = @{PMT::Item->items_by_status()};
    my @rows = map {[$_->{status}, $_->{count}]} @counts;
    return {config => $config, rows => \@rows};
}

sub clients_count {
    my $config = qq{graph_title PMT Clients
graph_vlabel clients
graph_category PMT
};
    my @counts = @{PMT::Client->clients_by_status()};
    my @rows = map {[$_->{status}, $_->{count}]} @counts;
    return {config => $config, rows => \@rows};

}

sub hours_count {
    my $config = qq{graph_title PMT Hours
graph_vlabel hours
graph_category PMT
graph_info total hours logged
};
    my $hours = PMT::Item->total_hours_logged();
    my @rows = (["hours",$hours]);
    return {config => $config, rows => \@rows};
}
