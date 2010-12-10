use lib qw(..);
package PMT::Project;
use base 'CDBI::DBI';
use PMT::Common;

my @PROJECT_STATUSES = qw/Discovery Design Development
    Deployment Deferred Maintenance Complete/;

my @APPROACHES = qw/analytic archives casestudies eseminars
    laboratory largeclass mse simulations training/;

my @AREAS = ("n/a", "Architecture","Arts","Business and Finance",
             "Culture and Society", "Education", "History",
             "Journalism", "Languages", "Law", "Literature",
             "Medicine and Health", "Philosophy and Religion",
             "Political Science and Social Policy", "Science",
             "Social Sciences", "Technology");
my @DISTRIBS = qw/Columbia external internal/;

my @RESTRICTEDS = qw/Columbia No Yes/;

my @TYPES = ("Course Page","Project","Other");

my @SCALES = qw/small medium large flagship/;


__PACKAGE__->table("projects");
__PACKAGE__->sequence("projects_s");
__PACKAGE__->columns(Primary => qw/pid/);
__PACKAGE__->columns(Essential => qw/pid name caretaker pub_view
description status/);
__PACKAGE__->columns(Others => qw/type area url restricted approach
                               info_url entry_rel eval_url projnum scale
                               distrib poster wiki_category/);
__PACKAGE__->columns(TEMP => qw/estimated_time completed_time/);
__PACKAGE__->has_a("caretaker" => 'PMT::User');
__PACKAGE__->has_many("documents" => 'PMT::Document', "pid");
__PACKAGE__->has_many(milestones => 'PMT::Milestone', "pid");
__PACKAGE__->has_many(works_on => 'PMT::WorksOn', "pid");
__PACKAGE__->has_many(clients => 'PMT::ProjectClients', 'pid');
__PACKAGE__->has_many(notifies => 'PMT::NotifyProject', 'pid');


__PACKAGE__->set_sql(all_items_in_project => qq{
SELECT i.iid, i.type, i.owner, uo.fullname as owner_fullname, i.assigned_to,
ua.fullname as assigned_to_fullname,
i.title, i.mid, m.name as milestone, i.url, i.status, i.description, i.priority,
i.r_status, i.last_mod, i.target_date, i.estimated_time
FROM items i, users uo, users ua, milestones m
WHERE i.mid = m.mid AND m.pid = ?
AND uo.username = i.owner AND ua.username = i.assigned_to;
}, 'Main');

__PACKAGE__->set_sql(estimated_time => qq{
SELECT sum(i.estimated_time) as estimated_time
from items i, milestones m
where i.mid = m.mid and m.pid = ?
    and i.status in ('OPEN','UNASSIGNED','INPROGRESS');});
__PACKAGE__->set_sql(all_estimated_time => qq{
SELECT sum(i.estimated_time) as estimated_time
from items i, milestones m
where i.mid = m.mid and m.pid = ?;});

__PACKAGE__->set_sql(completed_time => qq{
SELECT sum(a.actual_time) as completed_time
from actual_times a, items i, milestones m
where a.iid = i.iid and i.mid = m.mid
    and m.pid = ?;});


__PACKAGE__->set_sql(total_time_in_interval =>
qq{select sum(a.actual_time)  from actual_times a, items i, milestones m
where a.iid = i.iid and i.mid = m.mid and m.pid = ?
    and a.completed > ? and a.completed <= ?;}, 'Main');

__PACKAGE__->set_sql(user_time_in_interval =>
qq{select sum(a.actual_time) from actual_times a, items i, milestones m
            where a.resolver = ?
            and a.iid = i.iid and i.mid = m.mid and m.pid = ?
            and a.completed > ? and a.completed <= ?;}, 'Main');
__PACKAGE__->set_sql(project_milestones =>
                     qq{SELECT mid,name,target_date,pid,status,
                        description FROM milestones where pid = ?
                            ORDER BY target_date ASC;},
                     'Main');

__PACKAGE__->set_sql(upcoming_milestone =>
                     qq{SELECT mid, current_date - target_date as delta_t
                            FROM milestones
                            WHERE pid = ? AND (current_date - target_date) < 1
                            AND status = 'OPEN'
                            ORDER BY delta_t DESC
                            LIMIT 1;},
                     'Main');
