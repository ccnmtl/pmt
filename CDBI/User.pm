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

sub user_info {
    my $self = shift;
    my $data = $self->data();
    $data->{user_username} = $data->{username};
    $data->{user_fullname} = $data->{fullname};
    $data->{user_email} = $data->{email};
    delete $data->{username};
    delete $data->{fullname};
    delete $data->{email};
    delete $data->{status};

    throw Error::NonexistantUser "user does not exist" 
        unless $data->{user_username};
    return $data;
}

__PACKAGE__->set_sql(user_groups => qq{
    select u.username,u.fullname 
	from users u, in_group i 
	where u.username = i.grp and i.username = ?;},
		     'Main');

# lists the group that a specified user is part of
sub user_groups {
    my $self = shift;
    my $sth = $self->sql_user_groups;
    $sth->execute($self->username);
    
    return [map {
	$_->{group_name} =~ s/ \(group\)$//;
	$_;
    } map {
	{
	    'group' => $_->[0],
	    'group_name' => $_->[1],
	};
    } @{$sth->fetchall_arrayref()}];
}


__PACKAGE__->set_sql(projects_by_auth => qq{
	SELECT p.pid,p.name 
        FROM works_on w, projects p
	    WHERE  w.pid = p.pid
	    AND p.status <> 'Complete'
	    AND w.username = ?
	    AND w.auth = ?;
    }, 'Main');


sub projects_by_auth {
    my $self = shift;
    my $auth = shift;
    my $seen = shift; 

    if(!$seen) {
	$seen = {};
    }
    if (exists $seen->{$self->username}) {
	return {};
    }

    $seen->{$self->username} = 1;

    # use a hash to automagically remove duplicates
    my %projects = ();

    my $sth = $self->sql_projects_by_auth;
    $sth->execute($self->username,$auth);
    # get the list of projects that this user
    # is explicitly attached to
    foreach my $p (@{$sth->fetchall_arrayref()}) {
	$projects{$p->[0]} = $p->[1];
    }

    # then, add in the projects for the groups that
    # the user is part of. 
    foreach my $g (@{$self->user_groups()}) {
	my $group_user = CDBI::User->retrieve($g->{group});
	my $group_projects = $group_user->projects_by_auth($auth,$seen);
	foreach my $pid (keys %{$group_projects}) {
	    $projects{$pid} = $group_projects->{$pid};
	}
    }
    return \%projects;
   
}

# returns a reference to a hashtable of projects that
# the user is attached to. searches recursively through
# groups that the user is in. key is pid, value is project name.

__PACKAGE__->set_sql(projects => qq{
	SELECT p.pid,p.name FROM works_on w, projects p 
	    WHERE w.pid = p.pid 
	    AND p.status <> 'Complete'
	    AND w.username = ?;
    }, 'Main');

sub projects_hash {
    my $self = shift;
    # hash of usernames 
    # prevents loops
    my $seen = shift; 
    if(!$seen) {
	$seen = {};
    }

    if (exists $seen->{$self->username}) {
	return {};
    }

    $seen->{$self->username} = 1;

    # use a hash to automagically remove duplicates
    my %projects = ();
    my $sth = $self->sql_projects;
    $sth->execute($self->username);

    # get the list of projects that this user
    # is explicitly attached to
    foreach my $p (@{$sth->fetchall_arrayref()}) {
	$projects{$p->[0]} = $p->[1];
    }

    # then, add in the projects for the groups that
    # the user is part of. 
    foreach my $g (@{$self->user_groups()}) {
	my $group_user = CDBI::User->retrieve($g->{group});
	my $group_projects = $group_user->projects_hash($seen);
	foreach my $pid (keys %{$group_projects}) {
	    $projects{$pid} = $group_projects->{$pid};
	}
    }
    return \%projects;
}

__PACKAGE__->set_sql(interval_time => qq{
    select sum(a.actual_time) from actual_times a 
	where a.resolver = ?
	and a.completed > ? and a.completed <= date(?) + interval '1 day';}, 'Main');

sub interval_time {
    my $self = shift;
    my $start = shift;
    my $end = shift;
    # calculate the total time spent on all projects by the user
    my $sth = $self->sql_interval_time;
    $sth->execute($self->username,$start,$end);
    return $sth->fetchrow_arrayref()->[0];
}

__PACKAGE__->set_sql(active_projects => qq{
	select distinct p.pid,p.name from actual_times a,
	items i, milestones m, projects p  
	    where a.iid = i.iid 
	    and a.resolver = ?
	    and i.mid = m.mid and m.pid = p.pid
	    and a.completed > ? and a.completed <= date(?) + interval '1 day';
    }, 'Main');

sub active_projects {
    my $self = shift;
    my $start_date = shift;
    my $end_date = shift;
    my $sth = $self->sql_active_projects;
    $sth->execute($self->username,$start_date,$end_date);
    return [map {
	{
	    pid => $_->[0],
	    name => $_->[1],
	}
    } @{$sth->fetchall_arrayref()}];
}

