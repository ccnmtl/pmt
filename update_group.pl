#!/usr/bin/perl -wT

# File: update_group.pl
# Time-stamp: <Mon Jul 15 14:17:51 2002>

use strict;
use lib qw(.);
use PMT;

my $pmt = PMT->new();
my $cgi = new CGI();
eval {
    my $username = $cgi->cookie('pmtusername') || "";
    my $password = $cgi->cookie('pmtpassword') || "";
    my $user = new PMT::User($username);
    $user->validate($username,$password);

    my $group = $cgi->param('group') || "";
    my @users = $cgi->param('users');

    $pmt->update_group($group,\@users);

    print $cgi->redirect("group.pl?group=$group");
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
