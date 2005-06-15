#!/usr/bin/perl -w
use strict;
use lib qw(.);
use PMT;
use PMT::Common;

my $pmt = PMT->new();
my $cgi = CGI->new();

eval {

    my $login = $cgi->cookie('pmtusername') || "";
    my $password = $cgi->cookie('pmtpassword') || "";
    my $user = new PMT::User($login);
    $user->validate($login,$password);

    my ($sec,$min,$hour,$mday,$mon,
	$year,$wday,$yday,$isdst) = localtime(time); 

    my $username = $cgi->param('username') || "";
    my $sortby   = $cgi->param('sortby')   || "priority";

    my $viewing_user = new PMT::User($username);

    my $template = template("user.tmpl");
    my $data = $viewing_user->data();
    $data->{user_username} = $data->{username};
    $data->{user_fullname} = $data->{fullname};
    $data->{user_email} = $data->{email};
    delete $data->{username};
    delete $data->{fullname};
    delete $data->{email};
    delete $data->{status};
    throw Error::NonexistantUser "user does not exist" 
        unless $data->{user_username};
    if ($data->{group}) {
        $data->{users} = $pmt->users_in_group($username);
    } else {
        $data->{groups} = $viewing_user->user_groups();
    }
    my $vu = CDBI::User->retrieve($username);
    $data->{total_estimated_time} = $vu->total_estimated_time();
    $template->param(%$data);
    $template->param(items => $viewing_user->items($login,$sortby));
    $template->param(page_title => "user info for $username");
    $template->param($user->menu());
    $template->param(month      => $mon + 1,
		     year       => 1900 + $year);
    $template->param(users_mode => 1);
    print $cgi->header, $template->output();
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
