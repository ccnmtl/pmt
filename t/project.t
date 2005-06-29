use strict;
use Test::More tests => 15;
use lib qw(.);
use PMT;
use PMT::Project;

my $name = "regression test project";
my $target_date = "2010-01-01";
my $description = "a project for regression testing";
my $wiki_category = "Regression Test Project";
my $user = PMT::User->retrieve("regressiontestuser");

my $pmt = new PMT();

my $project = PMT::Project->create({name => $name, pub_view => 'true',
   				caretaker => $user, description => $description,
				status => 'planning', wiki_category => $wiki_category});
my $manager = PMT::WorksOn->create({username => $user->username, pid => $project->pid, auth => 'manager'});

$project->add_milestone("Final Release",$target_date,"project completion");


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

# some extra simple tests to catch runtime errors
$project->interval_total("2005-01-01","2005-01-07");
ok(1);
$project->add_item_form("bug","regressiontestuser");
ok(1);
$project->project_milestones_select();
ok(1);
$project->upcoming_milestone();
ok(1);
$project->project_milestones("regressiontestuser");
ok(1);
$project->events_on("2005-01-01");
ok(1);
$project->recent_events();
ok(1);
$project->recent_items();
ok(1);
$project->group_hours("grp_programmers","2005-01-01","2005-01-07");
ok(1);
