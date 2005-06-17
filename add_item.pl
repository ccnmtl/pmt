#!/usr/bin/perl -wT
use lib qw(.);
use strict;
use PMT;
use PMT::Common;
use PMT::Milestone;
my $pmt = PMT->new() or die "couldn't make PMT object";
my $cgi = new CGI();
eval {
    my $username = $cgi->cookie('pmtusername') || "";
    my $password = $cgi->cookie('pmtpassword') || "";
    my $user = new PMT::User($username);
    $user->validate($username,$password);

    my $type         = $cgi->param('type') || throw Error::NO_TYPE "type is necessary";
    my $pid          = $cgi->param('pid') || throw Error::NO_PID "no project specified";
    my $mid          = $cgi->param('mid') || "";
    if ($mid eq "") {
	my $project = PMT::Project->retrieve($pid);
	$mid = $project->upcoming_milestone();
    }
    my $title = escape($cgi->param('title')) || "no title";
    
    #Min's changes to implement multiple assignees to an action item
    #my $assigned_to  = $cgi->param('assigned_to') || "";
    my @assigned_to  = $cgi->param('assigned_to');
    my $owner        = $cgi->param('owner') || $username;
    my $priority     = $cgi->param('priority') || "";
    my $year         = $cgi->param('year') || "";
    my $month        = $cgi->param('month') || "";
    my $day          = $cgi->param('day') || "";
    my $url          = escape($cgi->param('url')) || "";
    my $description  = $cgi->param('description') || "";
    my $new_keywords = $cgi->param('new_keywords') || "";
    my @keywords     = $cgi->param('keywords');
    my @dependencies = $cgi->param('depends');
    my @clients      = $cgi->param('clients');
    my $completed    = $cgi->param('completed') || "";


    my $target_date = $cgi->param('target_date') || "";
    my $estimated_time = $cgi->param('estimated_time') || "";

    if($target_date =~ /(\d{4}-\d{2}-\d{2})/) {
	$target_date = $1;
    } else {
	my $milestone = PMT::Milestone->retrieve($mid);
	$target_date = $milestone->target_date;
    }
    if ($estimated_time =~ /^(\d+)$/) {
        $estimated_time .= "h";
    }
    if ($estimated_time eq "") {
        $estimated_time = "0h";
    }
    push @keywords, split /\n/, $new_keywords;
    @keywords = map {escape($_);} @keywords;

    my @new_keywords;
    foreach my $k (@keywords) {
	push @new_keywords, $k unless $k eq "";
    }

    my @new_dependencies;
    foreach my $d (@dependencies) {
	push @new_dependencies, $d unless $d eq "";
    }
    my @new_clients;
    foreach my $client (@clients) {
	push @new_clients, $client unless $client eq "";
    }

    #Min's changes to implement multiple assignees to an action item
    # loop through each assignee, creating a new action item for
    # each assignee
    #foreach my $assignee (@assigned_to) {

        if($type eq "tracker") {
    	    my $resolve_time = $cgi->param('time') || "1 hour";
	    if($resolve_time =~ /^(\d+)$/) {
	        # default to hours if now unit is specified
	        $resolve_time = "$1"."h";
	    }
	    $pmt->add_tracker(pid => $pid,
	    		      mid => $mid,
			      title => $title,
			      'time' => $resolve_time,
			      target_date => $target_date,
			      owner => $username,
			      completed => $completed,
			      clients => \@new_clients);
        } elsif ($type eq "todo") {
	    $pmt->add_todo(pid => $pid,
		           mid => $mid,
		           title => $title,
		           target_date => $target_date,
		           owner => $username);
        } else {
    #Min's changes to implement multiple assignees to an action item
    # loop through each assignee, creating a new action item for
    # each assignee
            foreach my $assignee (@assigned_to) {

               my %item = (type         => $type,
	                pid          => $pid,
		        mid          => $mid,
		        title        => $title,
		        assigned_to  => $assignee,
		        owner        => $owner,
		        priority     => $priority,
		        target_date  => $target_date,
		        url          => $url,
		        description  => $description,
		        keywords     => \@new_keywords,
		        dependencies => \@new_dependencies,
		        clients      => \@new_clients,
		        estimated_time => $estimated_time);
	       $pmt->add_item(\%item);
	    }
	$type =~ s/\s/%20/g;
      }
# put the user back at the add item for for the same type/project
# so they can conveniently add multiple items
    print $cgi->redirect("home.pl?mode=add_item_form;type=$type;pid=$pid");
};

if($@) {
    my $E = $@;
    if($E->isa('Error::Simple')) {
	if ($E->isa('Error::NO_USERNAME') || 
	    $E->isa('Error::NO_PASSWORD') ||
	    $E->isa('Error::AUTHENTICATION_FAILURE')) {
	    print $cgi->redirect('login.pl');
	} elsif ($E->isa('Error::NO_TYPE') ||
		 $E->isa('Error::NO_PID')) {
	    print $cgi->redirect('home.pl');
	} else {
	    print $cgi->header(), "<h1>error:</h1><p>$E->{-text}</p>";
	}
    } else {
	die "unknown error: $E";
    }
}

