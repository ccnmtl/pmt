#!/usr/bin/perl -wT

# File: document.pl
# Time-stamp: <Tue Nov 12 16:20:28 2002>

use strict;
use lib qw(.);
use CGI;
use CDBI::User;
use PMT::Project;
use CDBI::User;
use PMT::Document;

my $cgi = new CGI();

eval {
    my $did = $cgi->param('did') || "";
    my $document = PMT::Document->retrieve($did);

    if($document->type eq "url") {
	print $cgi->redirect($document->url);
    } else {
	my $content_type = $document->content_type();
	if($document->content_disposition()) {
	    my $filename = $document->filename;
	    print $cgi->header(-type => $content_type,
			       -content_disposition => "attachment;filename=$filename");
	} else {
	    print $cgi->header(-type => $content_type);
	}
	print $document->contents();
    }
};

if ($@) {
    my $E = $@;
    print $cgi->header(), "caught error: $E";
}
