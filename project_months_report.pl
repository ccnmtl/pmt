#!/usr/bin/perl -wT

# Min's addition to implement monthly, quarterly, semestral, annual report
# File: project_months_report.pl
# similar to Anders' project_weekly_report.pl.
# Time-stamp: <Thu Nov 26 11:01:48 2004>

use strict;
use lib qw(.);
use PMT;
use Forum;
use PMT::Common;
use Date::Calc qw/Days_in_Month Add_Delta_YM Add_Delta_Days/;

my $pmt = new PMT();
my $cgi = new CGI();

eval {
    my $username = $cgi->cookie('pmtusername') || "";
    my $password = $cgi->cookie('pmtpassword') || "";

    my $user = new PMT::User($username);
    my $cdbi_user = CDBI::User->retrieve($username);
    $cdbi_user->validate($username,$password);

    my $pid        = $cgi->param('pid') || "";
    my $num_months = $cgi->param('num_months') || "";

    my $project = PMT::Project->retrieve($pid);

    my $syear = $cgi->param('year') || "";
    my $smonth = $cgi->param('month') || "";
    #if month is entered by user, in project_monthly_report.tmpl, we'll
    #need to make sure that user enters months between 1-12.
    #For now, any wrong number (ie >12) entered by user is 12 
#    if ($smonth ne "" && $smonth > 12) {
#       $smonth = 12;
#    }

    my ($time_period, $time_title); 
    if ($num_months == 1) {
        $time_period = "month";
	$time_title  = "Monthly";
    } elsif ($num_months == 3) {
        $time_period = "quarter";
	$time_title  = "Quarterly";
    } elsif ($num_months == 6) {
        $time_period = "semester";
	$time_title  = "Semestral";
    } elsif ($num_months == 12) {
        $time_period = "year";
	$time_title  = "Annual";
    }

    my ($sec,$min,$hour,$mday,$month,
	$year,$wday,$yday,$isdst);

    if($syear && $smonth) {
	# if the day was specified in the url, use that
	$year = $syear;
	$month = $smonth;
    } else {
	# otherwise, default to today
	($sec,$min,$hour,$mday,$month,
	 $year,$wday,$yday,$isdst) = localtime(time); 
	$year += 1900;
	$month += 1;
    }

    my ($p_year, $p_month, $p_day) = Add_Delta_YM($year, $month, 1, 0, -$num_months);
    my ($n_year, $n_month, $n_day) = Add_Delta_YM($year, $month, 1, 0, $num_months);

    my $start_day = 1;
    #calculate end day
    my ($end_year, $end_month, $end_day) = Add_Delta_Days($n_year, $n_month, $n_day, -1);
  
    my $start = $year . "-" . "$month" . "-" . $start_day;
    my $end   = $end_year . "-" . "$end_month" . "-" . $end_day;
    #Min's addition to include forum posts in reports
    my $forum = new Forum($username, $pmt);

    my $template = template("project_months_report.tmpl");
    $template->param($cdbi_user->menu());
    $template->param(
		     year => $year,
		     month => $month,
		     p_year => $p_year,
		     p_month => $p_month,
		     n_year => $n_year,
		     n_month => $n_month,
		     num_months => $num_months,
		     time_period => $time_period,
		     time_title => $time_title,
		     );
    $template->param($project->weekly_report("$year-$month-$start_day", "$end_year-$end_month-$end_day"));
    $template->param($project->data());
  
    # Min's additions to include forum posts in report
    $template->param(posts => $forum->project_posts_by_time($pid, $start, $end));

    print $cgi->header(), $template->output();
};

if($@) {
    my $E = $@;
    if($E->isa('Error::Simple')) {
	if ($E->isa('Error::NO_USERNAME') || 
	    $E->isa('Error::NO_PASSWORD') ||
	    $E->isa('Error::AUTHENTICATION_FAILURE')) {
	    print $cgi->redirect('login.pl');
	} elsif ($E->isa('Error::NO_PID')) {
	    print $cgi->redirect('home.pl');
	} else {
	    print $cgi->header(), "<h1>error:</h1><p>$E->{-text}</p>";
	}
    } else {
	die "unknown error: $E";
    }
}

exit(0);
