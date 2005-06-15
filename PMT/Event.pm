use lib qw(..);
package PMT::Event;
use base 'CDBI::DBI';
__PACKAGE__->table('events');
__PACKAGE__->sequence('events_s');
__PACKAGE__->columns(All => qw/eid status event_date_time item/);
__PACKAGE__->has_a(item => 'PMT::Item');
__PACKAGE__->has_many(comments => 'PMT::Comment', 'event');

1;
