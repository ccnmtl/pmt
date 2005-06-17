#!/usr/bin/perl -wT
use lib qw(.);
use strict;
use PMT;
use PMT::Common;

my $pmt = PMT->new();
my $cgi = CGI->new();
eval {
    my $username = $cgi->cookie('pmtusername') || "";
    my $password = $cgi->cookie('pmtpassword') || "";
    my $user = new PMT::User($username);
    my $cdbi_user = CDBI::User->retrieve($username);
    $cdbi_user->validate($username,$password);
    my $mid    = $cgi->param('mid')    || "";

    my $milestone = PMT::Milestone->retrieve($mid);
    my %data = %{$milestone->data()};

    $data{'items'} = [map {$_->data()} $milestone->items()];
    $data{'total_estimated_time'} = $milestone->estimated_time();
    my $project = $milestone->pid;
    my $works_on = $project->project_role($username);
    if($works_on){
	$data{$works_on} = 1;
    }
    my $template = template("milestone.tmpl");
    my $project = $milestone->pid;
    $data{total_remaining_time} = interval_to_hours($project->estimated_time);
    $data{total_completed_time} = interval_to_hours($project->completed_time);
    $data{total_estimated_time} = interval_to_hours($project->all_estimated_time);

    ($data{done},$data{todo},$data{free},$data{completed_behind},$data{behind}) = $project->estimate_graph(150);
    $template->param(\%data);
    $template->param($user->menu());
    $template->param(page_title => "Milestone: $data{name}");
    $template->param(projects_mode => 1);
    print $cgi->header(), $template->output();
};
if($@) {
    my $E = $@;
    print STDERR $E;
    if($E->isa('Error::Simple')) {
	if ($E->isa('Error::NO_USERNAME') || 
	    $E->isa('Error::NO_PASSWORD') ||
	    $E->isa('Error::AUTHENTICATION_FAILURE')) {
	    print $cgi->redirect('login.pl');
	} elsif ($E->('Error::NO_MID')) {
	    print $cgi->redirect('home.pl');
	} else {
	    print $cgi->header(), "<h1>error:</h1><p>$E->{-text}</p>";
	}
    } else {
	die "unknown error: $E";
    }
}

exit(0);