__PACKAGE__->set_sql(latest_milestone =>
                     qq{SELECT mid FROM milestones WHERE pid = ?
                            ORDER BY target_date DESC;},
                     'Main');


__PACKAGE__->set_sql(interval_total =>
                     qq{
                         select sum(a.actual_time) as total_time from actual_times a, items i, milestones m, in_group g
                             where a.iid = i.iid and i.mid = m.mid and m.pid = ?
                             and a.resolver = g.username and g.grp in
                             ('grp_programmers','grp_webmasters','grp_video',
                              'grp_educationaltechnologists','grp_management')
                             and a.completed > ? and a.completed <= ?;
                     },
                     'Main');
# {{{ interval_total

sub interval_total {
    my $self = shift;
    my $start = shift;
    my $end = shift;
    my $sth = $self->sql_interval_total;
    $sth->execute($self->pid,$start,$end);
    my $total_time = $sth->fetchrow_hashref()->{total_time};
    $sth->finish;
    return $total_time;
}

# }}}


sub add_user_from_group_to_project {
    my $self = shift;
    my $username = untaint_username(shift);
    my $group = untaint_username(shift);
    my @wo = PMT::WorksOn->search(pid => $self->pid, username => $username);
    if (!scalar @wo) {
        # add 'em
        my $auth = $self->project_role($group);
        PMT::WorksOn->create({pid => $self->pid, username => $username, auth => $auth});
    } else {
        # they are already on the project so we
        # don't need to add them.
    }
}


sub add_item_form {
    my $self     = shift;
    my $type     = shift || "bug";
    my $username = untaint_username(shift);

    my %data = %{$self->data()};
    my $user = PMT::User->retrieve($username);

    $data{'tags'}         = $self->tags();
    my $caretaker = $self->caretaker->username;
    $data{'personnel'}   = [map {{
            username => $_->username, fullname => $_->fullname,
            caretaker => ($_->username eq $caretaker),
        };
    } $self->all_personnel_in_project()];
    $data{'type'}         = $type;
    $data{'on_project'}   = $self->project_role($username);
    $data{'clients_select'} = $self->clients_data();
    $data{'owner_select'} = $self->owner_select($user);
    $data{'milestone_select'} = $self->project_milestones_select();
    $data{$type}          = 1;
    return \%data;
}

sub edit_project {
    my $self        = shift;
    my %args = @_;
    my $pid         = $args{pid};
    my $name        = escape($args{name})
        || throw Error::NO_NAME "no name specified in edit_project()";
    my $description = escape($args{description});
    my $caretaker   = untaint_username($args{caretaker});
    my $pr          = $args{personnel};
    my $pub_view    = $args{pub_view};
    my $status      = $args{status};
    my $projnum     = $args{projnum} || 0;
    my $area        = $args{area};
    my $url         = $args{url} || "";
    my $restricted  = $args{restricted};
    my $approach    = $args{approach};
    my $info_url    = $args{info_url} || "";
    my $entry_rel   = $args{entry_rel};
    my $eval_url    = $args{eval_url} || "";
    my $scale       = $args{scale};
    my $distrib     = $args{distrib};
    my $type        = $args{type};
    my $poster      = $args{poster};

    $self->name($name);
    $self->description($description);
    $self->caretaker(PMT::User->retrieve($caretaker));
    $self->pub_view($pub_view);
    $self->status($status);
    $self->projnum($projnum);
    $self->area($area);
    $self->url($url);
    $self->restricted($restricted);
    $self->approach($approach);
    $self->info_url($info_url);
    $self->entry_rel($entry_rel);
    $self->eval_url($eval_url);
    $self->scale($scale);
    $self->distrib($distrib);
    $self->type($type);
    $self->poster($poster);

    # clear users
    $self->works_on()->delete_all();
    my $got_caretaker = 0;
    # put them back in

    my %seen;

    foreach my $person (@$pr) {
        next if $person eq "-1";
        next if $person eq "";
        next if $seen{$person};
        my $w = PMT::WorksOn->create({username => $person, pid => $self->pid});
        $seen{$person} = 1;
        $got_caretaker = 1 if $person eq $caretaker;
    }
    # make sure that at least the caretaker is on the project
    if(!$got_caretaker) {
        my $w = PMT::WorksOn->create({username => $caretaker, pid => $self->pid});
        $seen{$caretaker} = 1;
    }
    $self->update();

}



