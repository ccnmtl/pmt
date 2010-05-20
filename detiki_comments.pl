#!/usr/bin/perl -w
use strict;
use lib qw(.);
use PMT;
use PMT::Common;
use PMT::Item;
use Data::Dumper;

my $item = PMT::Item->retrieve(34710);

foreach my $d (@{PMT::Item->all_items()}) {
    my $item = PMT::Item->retrieve($d->{iid});
    $item->detiki_comments();
    print "finished item ", $item->{iid}, "\n";
}


