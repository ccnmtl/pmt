#!/usr/bin/perl -w

# File: weekly_summary.pl
# Time-stamp: <Mon Nov 11 15:45:40 2002>

use strict;
use lib qw(.);
use PMT;
use Date::Calc qw/Week_of_Year Monday_of_Week Add_Delta_Days/;
use PMT::Common;

my $pmt = new PMT();
my $cgi = new CGI();

eval {
    my $username = $cgi->cookie('pmtusername') || "";
    my $password = $cgi->cookie('pmtpassword') || "";

    my $user = PMT::User->retrieve($username);
    $user->validate($username,$password);

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

    my $template = get_template("weekly_summary.tmpl");
    $template->param($user->menu());
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
    my @groups = $cgi->param("groups");
    unless (@groups) {
        # default to a couple
        @groups = qw/grp_programmers grp_webmasters
        grp_educationaltechnologists grp_video grp_management/;
    } 
    
    @groups = map { $pmt->group($_) } @groups;
    $template->param(groups => \@groups);
    
    $template->param($pmt->weekly_summary("$mon_year-$mon_month-$mon_day",
					  "$sun_year-$sun_month-$sun_day",
                                      \@groups));
    $template->param(page_title => "Weekly Summary");
    my @values = ();
    my @labels = ();
    foreach my $g (@{PMT::User->groups()}) {
        my $name = $g->{group_name};
        $name =~ s/\s+\(group\)$//;
        push @values, $g->{group};
        push @labels, $name;
    }
    $template->param(groups_select => selectify(\@values, \@labels,
            [map {$_->{group}} @groups]));
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
