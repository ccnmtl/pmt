use lib qw/../;
package PMT::NotifyProject;
use base 'CDBI::DBI';
__PACKAGE__->table('notify_project');
__PACKAGE__->columns(Primary => qw/pid username/);
__PACKAGE__->columns(Essential => qw/pid username/);

1;
