use lib qw(..);
package CDBI::User;
use base 'CDBI::DBI';
use PMT::Common;

my %PRIORITIES = (4 => 'CRITICAL', 3 => 'HIGH', 2 => 'MEDIUM', 1 => 'LOW',
0 => 'ICING');

__PACKAGE__->table('users');
__PACKAGE__->columns (Primary          => qw/username/);
__PACKAGE__->columns (All              => qw/fullname email status grp password/);

__PACKAGE__->has_many(nodes            => 'PMT::Node', 'author');
__PACKAGE__->has_many(projects         => 'PMT::Project', 'caretaker');
__PACKAGE__->has_many(documents        => 'PMT::Document', 'author');
__PACKAGE__->has_many(owned_items      => 'PMT::Item', 'owner');
__PACKAGE__->has_many(assigned_items   => 'PMT::Item', 'assigned_to');
__PACKAGE__->has_many(actual_times     => 'PMT::ActualTime', 'resolver');
__PACKAGE__->has_many(notifies         => 'PMT::Notify', 'username');
__PACKAGE__->has_many(works_on         => 'PMT::WorksOn', 'username');
__PACKAGE__->has_many(comments         => 'PMT::Comment', 'username');
__PACKAGE__->has_many(clients          => 'PMT::Client', 'contact');
__PACKAGE__->has_many(project_notifies => 'PMT::NotifyProject', 'username');

__PACKAGE__->add_constructor(all_active => qq{status = 'active' order by
upper(fullname) ASC});

__PACKAGE__->set_sql(total_estimated_time =>  
		     qq{select sum(i.estimated_time) from items i where
			    i.assigned_to = ? 
			    and i.status IN ('OPEN','UNASSIGNED','INPROGRESS');
		    },'Main');
__PACKAGE__->set_sql(watched_items => 
		     qq{
    select i.iid,i.type,i.title,i.priority,i.status,i.r_status,p.name,
       m.pid,i.target_date,to_char(i.last_mod,'YYYY-MM-DD HH24:MI'),
       current_date - i.target_date, i.description, i.assigned_to,
       ua.fullname, i.owner, uo.fullname
       from items i, notify n, milestones m, projects p, users ua, users uo
       where i.iid = n.iid 
           and m.mid = i.mid
           and m.pid = p.pid
           and uo.username = i.owner
           and ua.username = i.assigned_to
           and n.username = ? order by i.last_mod desc limit 20;
},'Main');

sub data {
    my $self = shift;
    return {
        username => $self->username,
        fullname => $self->fullname,
        email => $self->email,
        status => $self->status,
        grp => $self->grp,
    };
}

# {{{ validate

# checks that username and password are valid
# just returns if good. prints an error message and
# dies if authentication fails
sub validate {
    my $self = shift;

    my $username = untaint_username(shift);
    my $password = untaint_password(shift);


    if($self->password eq $password) {
	if($self->status ne "active") {
	    throw Error::InactiveUser "user is inactive and may not login";
	} else {
	    return;
	}
    } else {
	throw Error::INCORRECT_PASSWORD "incorrect password";
    }
}

# }}}


# NOTE: the next 3 methods don't do the recursive user/group thing.

# return Projects that this user manages
sub managed_projects {
    my $self = shift;
    return map {$_->pid} PMT::WorksOn->search(username => $self->username,
        auth => 'manager');
}

# return Projects that this user is a developer on
sub developer_projects {
    my $self = shift;
    return map {$_->pid} PMT::WorksOn->search(username => $self->username,
        auth => 'developer');

}

# return Projects that this user is a guest on
sub guest_projects {
    my $self = shift;
    return map {$_->pid} PMT::WorksOn->search(username => $self->username,
        auth => 'guest');

}


#Min's addition to implement email opt in/out
#as of Thanksgiving Day, this is not being used.  The same subroutine
#in PMT/User.pm  
sub notify_projects {
    my $self = shift;
    my $pid  = shift;

    my @res = PMT::NotifyProject->search(pid => $pid, 
                   username => $self->username);

    if (scalar @res) {
       return 1;
    } else {
       return 0;
    }
}