sub data {
    my $self = shift;
    return {
        pid => $self->pid, name => $self->name, caretaker =>
        $self->caretaker->username, pub_view => $self->pub_view,
        description => $self->description, status => $self->status, type =>
        $self->type, area => $self->area, url => $self->url, restricted =>
        $self->restricted, approach => $self->approach, info_url =>
        $self->info_url, entry_rel => $self->entry_rel, eval_url =>
        $self->eval_url, projnum => $self->projnum, scale => $self->scale,
        distrib => $self->distrib, poster => $self->poster,
        wiki_category => $self->wiki_category,
    };
}

sub project_milestones_select {
    my $self = shift;
    my @milestones = map {$_->data()} $self->milestones();
    my $upcoming = $self->upcoming_milestone();
    my @values = map {$_->{mid}} @milestones;
    my @labels = map {$_->{name} . " (" . $_->{target_date} . ")" } @milestones;
    return selectify(\@values,\@labels,[$upcoming]);
}

sub upcoming_milestone  {
    my $self = shift;
    my $pid = $self->pid;
    # ideally, we want a milestone that is open, in the future and as close
    # to today as possible
    my $sth = $self->sql_upcoming_milestone;
    $sth->execute($pid);
    my $res = $sth->fetchrow_hashref();
    $sth->finish;
    if (defined $res) {
        return $res->{mid};
    } else {
        # there aren't any upcoming open milestones, so instead we just
        # grab one.
        $sth = $self->sql_latest_milestone;
        $sth->execute($pid);
        my $mid = $sth->fetchrow_hashref()->{mid};
        $sth->finish;
        return $mid;
    }
}


# like milestones() but shows unclosed items only
sub project_milestones {
    my $self   = shift;
    my $sortby = shift || "priority";
    my $username = shift;

    my $sth = $self->sql_project_milestones;
    $sth->execute($self->pid);

    my @milestones = @{$sth->fetchall_arrayref({})};

    my $set = 0;
    my $has_open = 0;
    foreach my $m (@milestones) {
        my $milestone = PMT::Milestone->retrieve($m->{mid});
        $m->{items} = $milestone->unclosed_items($sortby, $username);
        $m->{total_estimated_time} = interval_to_hours($milestone->estimated_time) || "0";
        $m->{total_completed_time} = interval_to_hours($milestone->completed_time) || "0";
        if(!$set) {
            if($m->{status} eq 'OPEN') {
                $m->{next} = 1;
                $set = 1;
                $has_open = 1;
            }
        }
    }
    if(!$has_open) {
        $milestones[0]->{next} = 1;
    }
    return \@milestones;
}

__PACKAGE__->set_sql(events_on => qq{
SELECT e.status,e.event_date_time as date_time,e.item,i.iid,i.title,c.comment,c.username
FROM events e, items i, milestones m, comments c
WHERE e.item = i.iid AND c.event = e.eid AND i.mid = m.mid AND m.pid = ?
AND date_trunc('day',e.event_date_time) = ?
ORDER BY e.event_date_time ASC;},'Main');

sub events_on {
    my $self = shift;
    my $date = shift;
    my $sth = $self->sql_events_on;
    $sth->execute($self->pid, $date);
    return $sth->fetchall_arrayref({});
}

__PACKAGE__->set_sql(recent_events => qq{
SELECT e.status,i.iid,i.title,c.comment,c.username,e.event_date_time,i.assigned_to,i.owner
FROM   events e, items i, milestones m, comments c
WHERE  e.item = i.iid AND c.event = e.eid AND i.mid = m.mid AND m.pid = ?
ORDER BY e.event_date_time DESC limit 10;
}, 'Main');

sub recent_events {
    my $self = shift;
    my $sth = $self->sql_recent_events;
    $sth->execute($self->pid);
    return $sth->fetchall_arrayref({});
}

