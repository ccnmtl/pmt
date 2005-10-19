use lib qw(..);
use PMT::Common;
package PMT::ActualTime;
use base 'CDBI::DBI';

__PACKAGE__->table('actual_times');
__PACKAGE__->columns(Primary => qw/iid resolver actual_time completed/);
#__PACKAGE__->has_a(iid => 'PMT::Item');
#__PACKAGE__->has_a(resolver => 'PMT::User');

__PACKAGE__->set_sql(interval_total_time =>
                     qq {select sum(a.actual_time) as total
                             from actual_times a, in_group g
                             where a.resolver = g.username and g.grp in
                             ('grp_programmers','grp_webmasters','grp_video',
                              'grp_educationaltechnologists','grp_management')
                             and a.completed > ? and a.completed <= ?;},
                     'Main');

sub interval_total_time {
    my $self = shift;
    my $week_start = shift;
    my $week_end = shift;
    my $sth = $self->sql_interval_total_time;
    $sth->execute($week_start,$week_end);
    my $r = $sth->fetchrow_hashref()->{total};
    $sth->finish();
    return $r;
}


1;
