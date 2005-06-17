#!/usr/bin/perl -wT

# File: users.pl
# Time-stamp: <Fri Mar  7 15:56:56 2003>
use strict;
use lib qw(.);
use PMT;
use PMT::Common;

my $cgi = new CGI();
my $pmt = PMT->new();
eval {
    my $username = $cgi->cookie('pmtusername') || "";
    my $password = $cgi->cookie('pmtpassword') || "";

    my $user = new PMT::User($username);
    my $cdbi_user = CDBI::User->retrieve($username);
    $cdbi_user->validate($username,$password);

    my $template = template("users.tmpl");

    
    $template->param(users => $pmt->users_hours());
    $template->param($user->menu());

    $template->param(page_title => "users");
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

exit(0);



