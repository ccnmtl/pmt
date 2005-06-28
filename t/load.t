use strict;
use Test::More tests => 19;

BEGIN {
    use_ok("PMT");
    use_ok("PMT::User");
    use_ok("PMT::Project");
    use_ok("PMT::Milestone");
    use_ok("PMT::Item");
    use_ok("PMT::Client");
    use_ok("PMT::Common");
    use_ok("PMT::Config");
    use_ok("PMT::Control");
    use_ok("PMT::Document");
    use_ok("PMT::Event");
    use_ok("PMT::Group");
    use_ok("PMT::Item");
    use_ok("PMT::ItemClients");
    use_ok("PMT::Keyword");
    use_ok("PMT::Notify");
    use_ok("PMT::ProjectClients");
    use_ok("PMT::WorksOn");
    use_ok("PMT::Dependency");
}

use DBI;
my $dbh = DBI->connect("DBI:Pg:dbname=pmt2","anders","",{RaiseError =>
1, AutoCommit => 0});



# delete the regression test user(s), project(s), etc.

$dbh->do(qq{delete from projects where name = 'regression test project';});
$dbh->do(qq{delete from users where username like '%regression%';});
$dbh->do(qq{delete from clients where firstname = 'regression test';});
$dbh->commit;
$dbh->disconnect;
