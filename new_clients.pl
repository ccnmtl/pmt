#!/usr/bin/perl -wT

# File: new_clients.pl
# Time-stamp: <Tue Jun 17 18:24:44 2003>
use strict;
use lib qw(.);
use PMT;
use PMT::Client;
use Date::Calc qw/Week_of_Year Monday_of_Week Add_Delta_Days Days_in_Month/;
use PMT::Common;

my $pmt = PMT->new();
my $cgi = CGI->new();

my @months = qw/January February March April May June July August September October November December/;

eval {
    my $username = $cgi->cookie('pmtusername') || "";
    my $password = $cgi->cookie('pmtpassword') || "";

    my $user = new PMT::User($username);
    $user->validate($username,$password);

    my $syear = $cgi->param('year') || "";
    my $smonth = $cgi->param('month') || "";
    my $sday = $cgi->param('day') || "";
    my ($sec,$min,$hour,$mday,$mon,
	$year,$wday,$yday,$isdst);
    if($syear && $smonth && $sday) {
	# if the day was specified in the url, use that
	$year = $syear;
	$mon  = $smonth;
	$mday = $sday;
    } else {
	# otherwise, default to today
	($sec,$min,$hour,$mday,$mon,
	 $year,$wday,$yday,$isdst) = localtime(time); 
	$year += 1900;
	$mon += 1;
    }


    my ($mon_year,$mon_month,$mon_day) = ($year,$mon,1);
    my ($sun_year,$sun_month,$sun_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,Days_in_Month($mon_year,$mon_month) - 1);
    my ($pm_year,$pm_month,$pm_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,-1);
    my ($nm_year,$nm_month,$nm_day) = Add_Delta_Days($sun_year,$sun_month,$sun_day,1);


    my $template = template("new_clients.tmpl");
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
		     month => $months[$mon - 1],
		     year => $mon_year,
		     pm_mon => $months[$pm_month - 1],
		     nm_mon => $months[$nm_month - 1],
		     );

    $template->param($user->menu());
    $template->param(clients_mode => 1);
    $template->param(page_title => 'new clients report');
    $template->param(clients => PMT::Client->new_clients_data("$mon_year-$mon_month-$mon_day",
							  "$sun_year-$sun_month-$sun_day"));
    print $cgi->header(), $template->output();
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