__PACKAGE__->set_sql(total_breakdown => qq{
    select p.pid,p.name,sum(a.actual_time) as time
	from projects p, milestones m, items i, actual_times a
	where a.resolver = ? and a.iid = i.iid and i.mid = m.mid and m.pid =
	p.pid
	group by p.pid,p.name order by time desc;}, 'Main');

sub total_breakdown {
    my $self = shift;
    my $sth = $self->sql_total_breakdown;
    $sth->execute($self->username);
    my @projects = map { 
        $_->{'time'} = interval_to_hours($_->{'time'});
        $_;
    } map {
	{
	    pid => $_->[0],
	    name => $_->[1],
	    time => $_->[2],
	}
    } @{$sth->fetchall_arrayref()};
    return {projects => \@projects};
}

sub weekly_report {
    my $self = shift;
    my $week_start = shift;
    my $week_end = shift;
    my $viewer = shift || "";
    my $sortby = shift || "";
    # figure out which projects have been taking up time self week
    my $active_projects = $self->active_projects($week_start,$week_end);

    foreach my $project (@$active_projects) {
	$project->{time} =
        $cdbi->project_completed_time_for_interval($project->{pid},
            $week_start, $week_end);
	$project->{hours} = interval_to_hours($project->{time});
    }
    # get individual resolve times

    return {active_projects => $active_projects,
	    total_time => interval_to_hours($self->interval_time($week_start,$week_end)),
	    individual_times => $self->resolve_times_for_interval($week_start, $week_end),
	};
}

__PACKAGE__->set_sql(all_projects => qq{
    SELECT p.pid, p.name, p.status, p.caretaker,
    u.fullname, to_char(max(i.last_mod), 'YYYY-MM-DD HH24:MI')
	FROM projects p LEFT OUTER JOIN milestones m 
	ON p.pid = m.pid
	LEFT OUTER JOIN items i on m.mid = i.mid 
	JOIN users u on p.caretaker = u.username
	WHERE 
	(p.pub_view = 'true' 
	 OR p.pid in (SELECT w.pid 
		      FROM works_on w
		      WHERE w.username = ?))	    
	GROUP BY
	p.pid,p.name,p.status,p.caretaker,u.fullname
	ORDER BY upper(p.name) ASC;}, 'Main');

__PACKAGE__->set_sql(project_estimated_times => qq{
    select m.pid, sum(i.estimated_time) as
	estimated from items i, milestones m 
	where i.mid = m.mid and i.status in
	('OPEN','UNASSIGNED', 'INPROGRESS') group by m.pid;}, 'Main');

__PACKAGE__->set_sql(project_completed_times => qq{
    select m.pid, sum(a.actual_time) as completed from
	actual_times a, items i, milestones m where a.iid = i.iid
	and i.mid = m.mid group by m.pid;}, 'Main');

sub all_projects {
    my $self = shift;
    my $sth = $self->sql_all_projects;
    $sth->execute($self->username);
    my $projects = [map {
	{ pid => $_->[0], name => $_->[1], status => $_->[2], caretaker => $_->[3],
	  fullname => $_->[4], modified => $_->[5], }
    } @{$sth->fetchall_arrayref()}];

    my %estimated_times = ();
    my %completed_times = ();
    $sth = $self->sql_project_estimated_times;
    $sth->execute();
    foreach my $r (@{$sth->fetchall_arrayref()}) {
        $estimated_times{$r->[0]} = interval_to_hours($r->[1]);
    }
    $sth = $self->sql_project_completed_times;
    $sth->execute();
    foreach my $r (@{$sth->fetchall_arrayref()}) {
        $completed_times{$r->[0]} = interval_to_hours($r->[1]);
    }

    my @projects;
    foreach my $p (@$projects) {
        if (exists $estimated_times{$p->{pid}}) {
            $p->{total_estimated} = $estimated_times{$p->{pid}};
        } else {
            $p->{total_estimated} = "-";
        }
        if (exists $completed_times{$p->{pid}}) {
            $p->{total_completed} = $completed_times{$p->{pid}};
        } else {
            $p->{total_completed} = "-";
        }
	push @projects, $p;
    }
    return \@projects;
}

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


my %sorts = (priority => "i.priority DESC, i.type DESC, i.target_date ASC",
	     type => "i.type DESC, i.priority DESC, i.target_date ASC",
	     title => "i.title ASC, i.priority DESC, i.target_date ASC",
	     status => "i.status ASC, i.priority DESC, i.target_date ASC",
	     project => "p.name ASC, i.priority DESC, i.type DESC, i.target_date ASC",
	     target_date => "i.target_date ASC, i.priority DESC, i.type DESC",
	     last_mod => "i.last_mod DESC, i.priority DESC, i.type DESC, i.target_date ASC",
	     assigned_to => "i.assigned_to ASC, i.priority DESC, i.type DESC, i.target_date ASC",
	     owner       => "i.owner ASC, i.priority DESC, i.type DESC, i.target_date ASC");

