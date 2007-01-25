use lib qw(..);
package PMT::User;
use base 'CDBI::DBI';
use PMT::Common;

my %PRIORITIES = (4 => 'CRITICAL', 3 => 'HIGH', 2 => 'MEDIUM', 1 => 'LOW',
0 => 'ICING');

__PACKAGE__->table('users');
__PACKAGE__->columns (Primary          => qw/username/);
__PACKAGE__->columns (All              => qw/fullname email status grp password type 
title phone bio campus building room photo_url photo_width photo_height/);

__PACKAGE__->has_many(nodes            => 'PMT::Node', 'author');
__PACKAGE__->has_many(projects         => 'PMT::Project', 'caretaker');
__PACKAGE__->has_many(documents        => 'PMT::Document', 'author');
__PACKAGE__->has_many(attachments      => 'PMT::Attachment', 'author');
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
                     qq{select sum(i.estimated_time) as total from items i, milestones m where
                            i.assigned_to = ?
                            and i.mid = m.mid
                            and m.name <> 'Someday/Maybe'
                            and i.status IN ('OPEN','UNASSIGNED','INPROGRESS');
                    },'Main');

sub data {
    my $self = shift;
    return {
        username => $self->username,
        fullname => $self->fullname,
        email => $self->email,
        status => $self->status,
        grp => $self->grp,
        password => $self->password,
	type => $self->type,
	title => $self->title,
	phone => $self->phone,
	bio => $self->bio,
	campus => $self->campus,
	building => $self->building,
	room => $self->room,
	photo_url => $self->photo_url,
	photo_width => $self->photo_width,
	photo_height => $self->photo_height,
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

sub firstname {
    my $self = shift;
    my @parts = split ' ', $self->fullname;
    pop @parts;
    return join(" ",@parts);
}

sub lastname {
    my $self = shift;
    my @parts = split ' ', $self->fullname;
    return pop @parts;
}

sub calculate_group {
    my $self = shift;
    my @groups = map {$_->{group_name}} @{$self->user_groups()};

    my @sg = ();

    if (grep (/management/, @groups)) {
	push @sg, "Management";
    }
    if (grep (/educational technologists/, @groups)) {
	push @sg, "Education";
    }
    if (grep (/video/, @groups)) {
	push @sg, "Digital Media";
    } 
    if (grep (/programmers/, @groups)) {
	push @sg, "Technology";
    }
    if (grep (/webmasters/, @groups)) {
	push @sg, "Editorial and Design";
    }

    if (grep (/part-timers/, @groups)) {
	push @sg, "Part-Timers";
    }
    if (grep (/external partners/, @groups)) {
	push @sg, "External Partners";
    }
    if (grep (/new media associates/, @groups)) {
	push @sg, "New Media Associates";
    }
    return \@sg;
}

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
    select u.username as group,u.fullname as group_name
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
    } @{$sth->fetchall_arrayref({})}];
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
    foreach my $p (@{$sth->fetchall_arrayref({})}) {
        $projects{$p->{pid}} = $p->{name};
    }

    # then, add in the projects for the groups that
    # the user is part of.
    foreach my $g (@{$self->user_groups()}) {
        my $group_user = PMT::User->retrieve($g->{group});
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
            AND p.status <> 'Complete' AND p.status <> 'Deferred'
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
    foreach my $p (@{$sth->fetchall_arrayref({})}) {
        $projects{$p->{pid}} = $p->{name};
    }

    # then, add in the projects for the groups that
    # the user is part of.
    foreach my $g (@{$self->user_groups()}) {
        my $group_user = PMT::User->retrieve($g->{group});
        my $group_projects = $group_user->projects_hash($seen);
        foreach my $pid (keys %{$group_projects}) {
            $projects{$pid} = $group_projects->{$pid};
        }
    }
    return \%projects;
}

__PACKAGE__->set_sql(interval_time => qq{
    select sum(a.actual_time) as time from actual_times a
        where a.resolver = ?
        and a.completed > ? and a.completed <= date(?) + interval '1 day';}, 'Main');

