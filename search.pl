#!/usr/bin/perl -w
use strict;
use lib qw(.);
use PMT;
use XML::RSS;
use PMT::Common;

my $pmt = PMT->new() or die "couldn't make new pmt object";
my $cgi = CGI->new();

eval {
    my $username = $cgi->cookie('pmtusername') || "";
    my $password = $cgi->cookie('pmtpassword') || "";

    my $user = PMT::User->retrieve($username);
    $user->validate($username,$password);

    # the default to "" here so we can do a conditional test below
    # to see if any were set or not.
    my $pid         = $cgi->param('pid') || "";
    my $q           = $cgi->param('q')   || "";
    my $type        = $cgi->param('type') || "";
    my $owner       = $cgi->param('owner') || "";
    my $assigned_to = $cgi->param('assigned_to') || "";
    my @status      = $cgi->param('status');
    my $keyword     = $cgi->param('keyword') || "";
    my @show        = $cgi->param('show');
    my $number      = $cgi->param('number') || "";
    my $sortby      = $cgi->param('sortby') || "";
    my $order       = $cgi->param('order') || "";
    my $limit       = $cgi->param('limit') || 100;
    my $offset      = $cgi->param('offset') || 0;
    my $csv         = $cgi->param('csv') || "";
    my $rss         = $cgi->param('rss') || "";
    my $max_date    = $cgi->param('max_date') || "";
    my $min_date    = $cgi->param('min_date') || "";
    my $hide_menu   = $cgi->param('hide_menu') || "";
    my $results_title = $cgi->param('results_title') || "";
    
    my $template;

    if($csv eq "") {
	$template = template("search.tmpl");
	$template->param($user->menu());
        $template->param(items_mode => 1);
    } else {
	$template = template("search_tab.tmpl");
    }

    # ignore non iso8601 dates
    if($max_date !~ /\d{4}-\d{2}-\d{2}/) {
	$max_date = "";
    }

    if($min_date !~ /\d{4}-\d{2}-\d{2}/) {
	$min_date = "";
    }
    

    my $rows = 0;

    my %show;
    foreach my $show (@show) {
	$show{$show} = 1;
    }



    if ($pid ne "" || $q ne "" || $type ne "" || $owner ne "" 
	|| $assigned_to ne "" || $number ne "" || $sortby ne "" || $order ne "") 
    {
	$pid = $pid || "%";
	$owner = $owner || "%";
	$assigned_to = $assigned_to || "%";
	if($q ne "") {
	    $q = "%$q%";
	} else {
	    $q = "%";
	}

	
	my %orders = (type => "i.type DESC, i.priority $order",
		      priority => "i.priority $order, i.target_date ASC",
		      target_date => "i.target_date $order, i.priority DESC",
		      project => "upper(p.name) $order, i.priority DESC, i.target_date ASC",
		      owner => "upper(uo.fullname) $order, i.priority DESC, i.target_date ASC",
		      assigned_to => "upper(ua.fullname) $order, i.priority DESC, i.target_date ASC",
		      status => "i.status $order, i.r_status $order, i.priority DESC, i.target_date ASC",
		      last_mod => "i.last_mod $order",
		      milestone => "upper(m.name) $order, i.priority DESC, i.target_date ASC",
		      created => "i.iid $order",
		      );

	my $order_string = $orders{$sortby} || die "bad sortby";
	my $query_string;
	$query_string = qq{
	    SELECT i.iid,i.title,i.description,i.type,i.owner,i.assigned_to,uo.fullname,
                   ua.fullname,i.priority,i.target_date,i.url,i.last_mod,
	           i.mid,m.name,m.pid,p.name,i.status,i.r_status
		FROM items i, milestones m, projects p, users uo, users ua
		WHERE i.mid = m.mid
		AND m.pid = p.pid 
		AND i.owner = uo.username 
		AND i.assigned_to = ua.username
	    };
	my @args;
	if($type ne '%') {
	    $query_string .= qq{ AND i.type = ? };
	    push @args, $type;
	}

	if($max_date ne "") {
	    $query_string .= qq{ AND i.target_date <= ? };
	    push @args, $max_date;
	}

	if($min_date ne "") {
	    $query_string .= qq{ AND i.target_date >= ? };
	    push @args, $min_date;
	}

	my $status_string = "";
	foreach my $stat (@status) {
	    if ($stat =~ /_/) {
		my ($s,$r) = split /_/, $stat;
		$status_string .= "OR (i.status = 'RESOLVED' AND i.r_status like ?) ";
		push @args, $r;
	    } else {
		$status_string .= "OR i.status = ? ";
		push @args, $stat;
	    }
	}
	# remove the extra "OR" at the beginning
	if($status_string ne "") { 
	    $status_string = substr($status_string,2);
	    $query_string .= qq{ AND ($status_string) };
	}
	if($pid ne '%') {
	    $query_string .= qq{ AND p.pid = ? };
	    push @args, $pid;
	}
	if($owner ne "%") {
	    $query_string .= qq{ AND uo.username = ? };
	    push @args, $owner;
	}
	if($assigned_to ne "%") {
	    $query_string .= qq{ AND ua.username = ? };
	    push @args, $assigned_to;
	}
	if($q ne "%") {
	    $query_string .= qq{
		AND ( (i.iid IN (select k.iid 
				 from keywords k 
				 where upper(k.keyword) like upper(?)
				 )) OR
		      upper(i.title) LIKE upper(?) 
		      OR upper(i.description) LIKE upper(?))	    
		};
	    push @args, ($q,$q,$q);
	}
	$query_string .= qq{
		AND (p.pid IN (select w.pid 
			       from works_on w 
			       where username = ?) 
		     OR p.pub_view = 'true')
		ORDER BY $order_string
		LIMIT $limit OFFSET $offset;
	};
	push @args, $username;
	my $current_time = time();
	$pmt->debug("query_string: $query_string");
	$pmt->debug("starting main query: $current_time");
	my $r = $pmt->s($query_string,
			\@args,
			['iid','title','description','type','owner','assigned_to','owner_fullname',
			 'assigned_to_fullname','priority','target_date','url','last_mod',
			 'mid','milestone','pid','project','status','r_status']);
	$current_time = time();
	$pmt->debug("finished main query: $current_time");
	my @items;
	my %shows;
        

	foreach my $show (@show) {
	    $shows{"show_$show"} = 1;
	}

	if($rss) {
	    my $feed = new XML::RSS(version => '1.0');
	    $feed->channel(
			   title        => "PMT feed",
			   link         => "http://pmt.ccnmtl.columbia.edu/",
			   );
	    foreach my $i (@$r) {
		$feed->add_item(title => $i->{title},
				link => "http://pmt.ccnmtl.columbia.edu/item.pl?iid=$i->{iid}",
				description => $i->{description});
	    }
	    print $cgi->header("text/xml"),$feed->as_string();
	    exit(0);
	}

        if ((exists $shows{keywords}) || (exists $shows{dependencies}) ||
            (exists $shows{dependents}) || (exists $shows{comments}) ||
            (exists $shows{history})) {
            foreach my $i (@$r) {
                $pmt->debug("fetching item: " . time());
                my $r = $pmt->item($$i{iid});
                my %data = %$r;
                foreach my $k (keys %shows) {$data{$k} = 1;}
                push @items, \%data;
                $pmt->debug("done fetching item: " . time());
            }
        } else {
            foreach my $i (@$r) {
                my %data = %$i;
                foreach my $k (keys %shows) {$data{$k} = 1;}
                push @items, \%data;
            }
        }
        my %PRIORITIES = (4 => 'CRITICAL', 3 => 'HIGH', 2 => 'MEDIUM', 1 => 'LOW',
            0 => 'ICING');

        @items = map { 
            $_->{priority_label} = $PRIORITIES{$_->{priority}};
            $_->{type_class} = $_->{type};
            $_->{type_class} =~ s/\s//g;
            $_;} @items;
	$template->param(\%shows);
	$template->param(results => 1,
			 page_title => $results_title || 'search results',
			 results_title => $results_title,
			 hide_menu => $hide_menu,
			 found_items => ($#items >= 0),
			 items => \@items);
	if($csv) {
	    print $cgi->header("application/vnd.ms-excel");
	} else {
	    print $cgi->header();
	}
	print $template->output();
    } else {
	$template->param(users => [map {$_->data()}
            PMT::User->all_active()]);
	$template->param(page_title => 'search/filter');
	print $cgi->header, $template->output();

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
	print $cgi->header(),
	"an unknown error occurred: $E";
    }
}


