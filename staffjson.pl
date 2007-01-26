#!/usr/bin/perl -w
use strict;
use lib qw(.);
use PMT;
use Data::Dumper;
use PMT::User;
use JSON;

my $cgi = new CGI();
my $pmt = PMT->new();

my @users = map {
    {
	'type' => $_->type,
	'label' => $_->fullname,
	'first' => $_->firstname(),
	'last'  => $_->lastname(),
	'phone'    => $_->phone,
	'bio'      => $_->bio,
	'email'    => $_->email,
	'title'    => $_->title,
	'photo_url' => $_->photo_url,
	'photo_width' => $_->photo_width,
	'group' => $_->calculate_group(),
	'imageURL' => $_->photo_url,
	'building' => $_->building,
	'campus' => $_->campus,
	'room' => $_->room,
    };
} PMT::User->search(type => 'Staff',status=>'active', grp => 'f');

print $cgi->header('application/json');


my $json = new JSON(pretty => 1);
print $json->objToJson({'items' => \@users});

