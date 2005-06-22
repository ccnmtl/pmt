use strict;
use Test::More tests => 10;
use lib qw(.);
use PMT;
use PMT::User;
use PMT::Group;

my $username = "regressiontestuser";
my $password = "test";
my $email = "anders\@columbia.edu";
my $fullname = "regression test user";

my $PMT = new PMT();
ok($PMT,"new()");
ok($PMT->{db},"has db object");

$PMT->add_user($username,$password,$fullname,$email);
my $u = PMT::User->retrieve($username);
$u->validate($username,$password);
ok(1,"$username validated");

ok($u->username eq $username, "username matches");
ok($u->fullname eq $fullname, "fullname matches");
ok($u->email eq $email, "email matches");
ok($u->status eq "active", "status is correct");


my $passed = 0;
eval {
    $u->validate($username,"not_the_right_password");
};
if($@) {
    $passed = 1;
}
ok($passed,"testuser2 incorrect password didn't validate");

# create a group
my $grp = $PMT->add_group("regressiontest");
$PMT->update_group($grp, [$username]);
my $group = PMT::User->retrieve($grp);
my @programmers = $group->users_in_group();
my $found = 0;
foreach my $u (@programmers) {
    if ($u->username eq $username) {
        $found = 1;
    }
}
ok($found, "users_in_group()");

my $all_group_users = $group->all_users_in_group();
ok(exists $all_group_users->{$username}, "all_users_in_group()");