__PACKAGE__->set_sql(recent_items =>
qq{select i.iid,i.type,i.title,i.status,p.name as project,p.pid
from items i, milestones m, projects p
where i.mid = m.mid AND m.pid = ?
AND p.pid = m.pid
order by last_mod desc limit 10;}, 'Main');


sub recent_items {
    my $self = shift;
    my $sth = $self->sql_recent_items;
    $sth->execute($self->pid);
    return $sth->fetchall_arrayref({});
}
__PACKAGE__->set_sql(group_hours =>
                     qq{
                         select sum(a.actual_time) as hours from actual_times a, in_group g,
                         milestones m, items i
                             where a.iid = i.iid and i.mid = m.mid and m.pid = ? and
                             a.resolver = g.username and g.grp  = ?
                             and a.completed > ? and a.completed <= ?;},
                     'Main');
sub group_hours {
    my $self = shift;
    my $group = shift;
    my $week_start = shift;
    my $week_end = shift;

    my $sth = $self->sql_group_hours;
    $sth->execute($self->pid,$group,$week_start,$week_end);
    my $hours = $sth->fetchrow_hashref()->{hours};
    $sth->finish;
    return $hours;
}

__PACKAGE__->set_sql(all_users_in_project =>
                     qq{SELECT u.username,u.fullname,u.email
                            FROM users u, works_on w
                            WHERE u.username = w.username
                            AND u.status = 'active'
                            AND u.username not like 'grp_%'
                            AND w.pid = ?;},
                     'Main');

sub all_users_in_project {
    my $self = shift;
    my $sth = $self->sql_all_users_in_project;
    $sth->execute($self->pid);
    return $sth->fetchall_arrayref({});
}

sub tags {
    my $self = shift;
    my $pid = $self->pid;
    my $r = tasty_get("user/project_$pid/");
    if ($r->{tags}) {
	return [sort {$a->{tag} cmp $b->{tag}} 
		map {$_->{tag} = lc($_->{tag});$_;} 
		@{$r->{tags}}];
    } else {
        return [];
    }
}

__PACKAGE__->set_sql(active_users_in_interval =>
qq{SELECT distinct a.resolver as username, u.fullname from actual_times a, items i, milestones m, users u
where a.iid = i.iid and a.resolver = u.username and i.mid = m.mid and m.pid
= ? and a.completed > ? and a.completed <= ?;}, 'Main');

sub active_users_in_interval {
    my $self = shift;
    my $start = shift;
    my $end = shift;
    my $sth = $self->sql_active_users_in_interval;
    $sth->execute($self->pid,$start,$end);
    return $sth->fetchall_arrayref({});
}

__PACKAGE__->set_sql(completed_times_in_interval =>
qq{select a.actual_time, date_trunc('second',a.completed) as completed,
          a.iid, i.title as item, a.resolver as username, u.fullname
          from actual_times a, items i, users u, milestones m
          where a.iid = i.iid
              and i.mid = m.mid
              and a.resolver = u.username
              and m.pid = ?
              and a.completed > ? and a.completed <= ?
          order by a.completed ASC;}, 'Main');

sub completed_times_in_interval {
    my $self = shift;
    my $start = shift;
    my $end = shift;
    my $sth = $self->sql_completed_times_in_interval;
    $sth->execute($self->pid,$start,$end);
    return $sth->fetchall_arrayref({});
}


sub add_milestone {
    my $self = shift;
    my $name = shift;
    my $target_date = untaint_date(shift);
    my $description = shift;
    throw Error::INVALID_TARGET_DATE "invalid target date"
        unless $target_date =~ /^\d{4}-\d{1,2}-\d{1,2}$/;
    my $milestone = $self->add_to_milestones({
            name => $name, target_date => $target_date, description =>
            $description});
    return $milestone->mid;
}

sub estimated_time {
    my $self = shift;
    my $sth = $self->sql_estimated_time;
    $sth->execute($self->pid);
    my $res = $sth->fetchrow_array();
    $sth->finish;
    return $res;
}

sub all_estimated_time {
    my $self = shift;
    my $sth = $self->sql_all_estimated_time;
    $sth->execute($self->pid);
    my $res = $sth->fetchrow_array();
    $sth->finish;
    return $res;
}

