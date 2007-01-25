#!/usr/bin/perl -w
use strict;
use lib qw(.);
use PMT;
use Data::Dumper;
use PMT::User;
use JSON;

my $cgi = new CGI();
my $pmt = PMT->new();


#	"items" : [
#        {   type :         "Staff",
#            label :        "John Zimmerman",
#            building :     "Armory",
#            campus :	   "CUMC",
#            room :	   "200 Level",
#            email :        "zim@columbia.edu",
#            last :         "Zimmerman",
#            first :	   "John",
#            phone :        "646 772-8607",
#            title :        "Associate Director",
#            group :	    "Management",
#            bio :	    "Dr. Zimmerman manages the Health Sciences office of CCNMTL, working with a dedicated Health Sciences-CCNMTL staff and faculty at all of the Health Sciences Schools to develop course Web sites and major projects. As Assistant Dean for Information Resources, Associate Professor of Clinical Dentistry at Columbia University School of Dental and Oral Surgery and Associate Professor of Clinical Medical Informatics in the College of Physicians and Surgeons, Dr. Zimmerman coordinates the clinical, research, and educational informatics initiatives at the dental school and is director of the Dental Informatics Fellowship program.  He has published numerous dental informatics articles as well as the book _Dental Informatics: Integrating Technology into the Dental Environment_ and the monograph _Dental Informatics: Strategic Issues for the Dental Profession_. Dr. Zimmerman has been active in the field of dental information for many years and is the founder of American Medical Informatics Association's Working Group 4 - Dental Informatics and a member of the International Medical Informatics Association, Working Group 11- Dental Informatics. He was the first dentist elected to American College of Medical Informatics.",
#            imageURL :      "http://ccnmtl.columbia.edu/web/assets/headshots/Zimmerman.jpg"     
#        },


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
	'imageURL' => $_->photo_height,
	'building' => $_->building,
	'campus' => $_->campus,
	'room' => $_->room,
    };
} PMT::User->search(type => 'Staff',status=>'active', grp => 'f');

print $cgi->header('application/json');


my $json = new JSON(pretty => 1);
print $json->objToJson({'items' => \@users});