sub interval_time {
    my $self = shift;
    my $start = shift;
    my $end = shift;
    # calculate the total time spent on all projects by the user
    my $sth = $self->sql_interval_time;
    $sth->execute($self->username,$start,$end);
    my $time = $sth->fetchrow_hashref()->{time};
    $sth->finish;
    return $time;
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
    return $sth->fetchall_arrayref({});
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
    } @{$sth->fetchall_arrayref({})};
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
        $project->{time} = $self->project_completed_time_for_interval($project->{pid},$week_start, $week_end);
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
    u.fullname, date_trunc('minute',max(i.last_mod)) as modified
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
    my $all_projects = $sth->fetchall_arrayref({});

    my %estimated_times = ();
    my %completed_times = ();
    $sth = $self->sql_project_estimated_times;
    $sth->execute();
    foreach my $r (@{$sth->fetchall_arrayref({})}) {
        $estimated_times{$r->{pid}} = interval_to_hours($r->{estimated_time});
    }
    $sth = $self->sql_project_completed_times;
    $sth->execute();
    foreach my $r (@{$sth->fetchall_arrayref({})}) {
        $completed_times{$r->{pid}} = interval_to_hours($r->{completed});
    }

    my @projects;
    foreach my $p (@$all_projects) {
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
        push @all_projects, $p;
    }
    return \@all_projects;
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
    my $res = interval_to_hours($sth->fetchrow_hashref()->{total});
    $sth->finish;
    return $res;
}

__PACKAGE__->set_sql(watched_items =>
                     qq{
    select i.iid,i.type,i.title,i.priority,i.status,i.r_status,p.name as project,
       m.pid,i.target_date,date_trunc('minute',i.last_mod) as last_mod,
       current_date - i.target_date as overdue, i.description, i.assigned_to,
       ua.fullname as assigned_to_fullname, i.owner, uo.fullname as owner_fullname
       from items i, notify n, milestones m, projects p, users ua, users uo
       where i.iid = n.iid
           and m.mid = i.mid
           and m.pid = p.pid
           and uo.username = i.owner
           and ua.username = i.assigned_to
           and n.username = ? order by i.last_mod desc limit 20;
},'Main');


sub watched_items {
    # returns the recently updated items that the user is on the notify
    # list for
    my $self = shift;
    my $sth = $self->sql_watched_items;
    $sth->execute($self->username);
    return make_classes([map {
            $_->{priority_label} = $PRIORITIES{$_->{priority}};
            $_;
        } @{$sth->fetchall_arrayref({})}]);
}

__PACKAGE__->set_sql(events_on =>
                     qq{SELECT e.status,e.event_date_time as date_time,e.item as iid,i.title,c.comment,c.username
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
    return $sth->fetchall_arrayref({});
}

__PACKAGE__->set_sql(estimated_times_by_priority =>
                     qq{select sum(i.estimated_time) as time, i.priority from items i, milestones m where
                            i.assigned_to = ?
                            and i.mid = m.mid
                            and m.name <> 'Someday/Maybe'
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
    } @{$sth->fetchall_arrayref({})};
    my %priorities = ();
    foreach my $r (@results) {
        $priorities{"priority_" . $r->{priority}} = $r->{'time'};
    }
    return \%priorities;
}

__PACKAGE__->set_sql(estimated_times_by_schedule_status =>
                qq{select i.estimated_time,
                   current_date - i.target_date as overdue
                       from items i, milestones m where assigned_to = ?
                       and i.mid = m.mid
                       and m.name <> 'Someday/Maybe'
                       and i.status in ('OPEN','UNASSIGNED','INPROGRESS');
               }, 'Main');

sub estimated_times_by_schedule_status {
    my $self = shift;
    my $sth = $self->sql_estimated_times_by_schedule_status;
    $sth->execute($self->username);
    my %statuses = (overdue => 0, late => 0, due => 0, upcoming => 0, ok =>
        0);
    foreach my $res (@{$sth->fetchall_arrayref({})}) {
        my $t = interval_to_hours($res->{estimated_time});
        if ($res->{overdue} < -7) {
            $statuses{ok} += $t;
        } elsif ($res->{overdue} < -1) {
            $statuses{'upcoming'} += $t;
        } elsif ($res->{overdue} < 1) {
            $statuses{'due'} += $t;
        } elsif ($res->{overdue} < 7) {
            $statuses{'overdue'} += $t;
        } else {
            $statuses{'late'} += $t;
        }
    }
    return \%statuses;
}

__PACKAGE__->set_sql(estimated_times_by_project =>
                     qq{select sum(i.estimated_time) as time,p.pid,p.name as project
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
    } @{$sth->fetchall_arrayref({})}];
}

