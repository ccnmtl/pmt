use strict;
use Test::More tests => 17;
use lib qw(.);
use PMT;
use PMT::Client;

my $firstname = "regression test";
my $lastname = "regression test";
my $title = "regression test";
my $registration_date = "2000-01-01";
my $department = "regression test";
my $school = "regression test";
my $phone = "regression test";
my $email = "regressiontest\@columbia.edu";
my $comments = "this is a regression test user. if it shows up in
production data somehow, please report it.";
my $status = "active";
my $contact = PMT::User->retrieve("regressiontestuser");

my $client = PMT::Client->create({firstname => $firstname, lastname =>
$lastname, title => $title, registration_date => $registration_date,
department => $department, school => $school, phone => $phone, email =>
$email, comments => $comments, status => $status, contact => $contact});

ok($client->firstname eq $firstname, "firstname matches");
ok($client->lastname eq $lastname, "lastname matches");
ok($client->title eq $title, "title matches");
ok($client->registration_date eq $registration_date, "reg. date matches");
ok($client->department  eq $department, "department matches");
ok($client->school eq $school, "school matches");
ok($client->phone eq $phone, "phone matches");
ok($client->email eq $email, "email matches");
ok($client->comments eq $comments, "comments match");
ok($client->contact->username eq $contact->username, "contact matches");

# test contacts_select()
my $select_data = $client->contacts_select();
ok(ref($select_data) eq "ARRAY", "it should be a reference to an array");
ok(ref($select_data->[0]) eq "HASH", "there should be at least one element and that
element should be a reference to a hash");
ok(exists $select_data->[0]->{value}, "there should be a 'value' element in the
hash");
ok(exists $select_data->[0]->{label}, "there should be a 'label' element in the
hash");

my $found = 0;
foreach my $r (@{$select_data}) {
    if ($r->{value} eq $client->contact->username) {
        $found = 1;
        ok($r->{label} eq $client->contact->fullname, "label should be the
        contact's fullname");
        ok($r->{selected}, "that element should be selected");
        last;
    }
}
ok($found, "the contact showed up in the list");


