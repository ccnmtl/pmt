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
    my $tag         = $cgi->param('tag') || "";
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
        $template = get_template("search.tmpl");
        $template->param($user->menu());
        $template->param(items_mode => 1);
    } else {
        $template = get_template("search_tab.tmpl");
    }

    my $rows = 0;

    my %show;
    foreach my $show (@show) {
        $show{$show} = 1;
    }

    if ($pid ne "" || $q ne "" || $type ne "" || $owner ne ""
        || $assigned_to ne "" || $number ne "" || $sortby ne "" || $order ne "")
    {

        my $current_time = time();
        $pmt->debug("starting main query: $current_time");

        my $r = PMT::Item->search_items(pid => $pid, q => $q, type => $type, owner => $owner,
                                        assigned_to => $assigned_to, status => \@status, tag => $tag,
                                        number => $number, sortby => $sortby, order => $order, limit => $limit,
                                        offset => $offset, max_date => $max_date, min_date => $min_date,
                                        show => \@show);
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
        } else {

            if ((exists $shows{show_tags}) || 
                (exists $shows{show_comments}) ||
                (exists $shows{show_history})) {
                foreach my $i (@$r) {
                    $pmt->debug("fetching item: " . time());
                    my $item = PMT::Item->retrieve($i->{iid});
                    my $r = $item->full_data();
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
        }
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


