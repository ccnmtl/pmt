#!/usr/bin/perl -wT
use lib qw(.);
use strict;
use PMT;
use PMT::Common;

my $pmt = PMT->new();
my $cgi = CGI->new();

eval {
    my $username = $cgi->cookie('pmtusername') || "";
    my $password = $cgi->cookie('pmtpassword') || "";

    my $user = new PMT::User($username);
    $user->validate($username,$password);

    my $keyword = $cgi->param('keyword') || "";
    my $pid     = $cgi->param('pid')     || "";

    my $template = template("keyword.tmpl");
    $template->param($user->menu());
    $template->param($pmt->keyword($keyword,$username,$pid));

    print $cgi->header(), $template->output();
};

if($@) {
    my $E = $@;
    if($E->isa('Error::Simple')) {
	if ($E->isa('Error::NO_USERNAME') || 
	    $E->isa('Error::NO_PASSWORD') ||
	    $E->isa('Error::AUTHENTICATION_FAILURE')) {
	    print $cgi->redirect('login.pl');
	} elsif ($E->isa('Error::NO_KEYWORD')) {
	    print $cgi->redirect('home.pl');
	} else {
	    print $cgi->header(), "<h1>error:</h1><p>$E->{-text}</p>";
	}
    } else {
	die "unknown error: $E";
    }
}

exit 0;
