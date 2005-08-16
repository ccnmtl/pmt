#!/usr/bin/perl -w

# File: view.pl
# Time-stamp: <Tue Aug 16 16:14:04 2005>
#
# anonymous view of an item. 
use strict;

use lib qw(.);
use PMT;
use PMT::Common;
use Data::Dumper;

my $cgi = new CGI();

my $iid = $cgi->param('iid') || "";
my $message = $cgi->param('message') || "";

my $user = PMT::User->retrieve("anonymous");
my $item = PMT::Item->retrieve($iid);

my $template = get_template("anonymous_view.tmpl");
$template->param($item->data());
$template->param(message => $message);
$template->param(page_title => $item->title);

use Text::Tiki;
my $tiki = new Text::Tiki;
$template->param(description_html => $tiki->format($item->description));

my @full_history = ();
my %history_items = ();
 
foreach my $h (@{$item->history()}) {
    $history_items{$h->{event_date_time}} = $h;
}
foreach my $c (@{$item->get_comments()}) {
    $history_items{$c->{add_date_time}} = $c;
}

foreach my $i (sort keys %history_items) {
    my $t = $history_items{$i};
    $t->{timestamp} = $i;
    push @full_history, $t; 
}

$template->param(full_history => \@full_history);
$template->param(resolve_times => $item->resolve_times);

print $cgi->header(), $template->output();
