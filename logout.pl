#!/usr/bin/perl -w
use lib qw(.);
use strict;
use PMT;

my $pmt = PMT->new();
eval {
    $pmt->redirect_with_cookie("login.pl","","");
};


