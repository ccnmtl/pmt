#!/usr/bin/perl -w

# unfortunately, CGI::Test doesn't support cookies, so 
# it can't be used for 90% of the site... :(

use strict;
use CGI::Test;

my $ct = CGI::Test->make(
			 -base_url   => "http://www2.ccnmtl.columbia.edu/src/pmt2/",
			 -cgi_dir    => "/home/httpd/html/src/pmt2/",
			 );

my $page = $ct->GET("http://www2.ccnmtl.columbia.edu/src/pmt2/login.pl");
ok 1, $page->content_type =~ m|text/html\b|;

my $form = $page->forms->[0];
ok 2, $form->action eq "login.pl";






