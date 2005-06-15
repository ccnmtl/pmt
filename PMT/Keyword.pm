use lib qw(..);
package PMT::Keyword;
use base 'CDBI::DBI';
__PACKAGE__->table('keywords');
__PACKAGE__->columns(Primary => qw/keyword iid/);

sub data {
    my $self = shift;
    return {
        keyword => $self->keyword,
    };
}

1;
