use strict;
use Test::More tests => 41;
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

eval {
     my $ou = PMT::User->retrieve($username);
     $ou->delete();
     $ou->update();
};

my $u = PMT::User->create({username => $username, fullname => $fullname, email => $email, 
			       password => $password});
$u->validate($username,$password);
ok(1,"$username validated");

ok($u->username eq $username, "username matches");
ok($u->fullname eq $fullname, "fullname matches");
ok($u->email eq $email, "email matches");
ok($u->status eq "active", "status is correct");

my $ui = $u->user_info();
ok($ui->{password} eq $password, "password comes back from user_info()");

my $passed = 0;
eval {
    $u->validate($username,"not_the_right_password");
};
if($@) {
    $passed = 1;
}
ok($passed,"testuser2 incorrect password didn't validate");

# create a group
eval {
     my $og = PMT::User->retrieve("regressiontestgroup");
     $og->delete();
     $og->update();
};
my $grp = $PMT->add_group("regressiontestgroup");
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

# just some misc calls to catch runtime errors
#$u->weekly_report("2005-01-01","2005-01-07");
$u->user_info();
ok(1);
$u->user_groups();
ok(1);
$u->projects_by_auth('manager');
ok(1);
$u->projects_by_auth('developer');
ok(1);
$u->projects_by_auth('guest');
ok(1);
$u->projects_hash();
ok(1);
$u->interval_time("2005-01-01","2005-01-07");
ok(1);
$u->active_projects("2005-01-01","2005-01-07");
ok(1);
$u->total_breakdown();
ok(1);
$u->all_projects();
ok(1);
$u->notify_projects(9);
ok(1);
$u->clients_data();
ok(1);
$u->users_in_group();
ok(1);
$u->all_users_in_group();
ok(1);
$u->total_estimated_time();
ok(1);
$u->watched_items();
ok(1);
$u->events_on("2005-01-01");
ok(1);
$u->estimated_times_by_priority();
ok(1);
$u->estimated_times_by_schedule_status();
ok(1);
$u->estimated_times_by_project();
ok(1);
$u->resolve_times_for_interval("2005-01-01","2005-01-07");
ok(1);
$u->project_completed_time_for_interval(9,"2005-01-01","2005-01-07");
ok(1);
$u->total_completed_time();
ok(1);
$u->total_group_time();
ok(1);
$u->items($u->username);
ok(1);
$u->quick_edit_data();
ok(1);
$u->home();
ok(1);
$u->menu();
ok(1);
$u->users_select();
ok(1);
$u->groups();
ok(1);
$u->users_hours();
ok(1);