sub completed_time {
    my $self = shift;
    my $sth = $self->sql_completed_time;
    $sth->execute($self->pid);
    my $res = $sth->fetchrow_array();
    $sth->finish;
    return $res;
}

sub total_time_in_interval {
    my $self = shift;
    my $start = shift;
    my $end = shift;
    my $sth = $self->sql_total_time_in_interval;
    $sth->execute($self->pid,$start,$end);
    my $res = $sth->fetchrow_array();
    $sth->finish;
    return $res;
}

sub user_time_in_interval {
    my $self = shift;
    my $user = shift;
    my $start = shift;
    my $end = shift;

    my $sth = $self->sql_user_time_in_interval;
    $sth->execute($user,$self->pid,$start,$end);
    my $res = $sth->fetchrow_array();
    $sth->finish;
    return $res;
}

__PACKAGE__->set_sql(items_on =>
qq{SELECT i.iid,i.title,i.type,i.status
FROM items i, milestones m
WHERE i.target_date = ? AND i.mid = m.mid
AND m.pid = ? ORDER BY i.priority DESC;},'Main');


sub items_on {
    my $self = shift;
    my $date = shift;
    my $sth = $self->sql_items_on;
    $sth->execute($date, $self->pid);
    return $sth->fetchall_arrayref({});
}


sub milestone_select {
    my $self = shift;
    my $milestone = shift;
        return [map {
        {
            value => $_->mid,
            label => $_->name . " (" . $_->target_date . ")",
            selected => ($_->mid == $milestone->mid),
        }
    } $self->milestones()];
}

sub milestones_on {
    my $self = shift;
    my $date = untaint_date(shift);
    my @milestones = PMT::Milestone->search_milestones_on($date,$self->pid);
    return \@milestones;
}

sub status_select {
    my $self = shift;
    if (defined($self)) {
        return selectify([@PROJECT_STATUSES], [@PROJECT_STATUSES],
            [$self->status]);
    } else {
        return selectify([@PROJECT_STATUSES], [@PROJECT_STATUSES],[]);
    }
}

sub approaches_select {
    my $self = shift;
    if (defined($self)) {
        return selectify([@APPROACHES],[@APPROACHES], [$self->approach]);
    } else {
        return selectify([@APPROACHES],[@APPROACHES], []);
    }
}

sub scales_select {
    my $self = shift;
    if (defined($self)) {
        return selectify([@SCALES],[@SCALES],[$self->scale]);
    } else {
        return selectify([@SCALES],[@SCALES],[]);
    }
}

sub distribs_select {
    my $self = shift;
    if (defined($self)) {
        return selectify([@DISTRIBS],[@DISTRIBS],[$self->distrib]);
    } else {
        return selectify([@DISTRIBS],[@DISTRIBS],[]);
    }
}

sub areas_select {
    my $self = shift;
    if (defined($self)) {
        return selectify([@AREAS],[@AREAS],[$self->area]);
    } else {
        return selectify([@AREAS],[@AREAS],[]);
    }
}

sub restricteds_select {
    my $self = shift;
    return selectify([@RESTRICTEDS],[@RESTRICTEDS],[$self->restricted]);
}

sub types_select {
    my $self = shift;
    if (defined($self)) {
        return selectify([@TYPES],[@TYPES],[$self->type]);
    } else {
        return selectify([@TYPES],[@TYPES],[]);
    }
}

sub personnel {
    my $self = shift;
    return grep { $_->status eq "active" } map {PMT::User->retrieve($_->username) }
    PMT::WorksOn->search(pid => $self->pid);
}


sub personnel_in_project {
    my $self = shift;
    return grep {
        $_->status eq "active";
    }  map {
        PMT::User->retrieve($_->username);
    } PMT::WorksOn->search({pid => $self->pid});
}

# returns list of Users who are in the project
# includes all Users in groups that are in the project
# (recursively)
sub all_personnel_in_project {
    my $self = shift;
    my @users;
    my %unique;
    foreach my $user ($self->personnel_in_project()) {
        $unique{$user->username} = $user;
        if($user->grp) {
            # user is a group so we need the members
            my $groups = $user->all_users_in_group();
            foreach my $u (values %{$groups}) {
                next if exists $unique{$u->username};
                $unique{$u->username} = $u;
            }
        }
    }

    return sort {uc($a->fullname) cmp uc($b->fullname) } map {$unique{$_}} keys %unique;
}

