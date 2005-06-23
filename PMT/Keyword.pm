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

# gets a list of items associated with specified keyword
# if pid is specified, it will only get items from that
# project
sub keyword_data {
    my $keyword  = shift;
    my $pid = shift || "";
    my %data;

    if($pid ne "") {
        $data{items} = [map {
            PMT::Item->retrieve($_->iid)->data()
        } grep {
            PMT::Item->retrieve($_->iid)->mid->pid->pid == $pid;
        } PMT::Keyword->search(keyword => $keyword)];
    } else {
        $data{items} = [map {PMT::Item->retrieve($_->iid)->data()} PMT::Keyword->search(keyword
            => $keyword)];
    }
    $data{pid} = $pid;
    $data{keyword} = $keyword;
    return \%data;
}


1;
