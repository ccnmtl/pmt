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

    my $user = PMT::User->retrieve($username);
    $user->validate($username,$password);

    my $pid   = $cgi->param('pid')   || "";
    my $project = PMT::Project->retrieve($pid);

    my $month = $cgi->param('month') || "";
    my $year  = $cgi->param('year')  || "";

    my $c = HTML::CalendarMonth->new( month => $month, year => $year );
    foreach my $item ($c->days()) {
	my $r = $project->milestones_on("$year-$month-$item");
	foreach my $m (@$r) {
	    my $h2 = new HTML::Element 'h3';
	    my $a = HTML::Element->new('a',href => "home.pl?mode=milestone;mid=$$m{mid}");
	    $a->push_content("MILESTONE: $$m{name}");
	    $h2->push_content($a);
	    $c->item($item)->push_content($h2);
	}
	$r = $project->items_on("$year-$month-$item");
	foreach my $i (@$r) {
	    my $p = new HTML::Element 'br';
	    my $a = HTML::Element->new('a',href => "item.pl?iid=$$i{iid}");
	    $a->push_content("$$i{type} #$$i{iid} $$i{title} ($$i{status})");
	    $p->push_content($a);
	    $c->item($item)->push_content($p);
	}

    }
    $c->table->attr('align','left');
    $c->table->attr('valign','top');
    $c->attr('width','100%');

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

    my $template = get_template("project_cal.tmpl");

    $template->param(calendar   => $c->as_HTML,
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