# {{{ owner_select

sub owner_select {
    my $self        = shift;
    my $owner       = shift;
    return [map {
        {
            value => $_->username,
            label => $_->fullname,
            selected => ($_->username eq $owner->username),
        }
    } $self->all_personnel_in_project()];
}

# }}}

# {{{ assigned_to_select

sub assigned_to_select {
    my $self        = shift;
    my $assigned_to = shift;
    return [map {
        {
            value => $_->username,
            label => $_->fullname,
            selected => ($_->username eq $assigned_to->username),
        }
    } $self->all_personnel_in_project()];
}

# }}}

sub new_assigned_to_or_owner_select {
    my $self        = shift;
    my $exclude     = shift;
    my $default     = shift;
    my $users = [map {
        {
            value => $_->username,
            label => $_->fullname,
            selected => ($_->username eq $default->username),
        }
    } grep {
        $_->username ne $exclude->username
    } $self->all_personnel_in_project()];
    if (!@$users) {
        $users = [{value => $default->username, label => $default->fullname, selected => 1}];
    }
    return $users;
}



# {{{ all_items_in_project

sub all_items_in_project {
    my $self = shift;
    my $skip = shift || 0;
    my $sth = $self->sql_all_items_in_project;
    $sth->execute($self->pid);

    return [sort {
        $b->{'type'} cmp $a->{'type'}
    } grep {
        $_->{iid} != $skip
    } values %{$sth->fetchall_hashref('iid')}];
}

# }}}

sub groups_in_project {
    my $self = shift;
    return grep {PMT::User->retrieve($_->username)->grp} PMT::WorksOn->search(pid => $self->pid);
}

sub project_role {
    my $self     = shift;
    my $username = shift;
    my @w = PMT::WorksOn->search(pid => $self->pid, username => $username);
    if (scalar @w) {
        return $w[0]->auth;
    } else {
        # we have to go recursively through the groups to find a match
        foreach my $g ($self->groups_in_project()) {
            my $guser = PMT::User->retrieve($g->username);
            my $ut = $guser->all_users_in_group();
            if(exists $ut->{$username}) {
                return $g->auth;
            }
        }
    }
}

sub caretaker_select {
    my $self      = shift;
    my $caretaker = $self->caretaker;
    return [map {
        {
            value => $_->username,
            label => $_->fullname,
            selected => ($_->username eq $caretaker->username),
        }
    } $self->personnel()];
}

sub new_caretaker_select {
    my $self      = shift;
    my $potential = shift;
    my $caretaker = $self->caretaker;
    my $personnel = [map {
        {
            value => $_->username,
            label => $_->fullname,
            selected => ($_->username eq $potential->username),
        }
    } grep {$_->username ne $caretaker->username} $self->personnel()];

    if (!@$personnel) {
        $personnel = [{value => $potential->username, label => $potential->fullname,
                      selected => 1}];
    }
    return $personnel;
}


sub all_non_personnel_select {
    my $self = shift;
    my @selected = ($self->personnel());
    my %selected = map {$_->username => 1} @selected;

    my @users = PMT::User->all_active();
    @users = grep {!exists $selected{$_->username}} @users;

    return [map {
        {
            value => $_->username,
            label => $_->fullname,
        }
    } @users];
}

sub all_non_clients_select {
    my $self = shift;
    my %selected = map {$_->client_id => 1} $self->clients();
    my @labels = ();
    my @clients = PMT::Client->all_active();

    @clients = grep {!exists $selected{$_->client_id}} @clients;

    return [map {
        {
            value => $_->client_id,
            label => $_->lastname . ", " . $_->firstname,
        }
    } @clients];
}


sub clients_data {
    my $self = shift;
    return [map {my $c = PMT::Client->retrieve($_->client_id);$c->data()} $self->clients()];
}

sub clients_select {
    my $self = shift;
    my $selected = [map {$_->client_id} $self->clients()];
    my @labels = ();
    my $values = [map {
        push @labels, $_->firstname . " " . $_->lastname;
        $_->client_id;
    } PMT::Client->all_active()];
    return selectify($values,\@labels,$selected);
}

