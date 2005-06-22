use lib qw(..);
use PMT::Common;
package PMT::ActualTime;
use base 'CDBI::DBI';

__PACKAGE__->table('actual_times');
__PACKAGE__->columns(Primary => qw/iid resolver actual_time completed/);
#__PACKAGE__->has_a(iid => 'PMT::Item');
#__PACKAGE__->has_a(resolver => 'PMT::User');

1;