my $sql = qq {
SELECT i.iid,i.type,i.title,i.priority,i.status,i.r_status,p.name,
       m.pid,i.target_date,to_char(i.last_mod,'YYYY-MM-DD HH24:MI'),
       current_date - i.target_date,i.description
FROM   items i, milestones m, projects p
WHERE  i.mid = m.mid 
  AND  m.pid = p.pid 
  AND ((i.assigned_to = ? 
       AND i.status IN ('OPEN','UNASSIGNED','INPROGRESS')) 
       OR 
       (i.owner = ? AND i.status = 'RESOLVED') )
  AND ((p.pub_view = 'true') 
       OR  (p.pid in (SELECT w.pid 
                      FROM   works_on w
		      WHERE  w.username = ?))
       OR (i.assigned_to = ?) 
       OR (i.owner = ?))
  ORDER BY };

foreach my $k (keys %sorts) {
    __PACKAGE__->set_sql("items_$k" => $sql . " " . $sorts{$k} . ";", 'Main');
} 

my %item_handles = (
    priority => sub {return shift->sql_items_priority;},
    type => sub {return shift->sql_items_type;},
    title => sub {return shift->sql_items_title;},
    status => sub {return shift->sql_items_status;},
    project => sub {return shift->sql_items_project;},
    target_date => sub {return shift->sql_items_target_date;},
    last_mod => sub {return shift->sql_items_last_mod;},
    assigned_to => sub {return shift->sql_items_assigned_to;},
    owner => sub {return shift->sql_items_owner;},
);


# gets the list of items that are either assigned to the user and open
# or owned by the user and resolved.
sub items {
    my $self = shift;
    my $username = $self->get("username");
    my $viewer = shift;
    my $sort = shift || "priority";
    $sort = "priority" unless exists $sorts{$sort};
    my $sth = $item_handles{$sort}($self);
    $sth->execute($self->username,$self->username,$viewer,$viewer,$viewer);
    return make_classes([map 
        {
            $_->{priority_label} = $PRIORITIES{$_->{priority}}; 
            $_;
	} map {
	    { iid => $_->[0], type => $_->[1], title => $_->[2], 
	      priority => $_->[3], status => $_->[4], r_status => $_->[5],
	      project => $_->[6], pid => $_->[7], target_date => $_->[8],
	      last_mod => $_->[9], overdue => $_->[10], description => $_->[11],
	  }
        } @{$sth->fetchall_arrayref()}]);
}



sub quick_edit_data {
    my $self = shift;
    my $sort = shift || "";
    my %data = %{$self->data()};
    $data{items}                = [
				   map {
				       if ($_->{overdue} < -7) {
					   $_->{schedule_status} = 'ok';
				       } elsif ($_->{overdue} < -1) {
					   $_->{schedule_status} = 'upcoming';
				       } elsif ($_->{overdue} < 1) {
					   $_->{schedule_status} = 'due';
				       } elsif ($_->{overdue} < 7) {
					   $_->{schedule_status} = 'overdue';
				       } else {
					   $_->{schedule_status} = 'late';
				       }
                                       my $i = PMT::Item->retrieve($_->{iid});
                                       $_->{status_select} = $i->status_select();
                                       $_->{priority_select} = $i->priority_select();
                                       my $p = $i->mid->pid;
                                       $_->{assigned_to_select} = $p->assigned_to_select($i->assigned_to);
				       $_;
				   }
				   @{$self->items($self->username,$sort)}];
    return \%data;
}



# returns a nice hashref of data to plugin to
# the template for the user's homepage.
sub home {
    my $self = shift;
    my $username = $self->username;
    my $sort = shift || "";
    my %data = %{$self->data()};
    $data{items}                = [
				   map {
				       if ($_->{overdue} < -7) {
					   $_->{schedule_status} = 'ok';
				       } elsif ($_->{overdue} < -1) {
					   $_->{schedule_status} = 'upcoming';
				       } elsif ($_->{overdue} < 1) {
					   $_->{schedule_status} = 'due';
				       } elsif ($_->{overdue} < 7) {
					   $_->{schedule_status} = 'overdue';
				       } else {
					   $_->{schedule_status} = 'late';
				       }
                                       $_->{priority_label} = $PRIORITIES{$_->{priority}};
				       $_;
				   }
				   @{$self->items($username,$sort)}];

    $data{total_estimated_time} = $self->total_estimated_time();
    $data{groups}               = $self->user_groups();
    my $est_priority = $self->estimated_times_by_priority();
    my $est_sched = $self->estimated_times_by_schedule_status();
    my $scheds = scale_array(150.0,[$est_sched->{ok}, $est_sched->{upcoming}, 
				    $est_sched->{due}, $est_sched->{overdue}, 
				    $est_sched->{late}]);

    $data{ok} = $scheds->[0];
    $data{upcoming} = $scheds->[1];
    $data{due} = $scheds->[2];
    $data{overdue} = $scheds->[3];
    $data{late} = $scheds->[4];

    my $priorities = scale_array(150.0, [$est_priority->{priority_4}, $est_priority->{priority_3},
					 $est_priority->{priority_2}, $est_priority->{priority_1},
					 $est_priority->{priority_0}]);

    $data{critical} = $priorities->[0];
    $data{high} = $priorities->[1];
    $data{medium} = $priorities->[2];
    $data{low} = $priorities->[3];
    $data{icing} = $priorities->[4];

    return \%data;
}

# }}}







1;
