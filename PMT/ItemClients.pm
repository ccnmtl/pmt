use lib qw(..);
package PMT::ItemClients;
use base 'CDBI::DBI';
__PACKAGE__->table('item_clients');
__PACKAGE__->columns(Primary => qw/iid client_id/);

1;
