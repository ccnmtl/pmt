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
    my $cdbi_user = CDBI::User->retrieve($username);
    $cdbi_user->validate($username,$password);

    my $pid = $cgi->param('pid');
    my $name        = escape($cgi->param('name')) || "";

    if ($name eq "") {
	edit_form($cgi,$pid,$pmt,$username);
	exit;
    }

    my $description = escape($cgi->param('description')) || "";
    my $caretaker   = escape($cgi->param('caretaker')) || "";
    my $pub_view    = ($cgi->param('pub_view') eq "public") ? 't' : 'f';
    my @managers    = $cgi->param('managers');
    my @developers  = $cgi->param('developers');
    my @guests      = $cgi->param('guests');
    my @clients     = $cgi->param('clients');
    my $status      = $cgi->param('status');
    my $projnum     = $cgi->param('projnum')    || "";
    my $type        = $cgi->param('type')       || "";
    my $area        = $cgi->param('area')       || "";
    my $url 	    = $cgi->param('url')        || "";
    my $restricted  = $cgi->param('restricted') || "";
    my $approach    = $cgi->param('approach')   || "";
    my $info_url    = $cgi->param('info_url')   || "";
    my $entry_rel   = $cgi->param('entry_rel')  || "";
    my $eval_url    = $cgi->param('eval_url')   || "";
    my $scale 	    = $cgi->param('scale')      || "";
    my $distrib     = $cgi->param('distrib')    || "";
    my $poster      = $cgi->param('poster')     || "";

    $pmt->edit_project(pid 	   => $pid,
		       name 	   => $name,
		       description => $description,
		       caretaker   => $caretaker,
		       managers    => \@managers,
		       developers  => \@developers,
		       guests 	   => \@guests,
		       clients     => \@clients,
		       pub_view    => $pub_view,
		       status 	   => $status,
		       projnum 	   => $projnum,
		       type 	   => $type,
		       area 	   => $area,
		       url 	   => $url,
		       restricted  => $restricted,
		       approach    => $approach,
		       info_url    => $info_url,
		       entry_rel   => $entry_rel,
		       eval_url    => $eval_url,
		       scale 	   => $scale,
		       distrib 	   => $distrib,
		       poster      => $poster,
		       );

    print $cgi->redirect("project.pl?pid=$pid");
};
if($@) {
    my $E = $@;
    if($E->isa('Error::Simple')) {
	if ($E->isa('Error::NO_USERNAME') || 
	    $E->isa('Error::NO_PASSWORD') ||
	    $E->isa('Error::AUTHENTICATION_FAILURE')) {
	    print $cgi->redirect('login.pl');
	} elsif ($E->isa('Error::PERMISSION_DENIED')) {
	    print $cgi->header(), "only managers may update a project";
	} else {
	    print $cgi->header(), "<h1>error:</h1><p>$E->{-text}</p>";
	}
    } else {
	die "unknown error: $E";
    }
}

sub edit_form {
    my $cgi = shift;
    my $pid = shift;
    my $pmt = shift;
    my $username = shift;
    my $user = new PMT::User($username);

    my ($sec,$min,$hour,$mday,$mon,
	$year,$wday,$yday,$isdst) = localtime(time); 

    my $sortby = $cgi->param('sortby') || $cgi->cookie("pmtsort") || "priority";
    my $project = PMT::Project->retrieve($pid);

    my %data = %{$project->data()};
    $data{managers}             = [map {$_->data()} $project->managers()];
    $data{developers}           = [map {$_->data()} $project->developers()];
    $data{guests}               = [map {$_->data()} $project->guests()];
    $data{caretaker_select}     = $project->caretaker_select();
    $data{all_non_personnel}    = $project->all_non_personnel_select();
    $data{keywords}             = $project->keywords();
    $data{statuses}             = $project->status_select();
    $data{approaches}           = $project->approaches_select();
    $data{scales}               = $project->scales_select();
    $data{distribs}             = $project->distribs_select();
    $data{areas}                = $project->areas_select();
    $data{restricteds}          = $project->restricteds_select();
    $data{types}                = $project->types_select();
    $data{clients}              = $project->clients_data();
    $data{clients_select}       = $project->clients_select();
    $data{all_non_clients}      = $project->all_non_clients_select();
    $data{total_remaining_time} = interval_to_hours($project->estimated_time);
    $data{total_completed_time} = interval_to_hours($project->completed_time);
    $data{total_estimated_time} = interval_to_hours($project->all_estimated_time);

    my $works_on = $project->project_role($username);
    if($works_on) {$data{$works_on} = 1;}
    my $template = template("edit_project.tmpl");
    $template->param(\%data);
    $template->param($user->menu());
    $template->param(page_title => "edit project: $data{name}",
		     month      => $mon + 1,
		     year       => 1900 + $year);
    my $proj = PMT::Project->retrieve($pid);
    $template->param(documents => [map {$_->data()} $proj->documents()]);
    $template->param(projects_mode => 1);

    print $cgi->header(-charset => 'utf-8'), $template->output();
}

exit 0;
