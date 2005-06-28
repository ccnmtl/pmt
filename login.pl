#!/usr/bin/perl -wT
use lib qw(.);
use strict;

use PMT;
use PMT::Common;

my $pmt = PMT->new();
my $cgi = CGI->new();

eval {
    my $username = $cgi->param('username') || &print_form($pmt,$cgi) && exit(0);
    my $password = $cgi->param('password') || &print_form($pmt,$cgi) && exit(0);
    my $user = PMT::User->retrieve($username);
    $user->validate($username,$password);
    $pmt->redirect_with_cookie("home.pl",$username,$password);
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

sub print_form {
    my $pmt = shift;
    my $cgi = shift;
    print $cgi->header();
    my $template = get_template("login.tmpl");
    $template->param(page_title => "login to PMT");
    print $template->output();
}
