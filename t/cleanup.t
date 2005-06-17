use strict;
use Test::More tests => 1;

# a special test script that just cleans up some indices after the other
# ones have run

use PMT;
my $PMT = new PMT();
my $db = $PMT->{db};

# delete the regression test user(s), project(s), etc.

my $sql = qq{delete from projects where name = 'regression test project';};
$db->update($sql,[]);

$sql = qq{delete from users where username = 'regressiontestuser';};
$db->update($sql,[]);
$sql = qq{delete from users where username = 'regressiontestuser2';};
$db->update($sql,[]);
$sql = qq{delete from users where username = 'grp_regressiontest';};
$db->update($sql,[]);
$sql = qq{delete from in_group where grp = 'grp_regressiontest';};
$db->update($sql,[]);
$sql = qq{delete from clients where firstname = 'regression test';};
$db->update($sql,[]);

# roll back the sequences so we don't end up with enormous gaps because of
# the tests.

$sql = "select max(pid) from projects;";
my $d = $db->ss($sql,[],['pid']);
$sql = "select setval('projects_s',?);";
$db->update($sql,[$d->{pid}]);
$sql = "select max(iid) from items;";
$d = $db->ss($sql,[],['iid']);
$sql = "select setval('items_s',?);";
$db->update($sql,[$d->{iid}]);
$sql = "select max(mid) from milestones;";
$d = $db->ss($sql,[],['mid']);
$sql = "select setval('milestones_s',?);";
$db->update($sql,[$d->{mid}]);
$sql = "select max(client_id) from clients;";
$d = $db->ss($sql,[],['client_id']);
$sql = "select setval('clients_client_id_seq',?);";
$db->update($sql,[$d->{client_id}]);


ok(1); # because it refuses to run if it doesn't have at least one test
