use strict;
use Test::More tests => 1;

# a special test script that just cleans up some indices after the other
# ones have run

use DBI;
my $dbh = DBI->connect("DBI:Pg:dbname=pmt2","anders","",{RaiseError =>
1, AutoCommit => 0});


# delete the regression test user(s), project(s), etc.

$dbh->do(qq{delete from projects where name = 'regression test project';});
$dbh->do(qq{delete from users where username like '%regression%';});
$dbh->do(qq{delete from clients where firstname = 'regression test';});

# roll back the sequences so we don't end up with enormous gaps because of
# the tests.

$dbh->do(qq{select setval('projects_s',(select max(pid) from projects));});
$dbh->do(qq{select setval('items_s',(select max(iid) from items));});
$dbh->do(qq{select setval('milestones_s',(select max(mid) from milestones));});
$dbh->do(qq{select setval('clients_client_id_seq',(select max(client_id) from clients));});

$dbh->commit;
$dbh->disconnect;

ok(1); # because it refuses to run if it doesn't have at least one test
