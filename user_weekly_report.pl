#!/usr/bin/perl -wT

# File: project_weekly_report.pl
# Time-stamp: <Thu Sep 26 14:43:48 2002>

use strict;
use lib qw(.);
use PMT;
use PMT::Common;
use Date::Calc qw/Week_of_Year Monday_of_Week Add_Delta_Days/;

my $pmt = new PMT();
my $cgi = new CGI();

eval {
    my $username = $cgi->cookie('pmtusername') || "";
    my $password = $cgi->cookie('pmtpassword') || "";

    my $primary_user = new PMT::User($username);
    my $cdbi_user = CDBI::User->retrieve($username);
    $cdbi_user->validate($username,$password);

    my $user = $cgi->param('username') || "";
    my $view_user = new PMT::User($user);
    my $syear = $cgi->param('year') || "";
    my $smonth = $cgi->param('month') || "";
    my $sday = $cgi->param('day') || "";
    my ($sec,$min,$hour,$mday,$mon,
	$year,$wday,$yday,$isdst);
    if($syear && $smonth && $sday) {
	# if the day was specified in the url, use that
	$year = $syear;
	$mon = $smonth;
	$mday = $sday;
    } else {
	# otherwise, default to today
	($sec,$min,$hour,$mday,$mon,
	 $year,$wday,$yday,$isdst) = localtime(time); 
	$year += 1900;
	$mon += 1;
    }


    my ($mon_year,$mon_month,$mon_day) = Monday_of_Week(Week_of_Year($year,$mon,$mday));
    my ($sun_year,$sun_month,$sun_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,7);
    my ($pm_year,$pm_month,$pm_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,-7);
    my ($nm_year,$nm_month,$nm_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,7);

    my $template = template("user_weekly_report.tmpl");
    $template->param($primary_user->menu());
    $template->param(
		     mon_year => $mon_year,
		     mon_month => $mon_month,
		     mon_day => $mon_day,
		     sun_year => $sun_year,
		     sun_month => $sun_month,
		     sun_day => $sun_day,
		     pm_year => $pm_year,
		     pm_month => $pm_month,
		     pm_day => $pm_day,
		     nm_year => $nm_year,
		     nm_month => $nm_month,
		     nm_day => $nm_day,
		     );

    #check is user is a group
    my $data = $pmt->group($user);
    $template->param($view_user->weekly_report("$mon_year-$mon_month-$mon_day",
					    "$sun_year-$sun_month-$sun_day"));
    my $cdbi_view_user = CDBI::User->retrieve($user->{username});
    $template->param($cdbi_view_user->user_info());
    $template->param(page_title => "weekly report for $user");
    $template->param(reports_mode => 1);
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
