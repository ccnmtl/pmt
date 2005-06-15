use lib qw(..);
package PMT::Comment;
use base 'CDBI::DBI';
__PACKAGE__->table('comments');
__PACKAGE__->sequence('comments_s');
__PACKAGE__->columns(All => qw/cid comment add_date_time username item
event/);
__PACKAGE__->has_a(username => 'CDBI::User');
__PACKAGE__->has_a(item => 'PMT::Item');
__PACKAGE__->has_a(event => 'PMT::Event');

1;
