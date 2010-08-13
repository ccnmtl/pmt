#!/usr/bin/perl -w
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

    if ($username eq "") {
	throw Error::NO_USERNAME;
    }

    my $user = PMT::User->retrieve($username);
    $user->validate($username,$password);

    my $item;
    my %data;
    eval {
        $item = PMT::Item->retrieve($iid);
        %data = %{$item->data($username)};
    };
    if ($@) {
        print $cgi->header(), qq{there is no item in the system with this id.
        it may have been deleted or you may have followed a bad link.};
    } else {

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
        $data{description} =~ s/\(([^\)\(]+\@[^\)\(]+)\)/( $1 )/g; # workaround horrible bug in Text::Tiki
	$data{description} =~ s/(\w+)\+(\w+)\@/$1&plus;$2@/g; # workaround for second awful Text::Tiki bug
        $data{description_html} = $tiki->format($data{description});
        $data{$data{type}}         = 1;
        $data{tags}                = $item->tags();
        $data{user_tags}           = $item->user_tags($username);
        $data{can_resolve}         = ($data{status} eq 'OPEN' ||
                                      $data{status} eq 'INPROGRESS' ||
                                      $data{status} eq 'RESOLVED');
        $data{resolve_times}       = $item->resolve_times();
        $data{history}             = $item->history();
        $data{comments}            = $item->get_comments();
        $data{attachments}         = [map {$_->data()} $item->attachments()];

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

        $data{wiki_category} = $project->wiki_category;

        ($data{done},$data{todo},$data{free},$data{completed_behind},$data{behind}) = $project->estimate_graph(150);

        my $template = get_template("item.tmpl");
        $template->param(\%data);

        $template->param(page_title => "Item: $data{title}");
        $template->param($user->menu());
        $template->param(cc => $item->cc($user));
        $template->param(wiki_base_url => PMT::Common::get_wiki_url());
        print $cgi->header(-charset => 'utf-8'), $template->output();
    }
};
if($@) {
    my $E = $@;
    if($E->isa('Error::Simple')) {
        if ($E->isa('Error::NO_USERNAME') ||
            $E->isa('Error::NO_PASSWORD') ||
            $E->isa('Error::AUTHENTICATION_FAILURE')) {
            print $cgi->redirect('/login.pl');
        } elsif ($E->isa('Error::NO_IID')) {
            print $cgi->redirect('/home.pl');
        } else {
            print $cgi->header(), "<h1>error:</h1><p>$E->{-text}</p>";
        }
    } else {
        print $cgi->header(), "unknown error: $E";
        die "unknown error: $E";
    }
}


