#!/usr/bin/perl -wT
use lib qw(.);
use strict;
use PMT;
use PMT::Common;
use PMT::Project;

my $cgi = CGI->new();

eval {
    my $username = $cgi->cookie('pmtusername') || "";
    my $password = $cgi->cookie('pmtpassword') || "";
    my $user = new PMT::User($username);
    my $cdbi_user = CDBI::User->retrieve($username);
    $cdbi_user->validate($username,$password);

    my $pid         = $cgi->param("pid") || throw Error::NO_PID "no project specified";
    my $name        = escape($cgi->param("name")) || throw Error::NO_NAME "no name specified";
    my $year        = $cgi->param('year') || "";
    my $month       = $cgi->param('month') || "";
    my $day         = $cgi->param('day') || "";
    my $description = $cgi->param('description') || "";

    my $target_date = $cgi->param('target_date') || "";
    if($target_date =~ /(\d{4}-\d{2}-\d{2})/) {
	$target_date = $1;
    } else {
	throw Error::INVALID_DATE "malformed date. a date must be specified in YYYY-MM-DD format.";
    }

    my $project = PMT::Project->retrieve($pid);
    $project->add_milestone($name,$target_date,$description);
    print $cgi->redirect("project.pl?pid=$pid");
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


exit(0);
