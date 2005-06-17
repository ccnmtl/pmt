#!/usr/bin/perl -wT

# File: add_services_item.pl
# Time-stamp: <Mon Oct 13 12:00:24 2003>

use strict;

use lib qw(.);
use strict;
use PMT;
use PMT::Common;

my $pmt = PMT->new() or die "couldn't make PMT object";
my $cgi = new CGI();
eval {
    my $username = $cgi->cookie('pmtusername') || "";
    my $password = $cgi->cookie('pmtpassword') || "";
    my $user = new PMT::User($username);
    my $cdbi_user = CDBI::User->retrieve($username);
    $cdbi_user->validate($username,$password);
    my $pid = $cgi->param('pid');
    my $type = $cgi->param('type') || "tracker";
    my $client_id = $cgi->param('client_id') || die "no client specified";
    
    my $template = template("add_courseworks_item.tmpl");

    $template->param($user->menu());
    $template->param($pmt->add_courseworks_item_form($pid,$type,$username,$client_id));

    use Date::Calc qw/Week_of_Year Monday_of_Week Add_Delta_Days/;
    my ($sec,$min,$hour,$mday,$mon,
	$year,$wday,$yday,$isdst) = localtime(time); 
    $year += 1900;
    $mon += 1;
    my ($mon_year,$mon_month,$mon_day) = Monday_of_Week(Week_of_Year($year,$mon,$mday));
    # backdated stuff goes in on sundays
    my ($p_year,$p_month,$p_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,-1);
    my ($pp_year,$pp_month,$pp_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,-8);

    $template->param(p_week => "$p_year-$p_month-$p_day",
		     pp_week => "$pp_year-$pp_month-$pp_day");

    print $cgi->header, $template->output();
};
