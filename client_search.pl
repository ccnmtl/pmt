#!/usr/bin/perl -wT

# File: client_search.pl
# Time-stamp: <Wed Oct 29 16:54:14 2003>

use strict;
use lib qw(.);
use PMT;
use PMT::Common;

my $pmt = PMT->new();
my $cgi = CGI->new();


eval {
    my $username = $cgi->cookie('pmtusername') || "";
    my $password = $cgi->cookie('pmtpassword') || "";

    my $user = new PMT::User($username);
    $user->validate($username,$password);

    my $template;
    my $status = $cgi->param('status') || "%";
    my $department = $cgi->param('department') || "%";
    my $school = $cgi->param('school') || "%";
    my $start_date = $cgi->param('start_date') || "1900-01-01";
    my $end_date = $cgi->param('end_date') || "2500-01-01";
    my $project = $cgi->param('project') || "%";
    my $limit = $cgi->param('limit') || 100;
    my $offset = $cgi->param('offset') || 0;
    my $contact = $cgi->param('contact') || "%";

    if($status ne "%" || $department ne "%" ||
       $school ne "%" || $start_date ne "1900-01-01" || $end_date ne "2500-01-01" ||
       $project ne "%" || $contact ne "%") {
	my $q = $cgi->param('q') || "%";
	$limit =~ s/\D//;

	$template = template("client_search_results.tmpl");
	$template->param(results => [map {
                $_->{inactive} = $_->{status} eq "inactive";
                $_;
            } @{$pmt->client_search(
                    query => $q,
                    status => $status,
                    department => $department,
                    school => $school,
                    start_date => $start_date,
                    end_date => $end_date,
                    project => $project,
                    limit => $limit,
                    offset => $offset,
                    contact => $contact,
                )}]);
        my $results_count = $pmt->client_search_count(
            query => $q,
            status => $status,
            department => $department,
            school => $school,
            start_date => $start_date,
            end_date => $end_date,
            project => $project,
            contact => $contact,
        );
	$template->param(results_count => $results_count);
        if ($results_count > ($offset + $limit)) {
           $template->param('next' => 1);
           $template->param('next_offset' => $offset + $limit);
        }
        if ($offset > 0) {
            $template->param('prev' => 1);
            $template->param('prev_offset' => $offset - $limit);
        }
        $template->param(limit => $limit,
            q => $q,
            status => $status,
            department => $department,
            school => $school,
            start_date => $start_date,
            end_date => $end_date,
            project => $project,
            contact => $contact);
        
    } else {
	$template = template("client_search_form.tmpl");
	my $sql = qq{select distinct school,upper(school) as uschool from clients order by upper(school);};
	$template->param(schools => $pmt->s($sql,[],['school','uschool']));
	$sql = qq{select distinct department,upper(department) as udep from clients order by upper(department);};
	$template->param(departments => $pmt->s($sql,[],['department','udep']));
	$sql = qq{select distinct c.contact,u.fullname,upper(u.fullname) from clients c, users u where c.contact = u.username order by upper(u.fullname) ASC;};
	$template->param(contacts => $pmt->s($sql,[],['contact_username','contact_fullname']));
	$sql = qq{select min(registration_date) from clients;};
	$template->param(start_date => $pmt->ss($sql,[],['reg'])->{reg});
	$sql = qq{select current_date;};
	$template->param(end_date => $pmt->ss($sql,[],['date'])->{date});
    }
    $template->param(page_title => "client search");
    $template->param($user->menu());
    $template->param(clients_mode => 1);
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

