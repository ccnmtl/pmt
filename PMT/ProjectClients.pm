use lib qw(..);
package PMT::ProjectClients;
use base 'CDBI::DBI';
__PACKAGE__->table('project_clients');
__PACKAGE__->columns(Primary => qw/pid client_id/);
__PACKAGE__->columns(Others => qw/role/);
__PACKAGE__->columns(Essential => qw/pid client_id role/);

1;
