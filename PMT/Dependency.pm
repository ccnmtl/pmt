use lib qw(..);
package PMT::Dependency;
use base 'CDBI::DBI';
__PACKAGE__->table('dependencies');
__PACKAGE__->columns(Primary => qw/source dest/);
__PACKAGE__->columns(Essential => qw/source dest/);
__PACKAGE__->columns(All => qw/source dest/);

1;
