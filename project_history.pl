#!/usr/bin/perl -wT
use lib qw(.);
use strict;
use CGI qw/:standard /;
use HTML::CalendarMonth;
use PMT;
use PMT::Common;

my $cgi = CGI->new();

eval {
    my $username = $cgi->cookie('pmtusername') || "";
    my $password = $cgi->cookie('pmtpassword') || "";

    my $user = new PMT::User($username);
    $user->validate($username,$password);

    my $pid   = $cgi->param('pid')   || "";
    my $month = $cgi->param('month') || "";
    my $year  = $cgi->param('year')  || "";

    my $project = PMT::Project->retrieve($pid);
    my $c = HTML::CalendarMonth->new( month => $month, year => $year );
    $c->table->attr('align','left');
    $c->table->attr('valign','top');
    $c->attr('width','100%');

    my $calendar = $c->as_HTML;

    foreach my $day ($c->days()) {
	my $r = $project->events_on("$year-$month-$day");
	my $cell = "";

	foreach my $i (@$r) {
	    $cell .= "<tr><td><a href='item.pl?iid=$$i{iid}'>$$i{title}</a></td>";
	    $cell .= "<td class='$$i{status}'>$$i{status}</td>";
	    $cell .= "<td>$$i{comment}<hr />by $$i{username} \@ $$i{date_time}</td>";
	    $cell .= "</tr>";
	}
	if($cell ne "") {
	    $cell = "<table>$cell</table>";
	    $calendar =~ s{>$day</td>}{>$day<br />$cell</td>};
	}
    }

    my $next = $month + 1;
    my $prev = $month - 1;
    my ($next_year,$prev_year) = ($year,$year);
    
    if(13 == $next) {
	$next = 1;
	$next_year = $year + 1;
    }
    if(0 == $prev) {
	$prev = 12;
	$prev_year = $year - 1;
    }

    my $template = template("project_history.tmpl");

    $template->param(calendar   => $calendar,
		     pid        => $pid,
		     next_month => $next,
		     next_year  => $next_year,
		     prev_month => $prev,
		     prev_year  => $prev_year);

    $template->param($user->menu());
    print $cgi->header, $template->output();
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

exit 0;
