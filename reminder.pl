#!/usr/bin/perl -w
use strict;
use lib qw(.);
use PMT;
use Mail::Sendmail;
use Digest::SHA1  qw(sha1_hex);

my $cgi = CGI->new();

eval {
    my $username = $cgi->param('username') || "";
    throw Error::NO_USERNAME "no username specified" unless $username;
    my $user = PMT::User->retrieve($username);

    my $r = $user->user_info();

    # make a new password
    my @letters = ('a' .. 'z', '0' .. '9');
    my $password = "";
    $password .= $letters[rand(36) foreach(1..10)];

    # hash it and set it
    my $salt = "";
    $salt.= $letters[rand(36)] foreach(1..5);	
    my $hash = sha1_hex($salt . $password);
    $user->password('sha1$' . $salt . '$' . $hash);

    # email the user
    my %data = %$r;
    my $body = <<END_MESSAGE;

username: $data{'user_username'}
new password: $password

Please login and use the 'Profile' link at the top of the
page to change your password to one that you can remember.

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


