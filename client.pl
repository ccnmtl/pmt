#!/usr/bin/perl -wT

# File: client.pl
# Time-stamp: <Fri Apr 11 15:38:01 2003>
use strict;
use lib qw(.);
use PMT;
use PMT::Client;
use PMT::Common;

my $cgi = CGI->new();
eval {
    my $username = $cgi->cookie('pmtusername') || "";
    my $password = $cgi->cookie('pmtpassword') || "";

    my $user = new PMT::User($username);
    $user->validate($username,$password);

    my $client_id = $cgi->param('client_id') || "";
    my $client = PMT::Client->retrieve($client_id);

    my $contact = new PMT::User($client->get('contact'));

    my $template = template("client.tmpl");
    $template->param($user->menu());
    my $data = $client->data();
    $data->{client_email} = $data->{email};
    $data->{active} = $data->{status} eq "active";
    $template->param(contact_fullname => $contact->get('fullname'));
    delete $data->{email};
    $template->param(%{$data});
    $template->param(client_projects => $client->projects_data(),
		     projects_select => $client->projects_select(),
		     contacts_select => $client->contacts_select(),
		     recent_items => $client->recent_items());
    $template->param(clients_mode => 1);
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
