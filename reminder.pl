#!/usr/bin/perl -w
use strict;
use lib qw(.);
use PMT;
use Mail::Sendmail;

my $cgi = CGI->new();

eval {
    my $username = $cgi->param('username') || "";
    throw Error::NO_USERNAME "no username specified" unless $username;
    my $user = PMT::User->retrieve($username);

    my $r = $user->user_info();
    my %data = %$r;
    my $body = <<END_MESSAGE;

username: $data{'user_username'}
password: $data{'password'}
END_MESSAGE


    my %mail = (To => $data{'user_email'},
                From => "Project Management Tool <pmt2\@pmt.ccnmtl.columbia.edu>",
                Subject => "PMT password reminder",
                Message => $body,
                smtp => 'oldsmtp.columbia.edu');
    Mail::Sendmail::sendmail(%mail) or die $Mail::Sendmail::error;


        print $cgi->header, "reminder sent to $data{'user_email'}";
};
if($@) {
    my $E = $@;
    if($E->isa('Error::Simple')) {
        if ($E->isa('Error::NO_USERNAME') ||
            $E->isa('Error::NO_PASSWORD') ||
            $E->isa('Error::AUTHENTICATION_FAILURE')) {
            print $cgi->redirect('login.pl');
        } elsif ($E->isa('Error::NO_USER')) {
            print $cgi->header(), "that user doesn't appear to exist";
        } else {
            print $cgi->header(), "<h1>error:</h1><p>$E->{-text}</p>";
        }
    } else {
        die "unknown error: $E";
    }
}


