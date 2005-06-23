use strict;
use Test::More tests => 6;
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
my $manager = PMT::WorksOn->create({username => $user, pid => $project, auth => 'manager'});

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
