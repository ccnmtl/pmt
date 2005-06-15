#!/usr/bin/perl -wT

# File: clients.pl
# Time-stamp: <Fri Apr 11 15:56:06 2003>

use strict;
use lib qw(.);
use PMT;
use PMT::Common;
use PMT::Client;

my $cgi = CGI->new();
eval {
    my $username = $cgi->cookie('pmtusername') || "";
    my $password = $cgi->cookie('pmtpassword') || "";

    my $letter = $cgi->param('letter') || "A";

    my @letters = map {{"letter" => $_,
			"current" => $_ eq $letter}} 'A'..'Z';

    my $user = new PMT::User($username);
    $user->validate($username,$password);

    my $template = template("clients.tmpl");
    $template->param($user->menu());
    $template->param(clients => [map {
	$_->{inactive} = $_->{status} eq "inactive";
	$_;
    } @{PMT::Client->all_clients_data($letter)}]);
    $template->param('letters' => \@letters);
    $template->param(clients_mode => 1);
    $template->param(page_title => "All clients ($letter)");
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