sub clients_data {
    my $self = shift;
    return [map {$_->data()} $self->clients];
}

# if this user is a group, return the users in that group

sub users_in_group {
    my $self = shift;
    return map { $_->username } PMT::Group->search(grp => $self->username);
}

# recursively go through the users that are in this group (if the user
# is a group) and get all the leaf users
sub all_users_in_group {
    my $self = shift;
    my @groups = ();
    my %users = ();
    # split out the leaf users at this level
    foreach my $u ($self->users_in_group()) {
        if ($u->grp) {
            push @groups, $u;
        } else {
            $users{$u->username} = $u;
        }
    }
    # then go through the groups
    foreach my $g (@groups) {
        foreach my $u (values %{$g->all_users_in_group()}) {
            $users{$u->username} = $u;
        }
    }
    return \%users;
}

sub total_estimated_time {
    my $self = shift;
    my $sth = $self->sql_total_estimated_time;
    $sth->execute($self->username);
    return interval_to_hours($sth->fetchrow_arrayref()->[0]);
}

sub watched_items {
    # returns the recently updated items that the user is on the notify
    # list for
    my $self = shift;
    my $sth = $self->sql_watched_items;
    $sth->execute($self->username);
    return make_classes([map {
            $_->{priority_label} = $PRIORITIES{$_->{priority}};
            $_;
        } map {
	    {
		iid => $_->[0], type => $_->[1], title => $_->[2],
		priority => $_->[3], status => $_->[4], r_status => $_->[5],
		project => $_->[6], pid => $_->[7], target_date => $_->[8], 
		last_mod => $_->[9], overdue => $_->[10], description => $_->[11], 
		assigned_to => $_->[12], assigned_to_fullname => $_->[13], 
		owner => $_->[14], owner_fullname => $_->[15],
	    }
	} @{$sth->fetchall_arrayref()}]);
}

__PACKAGE__->set_sql(events_on => 
		     qq{SELECT e.status,e.event_date_time,e.item,i.title,c.comment,c.username
			    FROM events e, items i, milestones m, comments c, projects p
			    WHERE c.username = ? AND e.item = i.iid AND c.event = e.eid 
			    AND m.pid = p.pid
			    AND i.mid = m.mid AND (p.pid in (select w.pid from works_on w 
							     where username = ?) 
						   OR p.pub_view = 'true')
			    AND date_trunc('day',e.event_date_time) = ?
			    ORDER BY e.event_date_time ASC;
		    }, 'Main');


sub events_on {
    my $self = shift;
    my $date = untaint_date(shift);
    my $viewer = shift;
    my $sth = $self->sql_events_on;
    $sth->execute($self->username,$viewer,$date);
    return [map {
	{
	    status => $_->[0], date_time => $_->[1], iid => $_->[2],
	    title => $_->[3], comment => $_->[4], username => $_->[5],
	}
    } @{$sth->fetchall_arrayref()}];
}

__PACKAGE__->set_sql(estimated_times_by_priority =>
		     qq{select sum(i.estimated_time), i.priority from items i where
			    i.assigned_to = ?
			    and i.status in ('OPEN','UNASSIGNED','INPROGRESS')
			    GROUP BY i.priority;
		    }, 'Main');

sub estimated_times_by_priority {
    my $self = shift;
    my $sth = $self->sql_estimated_times_by_priority;
    $sth->execute($self->username);
    my @results = map {
        $_->{'time'} = interval_to_hours($_->{'time'});
        $_;
    } map {
	{
	    time => $_->[0], priority => $_->[1],
	}
    } @{$sth->fetchall_arrayref()};
    my %priorities = ();
    foreach my $r (@results) {
        $priorities{"priority_" . $r->{priority}} = $r->{'time'};
    }
    return \%priorities;
}

