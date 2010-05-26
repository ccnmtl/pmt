use lib qw(..);
package PMT::WorksOn;
use base 'CDBI::DBI';
use PMT::Common;
__PACKAGE__->table('works_on');
__PACKAGE__->columns(Primary => qw/username pid/);
__PACKAGE__->columns(Essential => qw/username pid auth/);
__PACKAGE__->columns(Others => qw/auth/);

__PACKAGE__->set_sql(personnel_select =>
		     qq{select u.username,u.fullname
			    from users u where 
			    u.status = 'active'
			    order by upper(u.fullname) asc;},
		     'Main');

sub personnel_select {
    my $self = shift;
    my $sth = $self->sql_personnel_select;
    $sth->execute();

    my @fullnames = ();
    my @usernames = map {
	push @fullnames, $_->{fullname};
	$_->{username};
    } @{$sth->fetchall_arrayref({})};
    return selectify(\@usernames,\@fullnames,[]);

}


1;
