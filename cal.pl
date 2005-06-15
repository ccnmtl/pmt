#!/usr/bin/perl -w

# File: cal.pl
# Time-stamp: <Thu Apr 11 11:07:46 2002>
#
# Copyright (C) 2002 by anders pearson
#
# Author: anders pearson
#
# Description:
#  generates a popup calendar
use strict;
use CGI;
use HTML::CalendarMonth;
use HTML::Template;

my @month_names = qw(January February March April May
		     June July August September October
		     November December);

my $cgi = new CGI;
my ($start_year,$start_month,$start_day) = ("","","");
my $start = $cgi->param('start') || "";
if($start =~ /(\d{4})-(\d{2})-(\d{2})/) {
    # we've got an ISO formatted date to 
    # start with
    ($start_year,$start_month,$start_day) = ($1,$2,$3);
    $start = 1;
} else {
    $start = 0;
}

# quick check that the start date is legal
if($start_month || $start_day || $start_year) {
    if($start_month > 12) {
	# illegal month. 
	# see if maybe month and day are switched
	if($start_day <= 12) {
	    ($start_month,$start_day) = ($start_day,$start_month);
	} else {
	    # totally illegal date. screw it.
	    $start_month = "";
	    $start_day = "";
	}
    }
}

my @stuff = localtime(time);
my $month = $start_month || $cgi->param('month') || $stuff[4] + 1;
my $month_name = $month_names[$month - 1];
my $year  = $start_year || $cgi->param('year')  || $stuff[5] + 1900;

my $next_year = $year + 1;
my $prev_year = $year - 1;
my $next_month = ($month == 12) ? 1 : $month + 1;
my $prev_month = ($month == 1) ? 12 : $month - 1;
my $next_month_year = ($month == 12) ? $next_year : $year;
my $prev_month_year = ($month == 1) ? $prev_year : $year;

$month = sprintf("%02d",$month);
my $c = HTML::CalendarMonth->new( month => $month, year => $year );

my $cal_html = $c->as_HTML;
$cal_html =~ s/<table[^>]+>/<table border="0" cellpadding="1" cellspacing="0" width="100%">/;
$cal_html =~ s/<td([^>]*>[a-zA-Z]+)<\/td>/<th$1<\/th>/g;
$cal_html =~ s/<td([^>]*)>$year<\/td>/<th$1><a href="cal.pl?year=$prev_year;month=$month">&lt;<\/a>$year<a href="cal.pl?year=$next_year;month=$month">&gt;<\/a><\/th>/;
$cal_html =~ s/<td[^>]+>/<td>/g;
$cal_html =~ s/td>(\d{1,2})<\/td/"td><a href=\"javascript:setDate('$year-$month-".sprintf("%02d",$1)."');\">".sprintf("%02d",$1)."<\/a><\/td"/eg;
$cal_html =~ s/$month_name/<a href="cal.pl?month=$prev_month;year=$prev_month_year">&lt;<\/a>$month_name<a href="cal.pl?month=$next_month;year=$next_month_year">&gt;<\/a>/;
$cal_html =~ s/colspan=5/colspan=4/;
$cal_html =~ s/colspan=2/colspan=3/;
if(1 == $start) {
    $cal_html =~ s/td>(<a[^>]+>)$start_day</td class="startday">$1$start_day<\/span></;
}

my $template = new HTML::Template(filename => "templates/cal.tmpl",
				  die_on_bad_params => 0);
$template->param(cal => $cal_html,
		 next_year => $next_year,
		 prev_year => $prev_year,
		 next_month => $next_month,
		 prev_month => $prev_month,
		 next_month_year => $next_month_year,
		 prev_month_year => $prev_month_year,
		 month => $month,
		 year => $year,
);
print $cgi->header(), $template->output;
