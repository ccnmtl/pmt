use lib qw(..);
package PMT::Notify;
use base 'CDBI::DBI';
__PACKAGE__->table('notify');
__PACKAGE__->columns(Primary => qw/iid username/);
__PACKAGE__->columns(Essential => qw/iid username/);
__PACKAGE__->columns(Others => qw//);
#__PACKAGE__->has_a(iid => 'PMT::Item');
#__PACKAGE__->has_a(username => 'CDBI::User');

1;
