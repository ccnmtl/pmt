#!/usr/bin/perl -wT
use strict;
use lib qw(.);
use PMT;
use PMT::Common;


my $pmt = PMT->new();
my $cgi = new CGI();

eval {
    my $iid = $cgi->param('iid') || "";
    my $message = $cgi->param('message') || "";

    eval {
	$iid = $pmt->untaint_d($iid);
    };
    if($@) {
	throw Error::NO_IID "no iid specified";
    }

    my $username = $cgi->cookie('pmtusername') || "";
    my $password = $cgi->cookie('pmtpassword') || "";

    my $user = PMT::User->retrieve($username);
    $user->validate($username,$password);

    my $item;
    my %data;
    eval {
        $item = PMT::Item->retrieve($iid);
        %data = %{$item->data()};
    };
    if ($@) {
        print $cgi->header(), qq{there is no item in the system with this id.
        it may have been deleted or you may have followed a bad link.};
        exit;
    }

    my $owner       = PMT::User->retrieve($data{owner});
    my $assigned_to = PMT::User->retrieve($data{assigned_to});
    my $milestone   = $item->mid;
    my $project     = $milestone->pid;
    $data{message}              = $message;
    $data{owner_fullname}       = $owner->fullname;
    $data{assigned_to_fullname} = $assigned_to->fullname;
    $data{milestone}            = $milestone->name;
    $data{pid}                  = $milestone->pid->pid;
    $data{project}              = $project->name;
    my $tiki = new Text::Tiki;
    $data{description} = $data{description} || "";
    $data{description_html} = $tiki->format($data{description});
    $data{$data{type}}         = 1;
    $data{keywords}            = [map {$_->data()} $item->keywords()];
    $data{can_resolve}         = ($data{status} eq 'OPEN' || 
				  $data{status} eq 'INPROGRESS' || 
				  $data{status} eq 'RESOLVED');
    $data{resolve_times}       = $item->resolve_times();
    $data{keywords_select}     = $item->keywords_select($data{keywords});
    $data{dependencies}        = [map {PMT::Item->retrieve($_->dest)->data()} $item->dependencies()];
    $data{dependents}          = [map {PMT::Item->retrieve($_->source)->data()} $item->dependents()];
    $data{history}             = $item->history();
    $data{comments}            = $item->get_comments();
    #Min's addition to implement email opt in/out
    $data{item_cc}             = $item->notify_item($username);

    my @full_history = ();

    my %history_items = ();

    foreach my $h (@{$data{history}}) {
	$history_items{$h->{event_date_time}} = $h;
    }
    foreach my $c (@{$data{comments}}) {
	$history_items{$c->{add_date_time}} = $c;
    }

    foreach my $i (sort keys %history_items) {
	my $t = $history_items{$i};
	$t->{timestamp} = $i;
	push @full_history, $t; 
    }

    $data{full_history}        = \@full_history;
    $data{status_select}       = $item->status_select();
    if(exists $data{pub_view}) {
	$data{pub_view}            = $data{pub_view} == 1; 
    } else {
	$data{pub_view} = 0;
    }

    $data{clients}        = $item->clients_data();
    #$data{clients_select} = $item->clients_select();

    $data{$project->project_role($username)} = 1;
    $data{total_remaining_time} = interval_to_hours($project->estimated_time);
    $data{total_completed_time} = interval_to_hours($project->completed_time);
    $data{total_estimated_time} = interval_to_hours($project->all_estimated_time);

    ($data{done},$data{todo},$data{free},$data{completed_behind},$data{behind}) = $project->estimate_graph(150);

    my $template = get_template("item.tmpl");
    $template->param(\%data);

    $template->param(page_title => "Item: $data{title}");
    $template->param($user->menu());
    $template->param(cc => $item->cc($user));
    print $cgi->header(-charset => 'utf-8'), $template->output();
};
if($@) {
    my $E = $@;
    if($E->isa('Error::Simple')) {
	if ($E->isa('Error::NO_USERNAME') || 
	    $E->isa('Error::NO_PASSWORD') ||
	    $E->isa('Error::AUTHENTICATION_FAILURE')) {
	    print $cgi->redirect('login.pl');
	} elsif ($E->isa('Error::NO_IID')) {
	    print $cgi->redirect('home.pl');
	} else {
	    print $cgi->header(), "<h1>error:</h1><p>$E->{-text}</p>";
	}
    } else {
        print $cgi->header(), "unknown error: $E";
	die "unknown error: $E";
    }
}

exit(0);