sub interval_report {
    my $self = shift;
    my $interval_start = shift;
    my $interval_end = shift;


    # figure out which users have been active during the interval
    my $active_users = $self->active_users_in_interval($interval_start,$interval_end);

    # calculate the total time spent on the project by all users
    my $total_time =
    interval_to_hours($self->total_time_in_interval($interval_start, $interval_end));

    foreach my $user (@$active_users) {
        $user->{time} = $self->user_time_in_interval($user->{username},
            $interval_start,$interval_end);
        $user->{hours} = interval_to_hours($user->{time});
    }

    # get individual times
    my $indivs = $self->completed_times_in_interval($interval_start,$interval_end);

    return {active_users => $active_users,
            total_time => $total_time,
            individual_times => $indivs,
        };
}


sub add_cc {
    my $self   = shift;
    my $user = shift;

    # 1) add pid and username into notify_project table
    my $n = PMT::NotifyProject->find_or_create({pid => $self->pid,
            username => $user->username}) unless $self->cc($user);

    # 2) add username and all iid under this pid into notify table
    #     a) extract all iid under this pid
    my $iids = $self->all_items_in_project();

    #     b) foreach item under this project, add user and item in notify
    foreach my $item (@$iids) {
       my $i = PMT::Notify->find_or_create({iid => $item->{iid},
            username => $user->username});
    }

}

sub drop_cc {
    my $self     = shift;
    my $user     = shift;

    # 1) remove all iid under this pid and username from notify table
    #     a) extract all iid under this pid
    my $iids = $self->all_items_in_project();

    #     b) foreach item under this project, check which user
    #        is not assigned to the item
    foreach my $i (@$iids) {
        my $item = PMT::Item->retrieve($i->{iid});
        $item->drop_cc($user);
    }

    # 2) remove pid and username from notify_project table
    my @res = PMT::NotifyProject->search(pid => $self->pid,
                 username => $user->username);
    if (@res > 0) {
        PMT::NotifyProject->retrieve(pid => $self->pid, username =>
            $user->username)->delete;
    }
}

sub cc {
    my $self     = shift;
    my $user     = shift;

    my @res = PMT::NotifyProject->search(pid => $self->pid,
        username => $user->username);
    if (scalar @res) {
        return 1;
    } else {
        return 0;
    }
}

sub estimate_graph {
    my $self = shift;
    my $table_width = shift || 150.0;
    my $remaining = interval_to_hours($self->estimated_time);
    my $completed = interval_to_hours($self->completed_time);
    my $estimated = interval_to_hours($self->all_estimated_time);

    my ($done,$todo,$free,$behind, $completed_behind) = (0,0,0,0,0);
    if (($remaining + $completed) <= $estimated) {
        # ahead of or on schedule
        $free = int($estimated - ($remaining + $completed));
        $done = $completed;
        $todo = $remaining;
    } else {
        # behind schedule
        $behind = int(($remaining + $completed) - $estimated);
        if ($completed <= $estimated) {
            # remaining is what puts us behind schedule
            $todo = int($estimated - $completed);
        } else {
            # we're behind schedule on completed alone
            $done = int($estimated);
            $completed_behind = int($completed - $estimated);
        }
    }
    my $total = ($done + $todo + $free + $behind + $completed_behind);
    if ($total == 0) { $total = 1; } # guard against divide by zero errors
    my $scale = $table_width / $total;

    $done = int($done * $scale);
    $todo = int($todo * $scale);
    $free = int($free * $scale);
    $behind = int($behind * $scale);
    $completed_behind = int($completed_behind * $scale);

    return ($done,$todo,$free,$completed_behind,$behind);
}

__PACKAGE__->set_sql(all_projects_by_last_mod => qq{
    SELECT m.pid,date_trunc('minute',max(i.last_mod)) as last_mod
    FROM milestones m LEFT OUTER JOIN items i on m.mid = i.mid
    GROUP BY m.pid;},
                     'Main');

sub all_projects_by_last_mod {
    my $self = shift;
    my $sth = $self->sql_all_projects_by_last_mod;
    $sth->execute();
    my %results = ();
    foreach my $r (@{$sth->fetchall_arrayref({})}) {
        $results{$r->{pid}} = $r->{last_mod};
    }
    return \%results;
}

