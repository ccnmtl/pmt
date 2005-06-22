#!/usr/bin/perl -wT

# File: project_search.pl
# Time-stamp: <Thu Dec 12 17:27:35 2002>
#
# Copyright (C) 2002 by anders pearson
#
# Author: anders pearson
#
# Description:
# 
use strict;
use lib qw(.);
use PMT;
use PMT::Project;
use PMT::Common;

my $pmt = PMT->new();
my $cgi = CGI->new();


eval {
    my $username = $cgi->cookie('pmtusername') || "";
    my $password = $cgi->cookie('pmtpassword') || "";

    my $user = new PMT::User($username);
    my $cdbi_user = CDBI::User->retrieve($username);
    $cdbi_user->validate($username,$password);

    my $search = $cgi->param('search') || "";
    my $template;

    if($search) {
	my $type      = $cgi->param('type') || "";
	my $area      = $cgi->param('area') || "";
	my $approach  = $cgi->param('approach') || "";
	my $scale     = $cgi->param('scale') || "";
	my $distrib   = $cgi->param('distrib') || "";
	my $manager   = $cgi->param('manager') || "";
	my $developer = $cgi->param('developer') || "";
	my $guest     = $cgi->param('guest') || "";
	my $status    = $cgi->param('status') || "";

	$template = template("project_search_results.tmpl");
	$template->param(results => $pmt->project_search(type => $type,
							 area => $area,
							 approach => $approach,
							 scale => $scale,
							 distrib => $distrib,
							 manager => $manager,
							 developer => $developer,
							 guest => $guest,
							 status => $status,
							)
			);
    } else {
	$template = template("project_search_form.tmpl");


	$template->param(types_select => PMT::Project::types_select(),
			 areas_select => PMT::Project::areas_select(),
			 approaches_select => PMT::Project::approaches_select(),
			 scales_select => PMT::Project::scales_select(),
			 distributions_select => PMT::Project::distribs_select(),
			 managers_select => $pmt->works_on_select("manager"),
			 developers_select => $pmt->works_on_select("developer"),
			 guests_select => $pmt->works_on_select("guest"),
			 status_select => PMT::Project::status_select(),
			 );
    }
    $template->param($cdbi_user->menu());
    $template->param(projects_mode => 1);
    print $cgi->header(), $template->output();
};

if($@) {
    my $E = $@;
    if($E->isa('Error::Simple')) {
	if ($E->isa('Error::NO_USERNAME') || 
	    $E->isa('Error::NO_PASSWORD') ||
	    $E->isa('Error::AUTHENTICATION_FAILURE')) {
	    print $cgi->redirect('login.pl');
	} elsif ($E->isa('Error::NO_PID')) {
	    print $cgi->redirect('home.pl');
	} else {
	    print $cgi->header(), "<h1>error:</h1><p>$E->{-text}</p>";
	}
    } else {
	die "unknown error: $E";
    }
}

