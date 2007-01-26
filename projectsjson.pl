#!/usr/bin/perl -w
use strict;
use lib qw(.);
use PMT;
use Data::Dumper;
use PMT::User;
use JSON;

my $cgi = new CGI();
my $pmt = PMT->new();

my @projects = map {
    {
	pid	      => $_->pid,
	name	      => $_->name,
	pub_view      => $_->pub_view,
	description   => $_->description,
	status	      => $_->status,
	type	      => $_->type,
	area	      => $_->area,
	url	      => $_->url,
	restricted    => $_->restricted,
	approach      => $_->approach,
	info_url      => $_->info_url,
	entry_rel     => $_->entry_rel,
	eval_url      => $_->eval_url,
	projnum	      => $_->projnum,
	scale	      => $_->scale,
	distrib	      => $_->distrib,
	poster	      => $_->poster,
	wiki_category => $_->wiki_category,
    };
} PMT::Project->retrieve_all();

print $cgi->header('application/json');

my $json = new JSON(pretty => 1);
print $json->objToJson({'items' => \@projects});
