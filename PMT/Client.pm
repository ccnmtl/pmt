use lib qw(..);
package PMT::Client;
use base 'CDBI::DBI';

__PACKAGE__->table('clients');
__PACKAGE__->sequence('clients_client_id_seq');
__PACKAGE__->columns(All => qw/client_id lastname firstname title
registration_date department school add_affiliation phone email contact
comments status/);
__PACKAGE__->has_a(contact => 'PMT::User');
__PACKAGE__->has_many(items => 'PMT::ItemClients', 'client_id');
__PACKAGE__->has_many(projects => 'PMT::ProjectClients', 'client_id');
__PACKAGE__->add_constructor(all_active => qq{status = 'active' order by
upper(lastname) ASC, upper(firstname) ASC});
__PACKAGE__->set_sql(total_clients_by_school => qq{
select school, count(*) from clients group by school;
}, 'Main');

__PACKAGE__->set_sql(total_clients_by_school_for_date => qq{
select school, count(*) from clients 
where registration_date like ?
group by school;}, 'Main');

__PACKAGE__->set_sql(existing_clients => 
		     qq{
			 select c.client_id,c.email,c.lastname,c.firstname,
			 c.school,c.department,c.contact,u.fullname
			     from clients c, users u 
			     where c.contact = u.username 
			     and (c.email ilike ? 
				  or upper(c.lastname) = upper(?));},
		     'Main');
__PACKAGE__->set_sql(recent_items => qq{
    select i.iid, i.title, p.name, p.pid, i.status,i.type,
    to_char(i.last_mod,'YYYY-MM-DD HH24:MI') as last_mod
	from items i, milestones m, projects p 
	where i.mid = m.mid and m.pid = p.pid
	and 
	((i.iid in (select ic.iid from item_clients ic where ic.client_id = ?)) 
	 or 
	 (p.pid in (select pc.pid from project_clients pc where pc.client_id = ?)))
	order by i.last_mod desc limit 10;},
		     'Main');

__PACKAGE__->set_sql(all_clients_data => qq{
	SELECT c.client_id,c.lastname,c.firstname,c.title,c.department,
	       c.school,c.add_affiliation,c.phone,c.email,
	       c.contact,c.comments,c.registration_date,u.fullname,
	       c.status, to_char(max(i.last_mod),'YYYY-MM-DD HH24:MI')
        FROM clients c 
        LEFT OUTER JOIN item_clients ic on c.client_id = ic.client_id
        LEFT OUTER JOIN items i on ic.iid = i.iid
        JOIN users u on c.contact = u.username
	WHERE
	      upper(c.lastname) like upper(?)
        GROUP BY c.client_id,c.lastname,c.firstname,c.title,c.department,
	       c.school,c.add_affiliation,c.phone,c.email,
	       c.contact,c.comments,c.registration_date,u.fullname,
	       c.status
	       ORDER BY upper(c.lastname) ASC, upper(c.firstname);
    }, 'Main');
__PACKAGE__->set_sql(new_clients_data => qq{
	SELECT c.client_id,c.lastname,c.firstname,c.title,c.department,
	       c.school,c.add_affiliation,c.phone,c.email,
	       c.contact,c.comments,c.registration_date,u.fullname
        FROM clients c, users u
	WHERE c.contact = u.username
	AND c.registration_date >= ? AND c.registration_date <= ?
        ORDER BY c.registration_date ASC;
    }, 'Main');
    

__PACKAGE__->set_sql(projects_select => qq{
    SELECT p.pid,p.name
	FROM projects p
	ORDER BY upper(p.name) ASC;
    }, 'Main');

use PMT::Common;

