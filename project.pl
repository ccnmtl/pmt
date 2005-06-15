#!/usr/bin/perl -wT
use lib qw(.);
use strict;
use PMT;
use PMT::Common;
use CDBI::User;
use PMT::Project;
my $pmt = PMT->new();
my $cgi = CGI->new();


eval {
    my $username = $cgi->cookie('pmtusername') || "";
    my $password = $cgi->cookie('pmtpassword') || "";

    my $user = new PMT::User($username);
    $user->validate($username,$password);

    my ($sec,$min,$hour,$mday,$mon,
	$year,$wday,$yday,$isdst) = localtime(time); 
    my $pid    = $cgi->param('pid') || &new_project_form($user,$cgi) && exit(0);
    my $sortby = $cgi->param('sortby') || $cgi->cookie("pmtsort") || "priority";
    my $project = PMT::Project->retrieve($pid);
    my $works_on = $project->project_role($username);
    my %data = %{$project->data()};
    my $caretaker = $project->caretaker;

    $data{caretaker_fullname}   = $caretaker->fullname;
    $data{milestones}           = $project->project_milestones($sortby, $username);
    $data{managers}             = [map {$_->data()} $project->managers()];
    $data{developers}           = [map {$_->data()} $project->developers()];
    $data{guests}               = [map {$_->data()} $project->guests()];
    $data{keywords}             = $project->keywords();
    $data{total_remaining_time} = interval_to_hours($project->estimated_time);
    $data{total_completed_time} = interval_to_hours($project->completed_time);
    $data{total_estimated_time} = interval_to_hours($project->all_estimated_time);

    my $table_width = 150;
    ($data{done},$data{todo},$data{free},$data{completed_behind},$data{behind}) = $project->estimate_graph($table_width);

    if($works_on) {$data{$works_on} = 1;}
    my $template = template("project.tmpl");
    $template->param(\%data);
    $template->param($user->menu());
    #Min's additions to implement email notification opt in/out
    $template->param(proj_cc => $project->cc(CDBI::User->retrieve($username)));
    $template->param(page_title => "project: $data{name}",
		     month      => $mon + 1,
                     year       => 1900 + $year);
    
    my $proj = PMT::Project->retrieve($pid);
    $template->param(documents => [map {$_->data()} $proj->documents()]);
    $template->param(projects_mode => 1);
    print $cgi->header(-cookie => [$cgi->cookie(-name => "pmtsort",
						-value => $sortby,
						-path => '/',
						-expires => "+10y")]), 
    $template->output();
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

exit(0);

sub new_project_form {
    my $user = shift;
    my $cgi = shift;
    my $template = template("add_project.tmpl");
    $template->param($user->menu());
    print $cgi->header(-charset => 'utf-8'), $template->output();
}
