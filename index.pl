#!/usr/bin/perl -wT
use lib qw(.);
use CGI;
use strict;

my $cgi = new CGI();
my $username = $cgi->cookie('pmtusername') || "";
my $password = $cgi->cookie('pmtpassword') || "";

if($username eq "" || $password eq "") {
    print $cgi->redirect("login.pl");
} else {
    print $cgi->redirect("home.pl");
}
exit(0);
