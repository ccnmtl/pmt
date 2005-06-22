#!/usr/bin/perl -wT

# File: edit_client.pl
# Time-stamp: <Fri Apr 11 17:31:16 2003>

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
    my $cdbi_user = CDBI::User->retrieve($username);
    $cdbi_user->validate($username,$password);

    my $client_id         = $cgi->param('client_id') || "";
    my $client = PMT::Client->retrieve($client_id);
    my $client_email 	  = $cgi->param('client_email') || "";
    if ($client_email eq "") {
	edit_form($cgi,$client,$user);
	exit 0;
    } else {
	my $lastname 	  = $cgi->param('lastname') || "";
	my $firstname 	  = $cgi->param('firstname') || "";
	my $title 		  = $cgi->param('title') || "";
	my $registration_date = $cgi->param('registration_date') || "";
	my $department 	  = $cgi->param('department') || '';
	my $school 		  = $cgi->param('school') || '';
	my $add_affiliation   = $cgi->param('add_affiliation') || "";
	my $phone 		  = $cgi->param('phone') || "";
	my $contact 	  = $cgi->param('contact') || "";
	my $comments 	  = $cgi->param('comments') || "";
	my $status            = $cgi->param('status') || "active";

	my @projects = $cgi->param('projects');


	$client->update_data(
			     lastname 	 => $lastname,
			     firstname 	 => $firstname,
			     title 		 => $title, 
			     status          => $status,
			     department 	 => $department, 
			     school 	 => $school,
			     add_affiliation => $add_affiliation,
			     phone 		 => $phone,
			     email 		 => $client_email, 
			     contact 	 => $contact,
			     comments 	 => $comments,
			     registration_date => $registration_date,
			     projects 	 => \@projects,
			     );
	$client->update();
	my $letter = uc(substr($lastname,0,1));
	print $cgi->redirect("home.pl?mode=all_clients;letter=$letter");
    }
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

sub edit_form {
    my $cgi = shift;
    my $client = shift;
    my $user = shift;
    my $contact = new PMT::User($client->get('contact'));

    my $template = template("edit_client.tmpl");
    $template->param($cdbi_user->menu());
    my $data = $client->data();
    $data->{client_email} = $data->{email};
    $data->{active} = $data->{status} eq "active";
    $template->param(contact_fullname => $contact->get('fullname'));
    delete $data->{email};
    $template->param(%{$data});
    $template->param(projects => $client->projects_data(),
		     projects_select => $client->projects_select(),
		     contacts_select => $client->contacts_select(),
		     schools_select => $client->schools_select(),
		     departments_select => $client->all_departments_select());
    $template->param(clients_mode => 1);
    print $cgi->header(), $template->output();
}