__PACKAGE__->set_sql(resolve_times_for_interval =>
                     qq{select a.actual_time, date_trunc('second',a.completed) as completed,
                        a.iid, i.title, p.pid, p.name as project
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
    return $sth->fetchall_arrayref({});
}

__PACKAGE__->set_sql(project_completed_time_for_interval =>
                     qq{
                         select sum(a.actual_time) as total_time from actual_times a, items i, milestones m
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
    my $total_time = $sth->fetchrow_hashref()->{total_time};
    $sth->finish;
    return $total_time;
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
    my $time = $sth->fetchrow_hashref()->{time};
    $sth->finish;
    return interval_to_hours($time);
}

__PACKAGE__->set_sql(total_group_time =>
                     qq{select sum(a.actual_time) as time from actual_times a, in_group g
                            where a.resolver = g.username and g.grp = ?
                            and a.completed > ? and a.completed <= ?;},
                     'Main');

sub total_group_time {
    my $self = shift;
    my $start = shift;
    my $end = shift;
    my $sth = $self->sql_total_group_time;
    $sth->execute($self->username,$start,$end);
    my $time = $sth->fetchrow_hashref()->{time};
    $sth->finish;
    return $time;
}

__PACKAGE__->set_sql(items_search => qq {
SELECT i.iid,i.type,i.title,i.priority,i.status,i.r_status,p.name as project,
       m.pid,i.target_date,date_trunc('minute',i.last_mod) as last_mod,
       current_date - i.target_date as overdue,i.description
FROM   items i, milestones m, projects p
WHERE  i.mid = m.mid
  AND  m.pid = p.pid
  AND ((i.assigned_to = ?
       AND i.status IN ('OPEN','UNASSIGNED','INPROGRESS')
        AND m.name <> 'Someday/Maybe')
       OR
       (i.owner = ? AND i.status = 'RESOLVED') )
  AND ((p.pub_view = 'true')
       OR  (p.pid in (SELECT w.pid
                      FROM   works_on w
                      WHERE  w.username = ?))
       OR (i.assigned_to = ?)
       OR (i.owner = ?))
  ORDER BY i.priority DESC, i.type DESC, i.target_date ASC;}, 'Main');

# gets the list of items that are either assigned to the user and open
# or owned by the user and resolved.
sub items {
    my $self = shift;
    my $username = $self->username;
    my $viewer = shift;

    my $sth = $self->sql_items_search;
    $sth->execute($self->username,$self->username,$viewer,$viewer,$viewer);

    return make_classes([map
        {
            $_->{priority_label} = $PRIORITIES{$_->{priority}};
            $_;
        } @{$sth->fetchall_arrayref({})}]);
}

__PACKAGE__->set_sql(someday_maybe_items_search => qq {
SELECT i.iid,i.type,i.title,i.priority,i.status,i.r_status,p.name as project,
       m.pid,i.target_date,date_trunc('minute',i.last_mod) as last_mod,
       current_date - i.target_date as overdue,i.description
FROM   items i, milestones m, projects p
WHERE  i.mid = m.mid
  AND  m.pid = p.pid
  AND ((i.assigned_to = ?
       AND i.status IN ('OPEN','UNASSIGNED','INPROGRESS')
        AND m.name = 'Someday/Maybe'))
  AND ((p.pub_view = 'true')
       OR  (p.pid in (SELECT w.pid
                      FROM   works_on w
                      WHERE  w.username = ?))
       OR (i.assigned_to = ?)
       OR (i.owner = ?))
  ORDER BY i.priority DESC, i.type DESC, i.target_date ASC;}, 'Main');

sub someday_maybe_items {
    my $self = shift;
    my $username = $self->username;
    my $viewer = shift;

    my $sth = $self->sql_someday_maybe_items_search;
    $sth->execute($self->username,$viewer,$viewer,$viewer);

    return make_classes([map
        {
            $_->{priority_label} = $PRIORITIES{$_->{priority}};
            $_;
        } @{$sth->fetchall_arrayref({})}]);
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

sub someday_maybe {
    my $self = shift;
    my $username = $self->username;

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
                                   @{$self->someday_maybe_items($username)}];

    return \%data;
}



sub menu {
    my $self = shift;
    my %data = %{$self->data()};
    delete $data{status};
    my $projects = $self->projects_hash();
    $data{projects} = [map {
        {pid => $_, name => $projects->{$_}};
    } sort {
        lc($projects->{$a}) cmp lc($projects->{$b});
    } keys %{$projects}];
    return \%data;
}

sub users_select {
    my $default = shift || "";
    my @values = ();
    my @labels = map {
        push @values, $_->username;
        $_->fullname;
    } PMT::User->all_active();
    my @defaults = [];
    if ($default ne "") {
        @defaults = ($default);
    }
    return selectify(\@values,\@labels,\@defaults);
}


sub groups {
    my $self = shift;
    return [map {{group => $_->username, group_name => $_->fullname}} PMT::User->search(grp => 't')];
}

sub remove_from_all_groups {
    my $self = shift;
    foreach my $g (PMT::Group->search(username => $self->username)) {
        $g->delete();
    }
}


__PACKAGE__->set_sql(users_hours_1 => qq{
        SELECT u.username,u.fullname,count(i.iid) as open_items,sum(i.estimated_time) as hours
        FROM   users u, items i
        WHERE  u.status <> 'inactive'
               AND (i.status IN ('OPEN','INPROGRESS','UNASSIGNED'))
               AND u.username = i.assigned_to
        GROUP BY u.username,u.fullname;
    },'Main');

__PACKAGE__->set_sql(users_hours_2 => qq{
        SELECT u.username,u.fullname
        FROM   users u
        WHERE  u.username NOT IN (select distinct assigned_to from items)
               AND u.status <> 'inactive';
    }, 'Main');

__PACKAGE__->set_sql(users_hours_3 => qq{
    SELECT u.username,sum(a.actual_time) as resolved from users u left outer join
    actual_times a on u.username = a.resolver
    where a.completed >= ?
    group by u.username;}, 'Main');

# returns AoH with all the active users, the number of open items
# they have assigned to them, and their total estimated times
sub users_hours {
    my $self = shift;
    my $sth = $self->sql_users_hours_1;
    $sth->execute();
    my %users = ();
    foreach my $user (@{$sth->fetchall_arrayref({})}) {
        $user->{hours} = interval_to_hours($user->{'hours'});
        $users{$user->{username}} = $user;
    }

    # also get the users who don't have any open items

    $sth = $self->sql_users_hours_2;
    $sth->execute();
    foreach my $user (@{$sth->fetchall_arrayref({})}) {
        $user->{hours} = 0;
        $user->{open_items} = 0;
        $users{$user->{username}} = $user;
    }

    # get the resolved times in the last month


    use Date::Calc qw/Add_Delta_Days/;
    my ($year,$month,$day) = todays_date();
    my ($pyear,$pmonth,$pday) = Add_Delta_Days($year,$month,$day,-7);
    $sth = $self->sql_users_hours_3;
    $sth->execute("$pyear-$pmonth-$pday");
    foreach my $u (@{$sth->fetchall_arrayref({})}) {
        $users{$u->{username}}->{resolved}  =
        interval_to_hours($u->{resolved});
    }

    return [
            map {
                $users{$_};
            } sort {
                lc($users{$a}->{fullname}) cmp lc($users{$b}->{fullname});
            } keys %users
            ];
}



1;
