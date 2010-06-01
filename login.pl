#!/usr/bin/perl -w
use lib qw(.);
use strict;
use CGI;
use PMT::Common;
use PMT::User;
my $cgi = CGI->new();

eval {
    my $username = $cgi->param('username');
    my $password = $cgi->param('password');
    if ($username && $password) {
        my $user = PMT::User->retrieve($username);
        if ($user) {
            $user->validate($username,$password);
            redirect_with_cookie($cgi,"home.pl",$username,$password);
        } else {
            print $cgi->header(), "user $username does not exist. are you sure you've entered it correctly (the PMT is case sensitive)?";
        }
    }
    print_form($cgi);
};
if($@) {
    my $E = $@;
#    exit if $E && ref $E eq 'APR::Error' && $E == ModPerl::EXIT;
    if($E->isa('Error::Simple')) {
        if ($E->isa('Error::NO_USERNAME') ||
            $E->isa('Error::NO_PASSWORD') ||
            $E->isa('Error::AUTHENTICATION_FAILURE')) {
            print $cgi->redirect('login.pl');
        } else {
            print $cgi->header(), "<h1>error:</h1><p>$E->{-text}</p>";
        }
    } else {
        die "unknown error: $E";
    }
}

sub print_form {
    my $cgi = shift;
    print $cgi->header();
    my $template = get_template("login.tmpl");
    $template->param(page_title => "login to PMT");
    print $template->output();
}

