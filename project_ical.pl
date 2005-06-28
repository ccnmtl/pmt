#!/usr/bin/perl -w

# File: project_ical.pl
# Time-stamp: <Fri Mar 28 15:52:17 2003>
#
# Copyright (C) 2003 by 

use strict;
use lib qw(.);
use PMT;
use Net::ICal;
use PMT::Project;

my $cgi = CGI->new();

eval {
    my $pid = $cgi->param('pid') || die "no pid";

    my $project = PMT::Project->retrieve($pid);
    my @milestones = ();
    foreach my $m ($project->milestones()) {
	my $date = $m->target_date;
	$date =~ s/-//g;
	my $event = new Net::ICal::Event(dtstart => new Net::ICal::Time(ical => $date),
					 summary => $m->name,
					 categories => "PMT -- ".$project->name),
					 description => $m->description);
	push @milestones, $event;
    }
    my $cal = new Net::ICal::Calendar( events => \@milestones);
    my $string = $cal->as_ical;
    print $cgi->header("text/calendar");
    $string =~ s/DTSTART:(\d+)Z/DTSTART;VALUE=DATE:$1/g;
    print $string;

};
