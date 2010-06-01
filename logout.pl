#!/usr/bin/perl -w
use lib qw(.);
use strict;
use PMT::Common;

use CGI;
my $cgi = CGI->new();

eval {
    redirect_with_cookie($cgi,"login.pl","","");
};