sub set_caretaker {
    my $self = shift;
    my $caretaker = shift;
    $self->caretaker($caretaker);
}

sub projects_active_during {
    my $self       = shift;
    my $week_start = shift;
    my $week_end   = shift;
    my $groups     = shift;
    my $groups_string = join ',', map {"'$_'"} @{$groups};
    my $sql = qq{ select distinct p.pid,p.name,p.projnum
                      from projects p, milestones m, items i, actual_times a, in_group g
                      where p.pid = m.pid and m.mid = i.mid and i.iid = a.iid
                      and a.resolver = g.username and g.grp in
                      ($groups_string)
                      and a.completed > ? and a.completed <= ?
                      order by p.projnum
;};
    $self->set_sql(projects_active_during => $sql, 'Main');
    my $sth = $self->sql_projects_active_during;
    $sth->execute($week_start,$week_end);
    return $sth->fetchall_arrayref({});
}


sub projects_active_between {
    my $self       = shift;
    my $date_start = shift;
    my $date_end   = shift;

    my $sql = qq{
      select p.pid, p.name as project_name, p.projnum as project_number,
      date(tempalias.max) as project_last_worked_on, p.status as project_status,
      u.fullname as caretaker_fullname, u.username as caretaker_username, tempalias.sum as time_worked_on
          from
        ( select p.pid, max(completed), sum(a.actual_time)
          from projects p, milestones m, items i, actual_times a
          where p.pid = m.pid and m.mid = i.mid and i.iid = a.iid
          and a.completed >= ? and a.completed <= ? group by p.pid
        ) as tempalias, projects p, users u
        where tempalias.pid=p.pid and p.caretaker=u.username
        order by max desc;
    };

    $self->set_sql(projects_active_between => $sql, 'Main');
    my $sth = $self->sql_projects_active_between;
    $sth->execute($date_start,$date_end);
    return $sth->fetchall_arrayref({});

}


sub project_search {
    my $self = shift;
    my %args = @_;

    my $sql = qq{select p.pid,p.projnum,p.name,p.status,p.area,p.caretaker,u.fullname as caretaker_fullname
                     from projects p, users u where u.username = p.caretaker };
    my @values = ();
    my @conditions = ();
    foreach my $k (qw/type area approach scale distrib status/) {
        next unless $args{$k};
        push @conditions, "p.$k = ?";
        push @values, $args{$k};
    }
    if ($args{'personnel'}) {
	push @conditions, "p.pid in (select w.pid from works_on w where w.username = ?)";
        push @values, $args{'personnel'};
    }
    $sql .= " AND " if @conditions;
    $sql .= join " AND ", @conditions;
    $sql .= " order by upper(p.name) ASC;";
    $self->set_sql(project_search => $sql, 'Main');
    my $sth = $self->sql_project_search;
    $sth->execute(@values);
    return $sth->fetchall_arrayref({});
}

__PACKAGE__->set_sql(recent_project_logs =>
                     qq{select n.nid,n.replies,
                        to_char(added,'FMMonth FMDDth, YYYY') AS added_informal,
                        n.author,u.fullname as author_fullname
                            from nodes n, users u where n.type = 'log'
                            and n.author = u.username
                            and n.author in (select username from works_on where pid = ?)
                            order by modified desc limit 10;}, 'Main');

sub recent_project_logs {
    my $self = shift;
    my $sth = $self->sql_recent_project_logs;
    $sth->execute($self->pid);
    return $sth->fetchall_arrayref({});
}

sub someday_maybe_milestone {
    my $self = shift;
    my @milestones = PMT::Milestone->search(pid => $self->pid, name => 'Someday/Maybe');
    if (scalar (@milestones)) {
        return $milestones[0];
    } else {
        # no existing someday/maybe milestone. need to add one.
        my $m = $self->add_to_milestones({
            name        => 'Someday/Maybe',
            target_date => '2015-01-01',
            status      => 'OPEN',
            description => qq{A milestone for items that will not be immediately worked on. Items in this milestone
                                  will not appear on a homepage or in time estimates. },
            });
        return $m;
    }
}


1;