open(SCHOOLS_FILE,"config/schools.txt") or die "couldn't read in schools";
my @SCHOOLS = grep {$_ ne ""} map {$_ =~ s/\s+$//; $_ =~ s/^\s+//; $_;} <SCHOOLS_FILE>;
close SCHOOLS_FILE;
open(DEPS_FILE,"config/departments.txt") or die "couldn't read in
    departments";
my @DEPARTMENTS = grep {$_ ne ""} map {$_ =~ s/\s+$//; $_ =~ s/^\s+//; $_;} <DEPS_FILE>;
close DEPS_FILE;

sub all_clients_data {
    my $self = shift;
    my $letter = shift;
    my $sth = $self->sql_all_clients_data;
    $sth->execute("$letter%");
    return [map {
	{
	    client_id => $_->[0],
	    lastname => $_->[1],
	    firstname => $_->[2],
	    title => $_->[3],
	    department => $_->[4],
	    school => $_->[5],
	    add_affiliation => $_->[6],
	    phone => $_->[7],
	    email => $_->[8],
	    contact => $_->[9],
	    comments => $_->[10],
	    registration_date => $_->[11],
	    contact_fullname => $_->[12],
	    status => $_->[13],
	    last_mod => $_->[14],
	}
    } @{$sth->fetchall_arrayref()}];
}

sub new_clients_data {
    my $self = shift;
    my $start_date = shift;
    my $end_date = shift;
    my $sth = $self->sql_new_clients_data;
    $sth->execute($start_date,$end_date);
    return [map {
	{
	    client_id => $_->[0],
	    lastname => $_->[1],
	    firstname => $_->[2],
	    title => $_->[3],
	    department => $_->[4],
	    school => $_->[5],
	    add_affiliation => $_->[6],
	    phone => $_->[7],
	    email => $_->[8],
	    contact => $_->[9],
	    comments => $_->[10],
	    registration_date => $_->[11],
	    contact_fullname => $_->[12],
	} 
    } @{$sth->fetchall_arrayref()}];
}

sub recent_items {
    my $self = shift;
    my $sth = $self->sql_recent_items;
    $sth->execute($self->client_id,$self->client_id);
    return [map {
        $_->{type_class} = $_->{type};
        $_->{type_class} =~ s/\s//g;
        $_;
    } map {
	{
	    iid      => $_->[0],
	    title    => $_->[1],
	    project  => $_->[2],
	    pid      => $_->[3],
	    status   => $_->[4],
	    type     => $_->[5],
	    last_mod => $_->[6],
	}
    } @{$sth->fetchall_arrayref()}];
}

sub existing_clients {
    my $self = shift;
    my $uni = shift;
    my $lastname = shift;
    my $sth = $self->sql_existing_clients;
    $sth->execute("$uni%",$lastname);
    return [map {
	{
	    client_id => $_->[0],
	    email => $_->[1],
	    lastname => $_->[2],
	    firstname => $_->[3],
	    school => $_->[4],
	    department => $_->[5],
	    contact_username => $_->[6],
	    contact_fullname => $_->[7],
	}
    } @{$sth->fetchall_arrayref()}];
}

sub data {
    my $self = shift;
    return {
        client_id => $self->client_id,
        lastname => $self->lastname,
        firstname => $self->firstname,
        title => $self->title,
        registration_date => $self->registration_date,
        department => $self->department,
        school => $self->school,
        add_affiliation => $self->add_affiliation,
        phone => $self->phone,
        email => $self->email,
        contact => $self->contact,
        comments => $self->comments,
        status => $self->status
    };
}

sub contacts_select {
    my $self = shift;
    my @values = ();
    my @labels = map {
	push @values, $_->username;
	$_->fullname;
    } PMT::User->all_active();
    return selectify(\@values,\@labels,[$self->contact->username]);
}

sub schools_select {
    my $self = shift;
    my $school = $self->school;
    return selectify(\@SCHOOLS,[@SCHOOLS],[$school]);
}

sub all_schools_select {
    my $self = shift;
    my $school = shift || "Arts & Sciences";
    return selectify(\@SCHOOLS,[@SCHOOLS],[$school]);
}

sub all_departments_select {
    my $self = shift;
    my $department = shift || "";
    if ($department eq "nodepartment") {
	$department = $self->department;
    }
    return selectify(\@DEPARTMENTS,[@DEPARTMENTS],[$department]);
}

sub projects_data {
    my $self = shift;

    return [map {
	my $p = PMT::Project->retrieve($_->pid);
	my $data = $p->data();
	$data->{role} = $_->role;
	$data;
    } $self->projects()];
}

# returns data structure for making a select
# list of all projects with the ones that this
# client is on selected.
sub projects_select {
    my $self = shift;
    my @values = ();
    my $sth = $self->sql_projects_select();
    $sth->execute();
    my @labels = map {
	push @values, $_->[0];
	$_->[1];
    } @{$sth->fetchall_arrayref()};
    my @selected = map {$_->pid} $self->projects();
    return selectify(\@values,\@labels,\@selected);
}


sub total_clients_by_school {
    my $self = shift;
    my $sth = $self->sql_total_clients_by_school;
    $sth->execute();
    my %counts = map { 
        $_->[0] => $_->[1];
    } @{$sth->fetchall_arrayref()};
    
    my @schools = map { 
        my %data = ();
        $data{school} = $_;
        $data{count} = $counts{$_} || "0";
        \%data;
    } @SCHOOLS;
    return \@schools;
}

sub total_clients_by_school_for_month {
    my $self = shift;
    my $year = shift;
    my $month = shift;
    
    my $sth = $self->sql_total_clients_by_school_for_date; 
    $sth->execute("$year-$month-%");
    my %counts = map { 
        $_->[0] => $_->[1];
    } @{$sth->fetchall_arrayref()};
    
    my @schools = map { 
        my %data = ();
        $data{school} = $_;
        $data{count} = $counts{$_} || "0";
        \%data;
    } @SCHOOLS;
    return \@schools;

}

sub total_clients_by_school_for_year {
    my $self = shift;
    my $year = shift;
    
    my $sth = $self->sql_total_clients_by_school_for_date; 
    $sth->execute("$year-%");
    my %counts = map { 
        $_->[0] => $_->[1];
    } @{$sth->fetchall_arrayref()};
    
    my @schools = map { 
        my %data = ();
        $data{school} = $_;
        $data{count} = $counts{$_} || "0";
        \%data;
    } @SCHOOLS;
    return \@schools;

}

sub update_data {
    my $self = shift;
    my %args = @_;
    $self->lastname($args{lastname});
    $self->firstname($args{firstname});
    $self->title($args{title});
    $self->department($args{department});
    $self->school($args{school});
    $self->add_affiliation($args{add_affiliation});
    $self->phone($args{phone});
    $self->email($args{email});
    $self->contact($args{contact});
    $self->comments($args{comments});
    $self->registration_date($args{registration_date});
    $self->status($args{status});

    my %pids = map {$_ => 1} @{$args{projects}};
    my %existing = ();
    # remove any that the client isn't on anymore
    foreach my $project ($self->projects()) {
	if (!exists $pids{$project->pid}) {
	    $project->delete();
	} else {
	    $existing{$project->pid} = 1;
	}
    }
    # add any new ones

    foreach my $pid (@{$args{projects}}) {
	if (!exists $existing{$pid}) {
	    my $pc = PMT::ProjectClients->create({
		pid => $pid, client_id => $self->client_id});
	}
    }
}

sub find_by_uni {
    my $self = shift;
    my $uni = shift;
    my @clients = __PACKAGE__->search(email => $uni);
    if (@clients) { return @clients; }
    return __PACKAGE__->search(email => "$uni\@columbia.edu");
    
}

sub client_search {
    my $self = shift;
    my %args = @_;
    
    my $sql = "";
    my @vars = ("%$args{query}%","%$args{query}%","%$args{query}%",
        $args{department},$args{school},$args{contact},
        $args{start_date},$args{end_date},"$args{status}%");
    if ($args{project} eq "%" or $args{project} eq "") {
        $sql = qq{select c.client_id,c.lastname,c.firstname,c.registration_date as registered,
        c.department,c.school,c.status,c.contact as contact_username,u.fullname as contact_fullname, 
        to_char(max(i.last_mod), 'YYYY-MM-DD HH24:MI')
        from clients c left outer join item_clients ic on c.client_id =
        ic.client_id left outer join items i on ic.iid = i.iid
        join users u on c.contact = u.username
        where 
            (c.email ilike ? or c.lastname ilike ? or c.firstname ilike ?)
            and c.department ilike ?
            and c.school ilike ?
            and c.contact like ?
            and c.registration_date >= ?
            and c.registration_date <= ?
            and c.status like ?
        group by c.client_id,c.lastname,c.firstname,c.registration_date,
        c.department,c.school,c.status,c.contact,u.fullname
        order by upper(c.lastname), upper(c.firstname) limit $args{limit}
        offset $args{offset};
    };
    } else {
        $sql = qq{select c.client_id,c.lastname,c.firstname,c.registration_date as registered,
        c.department,c.school,c.status,c.contact as contact_username,u.fullname as contact_fullname,
        to_char(max(i.last_mod),'YYYY-MM-DD HH24:MI') as last_mod
        from clients c
        left outer join item_clients ic on c.client_id = ic.client_id
        left outer join items on ic.iid = i.iid
        join users u on c.contact = u.username
        join project_clients p on p.client_id = c.client_id
        where (c.email ilike ? or c.lastname ilike ? or c.firstname ilike ?)
            and c.department ilike ?
            and c.school ilike ?
            and c.contact like ?
            and c.registration_date >= ?
            and c.registration_date <= ?
            and c.status like ?
            and p.pid like ?
        group by c.client_id,c.lastname,c.firstname,c.registration_date,
        c.department,c.school,c.status,c.contact,u.fullname
        order by upper(c.lastname), upper(c.firstname) limit $args{limit}
        offset $args{offset};
        };
        push @vars, $args{project};
    }
    $self->set_sql(client_search => $sql, 'Main');
    my $sth = $self->sql_client_search;
    $sth->execute(@vars);
    return $sth->fetchall_arrayref({});
}
# }}}


1;
