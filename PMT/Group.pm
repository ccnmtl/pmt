use lib qw(..);
package PMT::Group;
use base 'CDBI::DBI';
__PACKAGE__->table('in_group');
__PACKAGE__->columns(Primary => qw/grp username/);
__PACKAGE__->has_a(username => 'CDBI::User');
