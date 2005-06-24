#!/usr/bin/perl -wT
use lib qw(.);
use strict;

use PMT;

my $pmt = PMT->new();
my $cgi = CGI->new();



eval {
    my $username = $cgi->param('username') || &print_form($cgi) && exit 0;
    my $password = $cgi->param('password') || &print_form($cgi) && exit 0;
    my $pass_ver = $cgi->param('pass_ver') || &print_form($cgi) && exit 0;
    my $fullname = $cgi->param('fullname') || &print_form($cgi) && exit 0;
    my $email    = $cgi->param('email')    || &print_form($cgi) && exit 0;

    throw Error::PASSWORD_MISMATCH "passwords do not match" unless $password eq $pass_ver;
    my $u = PMT::User->create({username => $username, fullname => $fullname, email => $email, 
			       password => $password});
    print $cgi->redirect("login.pl");
};
if($@) {
    my $E = $@;
    if($E->isa('Error::Simple')) {
	if ($E->isa('Error::NO_USERNAME') || 
	    $E->isa('Error::NO_PASSWORD') ||
	    $E->isa('Error::AUTHENTICATION_FAILURE')) {
	    print $cgi->redirect('../login.pl');
	} else {
	    print $cgi->header(), "<h1>error:</h1><p>$E->{-text}</p>";
	}
    } else {
	die "unknown error: $E";
    }
}

exit 0;

sub print_form {
    my $cgi = shift;
    print $cgi->redirect("new/add_user.html");
}
