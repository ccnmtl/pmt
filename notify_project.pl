#!/usr/bin/perl -wT

# notify_project.pl
# used for the opting in/out of email notification in the
# project level
# Min San Co
# Oct 27, 2004

use lib qw(.);
use strict;
use PMT;

my $cgi = CGI->new();
eval {
    my $pid = $cgi->param('pid') || "";
    $pid =~ s/\D//g;
    unless($pid) {
	print $cgi->redirect("home.pl");
	exit(0);
    }

    my $username = $cgi->cookie('pmtusername') || "";
    my $password = $cgi->cookie('pmtpassword') || "";
    my $user = CDBI::User->retrieve($username);

    $user->validate($username,$password);
#    my $project = new PMT::Project($pid);
    my $project = PMT::Project->retrieve($pid);

    my $notify_proj = $cgi->param('proj_notification');

    if($notify_proj eq "yes") {
	$project->add_cc($user);
    } else {
	$project->drop_cc($user);
    }

    print $cgi->redirect("project.pl?pid=$pid");
};
if($@) {
    my $E = $@;
    if($E->isa('Error::Simple')) {
	if ($E->isa('Error::NO_USERNAME') || 
	    $E->isa('Error::NO_PASSWORD') ||
	    $E->isa('Error::AUTHENTICATION_FAILURE')) {
	    print $cgi->redirect('login.pl');
	} elsif ($E->isa('Error::NO_ACTION')) {
	    print $cgi->header(), "no action was specified. please report this error.";
	} else {
	    print $cgi->header(), "<h1>error:</h1><p>$E->{-text}</p>";
	}
    } else {
	die "unknown error: $E";
    }
}

exit 0;
