#!/usr/bin/perl -wT
use lib qw(.);
use strict;
use PMT;
use PMT::Common;
use PMT::Milestone;


my $pmt = PMT->new();
my $cgi = CGI->new();

eval {
    my $iid = $cgi->param('iid') || "";
    $iid =~ s/\D//g;
    if($iid =~ /^(\d+)$/) {
	$iid = $1;
    } else {
	throw Error::NO_IID "no iid specified";
    }

    my $username = $cgi->cookie('pmtusername') || "";
    my $password = $cgi->cookie('pmtpassword') || "";
    my $user = new PMT::User($username);
    my $cdbi_user = CDBI::User->retrieve($username);
    $cdbi_user->validate($username,$password);

    my $status = $cgi->param('status') || "";

    if ($status eq "") {
	edit_form($cgi,$iid,$pmt,$username);
	exit 0;
    }

    my $r_status = "";
    ($status,$r_status) = split /_/, $cgi->param('status');

    

    my $type         = $cgi->param('type') || "";
    my $mid          = $cgi->param('mid') || "";
    my $title        = escape($cgi->param('title')) || "no title";
    my $assigned_to  = $cgi->param('assigned_to') || "";
    my $owner        = $cgi->param('owner') || "";
    my $priority     = $cgi->param('priority') || "";
    my $url          = escape($cgi->param('url')) || "";
    my $description  = $cgi->param('description') || "";
    my $new_keywords = $cgi->param('new_keywords') || "";
    my @keywords     = $cgi->param('keywords');
    my @dependencies = $cgi->param('depends');
    my @clients      = $cgi->param('clients');
    my $target_date  = $cgi->param('target_date') || PMT::Milestone->retrieve($mid)->target_date;
    my $comment      = escape($cgi->param('comment')) || "";
    my $resolve_time = $cgi->param('resolve_time') || "";
    my $client_uni   = $cgi->param('client_uni') || "";

    if($resolve_time =~ /^(\d+)$/) {
	# default to hours if no unit was specified.
	$resolve_time .= "h";
    }
    my $estimated_time = $cgi->param('estimated_time') || "01:00";
    if($estimated_time =~ /^(\d+)$/) {
	$estimated_time .= "h";
    }



    push @keywords, split /\n/, $new_keywords;
    @keywords = map {escape($_);} @keywords;
    my @new_keywords;
    foreach my $k (@keywords) {
	push @new_keywords, $k unless $k eq "";
    }

    my @new_deps;
    foreach my $d (@dependencies) {
	push @new_deps, $d unless $d eq "";
    }

    my @new_clients;
    foreach my $c (@clients) {
	push @new_clients, $c unless $c eq "";
    }

    my %item = (type         => $type,
		iid          => $iid,
		mid          => $mid,
		title        => $title,
		assigned_to  => $assigned_to,
		owner        => $owner,
		priority     => $priority,
		target_date  => $target_date,
		url          => $url,
		description  => $description,
		keywords     => \@new_keywords,
		dependencies => \@new_deps,
		clients      => \@new_clients,  
		client_uni   => $client_uni,
		status       => $status,
		r_status     => $r_status,
		resolve_time => $resolve_time,
		estimated_time => $estimated_time,
		comment      => $comment);

    use URI::Escape;

    my $message = URI::Escape::uri_escape($pmt->update_item(\%item,$username));
    print $cgi->redirect("item.pl?iid=$iid;message=$message");
};

if($@) {
    my $E = $@;
    if($E->isa('Error::Simple')) {
	if ($E->isa('Error::NO_USERNAME') || 
	    $E->isa('Error::NO_PASSWORD') ||
	    $E->isa('Error::AUTHENTICATION_FAILURE')) {
	    print $cgi->redirect('login.pl');
	} elsif ($E->isa('Error::NO_IID') ||
		 $E->isa('Error::NO_MID')) {
	    print $cgi->redirect('home.pl');
	} elsif ($E->isa('Error::UNRESOLVED_DEPENDENCIES')) {
	    print $cgi->header(), "<h1>unresolved dependency</h1>
<p>this item cannot be resolved because one or more of its dependencies is still open.</p>
<p>all dependencies must be resolved before an item may be resolved.</p>";
	} elsif ($E->isa('Error::NO_PRIORITY')) {
	    print $cgi->header(), "<h1>dependency error</h1><p>please try again. if you still get this error, please notify anders.</p>";
	} else {
	    print $cgi->header(), "<h1>error:</h1><p>$E->{-text}</p>";
	}
    } else {
	die "unknown error: $E";
    }
}

sub edit_form {
    my $cgi = shift;
    my $iid = shift;
    my $pmt = shift;
    my $username = shift;
    my $user = new PMT::User($username);

    my $r = $pmt->item($iid);
    my $item = PMT::Item->retrieve($iid);
    my %data = %$r;
    my $project = PMT::Project->retrieve($data{'pid'});
    $data{$project->project_role($username)} = 1;
    my $template = template("edit_item.tmpl");
    $template->param(\%data);
    $template->param(page_title => "Edit Item: $data{title}");
    $template->param($user->menu());
    $template->param(cc => $item->cc(CDBI::User->retrieve($username)));
    print $cgi->header(-charset => 'utf-8'), $template->output();
}

exit 0;

