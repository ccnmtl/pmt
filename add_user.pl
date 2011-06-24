#!/usr/bin/perl -w
use lib qw(.);
use strict;
use Digest::SHA1  qw(sha1_hex);
use PMT;

my $pmt = PMT->new();
my $cgi = CGI->new();




eval {
    my $username = $cgi->param('username');
    my $password = $cgi->param('password');
    my $pass_ver = $cgi->param('pass_ver');
    my $fullname = $cgi->param('fullname');
    my $email    = $cgi->param('email');

    if ($username && $password && $pass_ver && $fullname && $email) {
        throw Error::PASSWORD_MISMATCH "passwords do not match" unless $password eq $pass_ver;

	my @letters = ('a' .. 'z', '0' .. '9');
	my $salt = "";
	$salt.= $letters[rand(36)] foreach(1..5);	
	my $hash = sha1_hex($salt . $password);
	
        my $u = PMT::User->create({username => $username, fullname => $fullname, email => $email,
                                   password => 'sha1$' . $salt . '$' . $hash});
        print $cgi->redirect("login.pl");
    } else {
        print_form($cgi);
    }
};
if($@) {
    my $E = $@;
    if($E->isa('Error::Simple')) {
        if ($E->isa('Error::NO_USERNAME') ||
            $E->isa('Error::NO_PASSWORD') ||
            $E->isa('Error::AUTHENTICATION_FAILURE')) {
            print $cgi->redirect('../login.pl');
        } else {
            print $cgi->header(), "<h1>error:</h1><p>$E->{-text}</p>";
        }
    } else {
        die "unknown error: $E";
    }
}

sub print_form {
    my $cgi = shift;
    print $cgi->redirect("new/add_user.html");
}
