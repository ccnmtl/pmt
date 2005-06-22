use lib qw(..);
package PMT::WorksOn;
use base 'CDBI::DBI';
__PACKAGE__->table('works_on');
__PACKAGE__->columns(Primary => qw/username pid/);
__PACKAGE__->columns(Essential => qw/username pid auth/);
__PACKAGE__->columns(Others => qw/auth/);
__PACKAGE__->has_a(username => 'PMT::User');
__PACKAGE__->has_a(pid => 'PMT::Project');

1;
