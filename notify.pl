#!/usr/bin/perl -wT
use lib qw(.);
use strict;
use PMT;

my $cgi = CGI->new();
eval {
    my $iid = $cgi->param('iid') || "";
    $iid =~ s/\D//g;
    unless($iid) {
	print $cgi->redirect("home.pl");
	exit(0);
    }

    my $username = $cgi->cookie('pmtusername') || "";
    my $password = $cgi->cookie('pmtpassword') || "";
    my $user = new PMT::User($username);

    $user->validate($username,$password);
    my $item = PMT::Item->retrieve($iid);

    $user = CDBI::User->retrieve($username);

    #Min's changes to implement email notification opt in/out
#    my $add  = $cgi->param('add')  || "";
#    my $drop = $cgi->param('drop') || "";
#    $user = CDBI::User->retrieve($username);

    my $notify = $cgi->param('email_notification');

    if($notify eq "yes") {
        $item->add_cc($user);
    } else {
	$item->drop_cc($user);
    }

#    if($add eq "" && $drop eq "") {
#	throw Error::NO_ACTION "no action specified";
#    }

#    if($add) {
#	$item->add_cc($user);
#    }

#    if($drop) {
#	$item->drop_cc($user);
#    }

    print $cgi->redirect("item.pl?iid=$iid");
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