__PACKAGE__->set_sql(estimated_times_by_schedule_status =>
		qq{select i.estimated_time, 
		   current_date - i.target_date as overdue
		       from items i where assigned_to = ?
		       and i.status in ('OPEN','UNASSIGNED','INPROGRESS');
	       }, 'Main');     

sub estimated_times_by_schedule_status {
    my $self = shift;
    my $sth = $self->sql_estimated_times_by_schedule_status;
    $sth->execute($self->username);
    my %statuses = (overdue => 0, late => 0, due => 0, upcoming => 0, ok =>
        0);
    foreach my $res (@{$sth->fetchall_arrayref()}) {
        my $t = interval_to_hours($res->[0]);
        if ($res->[1] < -7) {
            $statuses{ok} += $t;
        } elsif ($res->[1] < -1) {
            $statuses{'upcoming'} += $t;
        } elsif ($res->[1] < 1) {
            $statuses{'due'} += $t;
        } elsif ($res->[1] < 7) {
            $statuses{'overdue'} += $t;
        } else {
            $statuses{'late'} += $t;
        }
    }
    return \%statuses;
}

__PACKAGE__->set_sql(estimated_times_by_project => 
		     qq{select sum(i.estimated_time),p.pid,p.name
			    from items i, milestones m, projects p
			    where i.mid = m.mid and m.pid = p.pid and i.assigned_to = ?
			    and i.status in ('OPEN','INPROGRESS','UNASSIGNED')
			    GROUP BY p.pid,p.name;},
		     'Main');

sub estimated_times_by_project {
    my $self = shift;
    my $sth = $self->sql_estimated_times_by_project;
    $sth->execute($self->username);
    return [map {
        $_->{time} = interval_to_hours($_->{time});
        $_;
    } map {
	{
	    time => $_->[0], pid => $_->[1], project => $_->[2],
	}
    }
    @{$sth->fetchall_arrayref()}];
}

__PACKAGE__->set_sql(resolve_times_for_interval =>
		     qq{select a.actual_time, to_char(a.completed,'YYYY-MM-DD HH24:MI:SS'), 
			a.iid, i.title, p.pid, p.name
			    from actual_times a, items i, milestones m, projects p
			    where a.iid = i.iid
			    and i.mid = m.mid
			    and m.pid = p.pid
			    and a.resolver = ?
			    and a.completed > ? and a.completed <= date(?) + interval '1 day'
			    order by a.completed ASC;},
		     'Main');

sub resolve_times_for_interval {
    my $self       = shift;
    my $start_date = shift;
    my $end_date   = shift;
    my $sth        = $self->sql_resolve_times_for_interval;
    $sth->execute($self->username,$start_date,$end_date);
    return [map {
	{
	    'actual_time' => $_->[0],
	    'completed' => $_->[1],
	    'iid' => $_->[2],
	    'item' => $_->[3],
	    'pid' => $_->[4],
	    'project' => $_->[5],
	}
    } @{$sth->fetchall_arrayref()}];
}

__PACKAGE__->set_sql(project_completed_time_for_interval =>
		     qq{	
			 select sum(a.actual_time) from actual_times a, items i, milestones m
			     where a.resolver = ? 
			     and a.iid = i.iid and i.mid = m.mid and m.pid = ?
			     and a.completed > ? and a.completed <= date(?) + interval '1 day';
		     }, 'Main');


sub project_completed_time_for_interval {
    my $self = shift;
    my $pid = shift;
    my $start_date = shift;
    my $end_date = shift;
    my $sth = $self->sql_project_completed_time_for_interval;
    $sth->execute($self->username,$pid,$start_date,$end_date);
    return $sth->fetchrow_arrayref()->[0]->[0];
}

__PACKAGE__->set_sql(total_completed_time =>
		     qq{
			 select sum(actual_time) as time
			     from actual_times where resolver = ?;},
		     'Main');

sub total_completed_time {
    my $self = shift;
    my $sth = $self->sql_total_completed_time;
    $sth->execute($self->username);
    return interval_to_hours($sth->fetchrow_arrayref()->[0]->[0]);
}



1;
