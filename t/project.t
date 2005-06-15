use strict;
use Test::More tests => 6;
use lib qw(.);
use PMT;
use PMT::Project;

my $name = "regression test project";
my $target_date = "2010-01-01";
my $description = "a project for regression testing";
my $wiki_category = "Regression Test Project";
my $user = CDBI::User->retrieve("regressiontestuser");

my $pmt = new PMT();

my $pid = $pmt->add_project($name, $description, $user->username, 'true',
    $target_date, $wiki_category);

my $project = PMT::Project->retrieve($pid);

ok($project->name eq $name, "name matches");
ok($project->description eq $description, "description matches");

my @users = $project->all_personnel_in_project();
my $found = 0;
foreach my $u (@users) {
    if ($u->username eq $user->username) {
        $found = 1;
    }
}

my $role = $project->project_role($user->username);
ok($role eq "manager", "user is a manager");

ok($found, "caretaker was added to list of users");

$project->add_cc($user);
ok($project->cc($user));

$project->drop_cc($user);
ok(!$project->cc($user));
