#!/usr/bin/perl -wT
use lib qw(.);
use strict;
use HTML::CalendarMonth;
use PMT;
use PMT::Common;

my $pmt = PMT->new();
my $cgi = CGI->new();

my @months = qw/January February March April May June
    July August September October November December/;

eval {
    my $username = $cgi->cookie('pmtusername') || "";
    my $password = $cgi->cookie('pmtpassword') || "";

    my $primary_user = new PMT::User($username);
    my $cdbi_user = CDBI::User->retrieve($username);
    $cdbi_user->validate($username,$password);


    my $user   = $cgi->param('user')  || "";
    my $view_user = CDBI::User->retrieve($user);
    my $month  = $cgi->param('month') || "";
    my $year   = $cgi->param('year')  || "";

    my @days;

    my $c = HTML::CalendarMonth->new( month => $month, year => $year );
    $c->table->attr('align','left');
    $c->table->attr('valign','top');

    my $month_name = $months[$month - 1];
    my $calendar = $c->as_HTML;


    $calendar =~ s/>(\d{1,2})</ class="calday">$1</g;

    foreach my $day ($c->days()) {
	my $r = $view_user->events_on("$year-$month-$day",$username);
	my $cell = "";

	foreach my $i (@$r) {
	    $cell .= "<td><a href='item.pl?iid=$$i{iid}'>$$i{title}</a></td>";
	    $cell .= "<td class='$$i{status}'>$$i{status}</td>";
	    $cell .= "<td>$$i{comment}<hr />by $$i{username} \@ $$i{date_time}</td>";
	    $cell .= "</tr>";
	}
	if($cell ne "") {
#	    $cell = "<tr><th colspan='3'><a name='$day'><h2 align='left'>$month_name $day</h2></a></th></tr>\n$cell";
	    push @days,{'cell'       => $cell,
			'month_name' => $month_name,
			'day'        => $day,
			'rows'       => scalar @$r,
			};
	    $calendar =~ s{>$day</td>}{><b><a href="#$day">$day</a></b></td>};
	}
    }

    foreach my $d (@days) {
	my $new_cal = $calendar;
	$new_cal =~ s/calday"><b><a href="\#$d->{day}">$d->{day}<\/a><\/b>/thisday"><b>$d->{day}<\/b>/;
	$d->{cal} = $new_cal;
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

    my $template = template("user_history.tmpl");

    $template->param(calendar   => $calendar,
		     user       => $user,
		     next_month => $next,
		     next_month_name => $months[($next - 1) % 12],
		     next_year  => $next_year,
		     prev_month => $prev,
		     prev_month_name => $months[($prev - 1) % 12],
		     days => \@days,
		     prev_year  => $prev_year);

    $template->param($primary_user->menu());
    $template->param(page_title => "user history for $user");
    print $cgi->header, $template->output();
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

exit 0;
