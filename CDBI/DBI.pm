use lib qw(..);
use PMT::Config;
my $config = new PMT::Config();
my $dbname = $config->{database};
my $dbuser = $config->{database_username};
my $dbpass = $config->{database_password};

package CDBI::DBI;
use base 'Class::DBI';
__PACKAGE__->set_db('Main' => "DBI:Pg:dbname=$dbname", $dbuser, $dbpass,
{AutoCommit => 1});

sub config {
    my $self = shift;
    return $config;
}
1;
