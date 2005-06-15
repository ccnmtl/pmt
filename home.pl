#!/usr/bin/perl -wT
use strict;
use lib qw(.);
use PMT::Control;

eval {
    my $app = new PMT::Control();
    $app->run();
};

if($@) {
    my $E = $@;
    my $cgi = new CGI();
    if($E->isa('Error::Simple')) {
	if ($E->isa('Error::NO_USERNAME') || 
	    $E->isa('Error::NO_PASSWORD') ||
	    $E->isa('Error::AUTHENTICATION_FAILURE') ||
            $E->isa('Error::INCORRECT_PASSWORD')
        ) {
	    print $cgi->redirect('login.pl');
        } elsif ($E->isa('Error::NO_EMAIL')) {
            print $cgi->header(), "<h1>error:</h1><p>you must enter a valid email address</p>";
	} else {
	    print $cgi->header(), "<h1>error:</h1><p>$E->{-text}</p>";
	}
    } else {
	die "unknown error: $E";
    }
}

exit(0);

