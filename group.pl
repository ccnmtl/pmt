#!/usr/bin/perl -wT

# File: group.pl
# Time-stamp: <Mon Jul 15 13:32:42 2002>

use strict;
use lib qw(.);
use PMT;
use PMT::Common;

my $pmt = PMT->new();
my $cgi = new CGI();
eval {
    my $username = $cgi->cookie('pmtusername') || "";
    my $password = $cgi->cookie('pmtpassword') || "";

    my $user = new PMT::User($username);
    my $cdbi_user = CDBI::User->retrieve($username);
    $cdbi_user->validate($username,$password);

    my $group = $cgi->param('group') || "";
    my $template;
    if($group ne "") {
	# display info for a group
	$template = template('group.tmpl');
	$template->param($pmt->group($group));
	$template->param(page_title => "Group: $group");
    } else {
	# list groups and display add group form
	$template = template('groups.tmpl');
	$template->param(groups => $pmt->groups());
	$template->param(page_title => "Groups");
    }
    $template->param($user->menu());
    $template->param(users_mode => 1);
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
