use lib qw(..);
package PMT::WorksOn;
use base 'CDBI::DBI';
use PMT::Common;
__PACKAGE__->table('works_on');
__PACKAGE__->columns(Primary => qw/username pid/);
__PACKAGE__->columns(Essential => qw/username pid auth/);
__PACKAGE__->columns(Others => qw/auth/);
#__PACKAGE__->has_a(username => 'PMT::User');
#__PACKAGE__->has_a(pid => 'PMT::Project');


__PACKAGE__->set_sql(works_on_select =>
		     qq{select u.username,u.fullname
			    from users u where u.username in 
			    ( select distinct w.username from works_on w
			      where w.auth = ?)
			    and u.status = 'active'
			    order by upper(u.fullname) asc;},
		     'Main');
sub works_on_select {
    my $self = shift;
    my $role = shift || "manager";
    my $sth = $self->sql_works_on_select;
    $sth->execute($role);

    my @fullnames = ();
    my @usernames = map {
	push @fullnames, $_->{fullname};
	$_->{username};
    } @{$sth->fetchall_arrayref({})};
    return selectify(\@usernames,\@fullnames,[]);
}



1;
