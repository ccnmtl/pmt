use lib qw(..);

package PMT::Item;
use base 'CDBI::DBI';
use PMT::Common;

__PACKAGE__->table("items");
__PACKAGE__->sequence("items_s");
__PACKAGE__->columns(All => qw/iid type owner assigned_to title mid url
status description priority r_status last_mod target_date estimated_time/);
__PACKAGE__->has_a(mid => 'PMT::Milestone');
__PACKAGE__->has_a(owner => 'PMT::User');
__PACKAGE__->has_a(assigned_to => 'PMT::User');
__PACKAGE__->has_many(actual_times => 'PMT::ActualTime', 'iid');
__PACKAGE__->has_many(notifies => 'PMT::Notify', 'iid');
__PACKAGE__->has_many(keywords => 'PMT::Keyword', 'iid');
__PACKAGE__->has_many(events => 'PMT::Event', 'item');
__PACKAGE__->has_many(comments => 'PMT::Comment', 'item');
__PACKAGE__->has_many(dependents => 'PMT::Dependency', 'dest');
__PACKAGE__->has_many(dependencies => 'PMT::Dependency', 'source');
__PACKAGE__->has_many(clients => 'PMT::ItemClients', 'iid');

__PACKAGE__->add_constructor(assigned_to_user => qq{status in
('OPEN','INPROGRESS','UNASSIGNED') and assigned_to = ?});

__PACKAGE__->add_constructor(unclosed_items_in_milestone => qq{
mid = ? and status in ('UNASSIGNED','OPEN','RESOLVED','INPROGRESS')});

__PACKAGE__->set_sql(is_notifying_user => qq{select count(*) from notify where username = ? and iid = ?});

__PACKAGE__->set_sql(resolve_times => qq{select 
    to_char(date_part('day',a.actual_time)*24 + date_part('hour',a.actual_time),'FM00') || ':' || to_char(date_part('minute',a.actual_time),'FM00'),
    to_char(a.completed,'YYYY-MM-DD HH24:MI'),
    a.resolver,
    u.fullname
    from   actual_times a, users u 
    where  a.iid = ?
    and  u.username = a.resolver 
    order by completed ASC;}, 'Main');

__PACKAGE__->set_sql(history => qq{
SELECT e.status,to_char(e.event_date_time,'YYYY-MM-DD HH24:MI:SS'),
c.username,u.fullname,c.comment
FROM events e, users u, comments c
WHERE e.eid = c.event AND e.item = ? AND c.username = u.username
ORDER BY e.event_date_time ASC;},'Main');

__PACKAGE__->set_sql(comments => qq{
SELECT c.comment,to_char(c.add_date_time,'YYYY-MM-DD HH24:MI:SS'),c.username, u.fullname
FROM comments c, users u
WHERE c.item = ? AND c.username = u.username
ORDER BY c.add_date_time DESC;}, 'Main');

my %PRIORITIES = (4 => 'CRITICAL', 3 => 'HIGH', 2 => 'MEDIUM', 1 => 'LOW',
0 => 'ICING');


sub is_notifying_user {
    my $self     = shift;
    my $username = shift;

    my $sth = $self->sql_is_notifying_user;
    $sth->execute($username, $self->iid);
    my @res = $sth->fetchrow_array();
    $sth->finish;
    return $res[0];
}


sub resolve_times {
    my $self = shift;
    my $sth = $self->sql_resolve_times;
    $sth->execute($self->iid);
    return [map {
        {
            actual_time => $_->[0],
            completed => $_->[1],
            resolver_username => $_->[2],
            resolver_fullname => $_->[3],
        }
    } @{$sth->fetchall_arrayref()}];
}

sub history {
    my $self = shift;
    my $sth = $self->sql_history;
    $sth->execute($self->iid);
    use Text::Tiki;
    my $tiki = new Text::Tiki();
    return [map {
        my $data = {
            status => $_->[0],
            event_date_time => $_->[1],
            username => $_->[2],
            fullname => $_->[3],
            comment => $_->[4],
        };
        $data->{comment} = $data->{comment} || "";
        $data->{comment} = $tiki->format($data->{comment});
        $data->{comment} =~ s{&lt;br /&gt;\s*}{\n}g;
        $data->{comment} =~ s{&lt;(/?)b&gt;}{<$1b>}g;
        $data;
    } @{$sth->fetchall_arrayref()}];
}

sub get_comments {
    my $self = shift;
    my $sth = $self->sql_comments;
    $sth->execute($self->iid);
    use Text::Tiki;
    my $tiki = new Text::Tiki();
    return [map {
        my $data = {
            comment       => $_->[0],
            add_date_time => $_->[1],
            username      => $_->[2],
            fullname      => $_->[3],
        };
        $data->{comment} = $data->{comment} || "";
	$data->{comment} = $tiki->format($data->{comment});
	$data;
    } @{$sth->fetchall_arrayref()}];
}


#Min's addition to implement email opt in/out
sub data_withuser {
    my $self = shift;
    my $username = shift;

     
    my %type_classes = (bug => 'bug', 'action item' => 'actionitem');
    return {
        iid                  => $self->iid, 
	type                 => $self->type, 
	owner                => $self->owner->username,
        assigned_to          => $self->assigned_to->username, 
        owner_fullname       => $self->owner->fullname,
        assigned_to_fullname => $self->assigned_to->fullname,
        title                => $self->title, 
        mid                  => $self->mid->mid, 
        milestone            => $self->mid->name,
        pid                  => $self->mid->pid->pid,
        project              => $self->mid->pid->name,
        url                  => $self->url, 
	status               => $self->status,
        description          => $self->description, 
	priority             => $self->priority,
        priority_label       => $PRIORITIES{$self->priority},
        r_status             => $self->r_status, 
	last_mod             => $self->last_mod_clean,
        target_date          => $self->target_date, 
        estimated_time       => PMT::Common::interval_to_hours($self->estimated_time),
        type_class           => $type_classes{$self->type},
        priority_select      => $self->priority_select(), 
        status_select        => $self->status_select(),
	notify               => $self->is_notifying_user($username),
    };
}

sub data {
    my $self = shift;

    my %type_classes = (bug => 'bug', 'action item' => 'actionitem');
    return {
        iid                  => $self->iid, 
	type                 => $self->type, 
	owner                => $self->owner->username,
        assigned_to          => $self->assigned_to->username, 
        owner_fullname       => $self->owner->fullname,
        assigned_to_fullname => $self->assigned_to->fullname,
        title                => $self->title, 
        mid                  => $self->mid->mid, 
        milestone            => $self->mid->name,
        pid                  => $self->mid->pid->pid,
        project              => $self->mid->pid->name,
        url                  => $self->url, 
	status               => $self->status,
        description          => $self->description, 
	priority             => $self->priority,
        priority_label       => $PRIORITIES{$self->priority},
        r_status             => $self->r_status, 
	last_mod             => $self->last_mod_clean,
        target_date          => $self->target_date, 
        estimated_time       => PMT::Common::interval_to_hours($self->estimated_time),
        type_class           => $type_classes{$self->type},
        priority_select      => $self->priority_select(), 
        status_select        => $self->status_select(),
    };
}

sub clients_data {
    my $self = shift;
    return [map {my $i = PMT::Client->retrieve($_->client_id); $i->data()} $self->clients()];
}

sub clients_select {
    my $self = shift;
    my $clients = [map {$_->client_id} $self->clients()];
    my @labels = ();
    my %seen_clients = ();
    my @values = map {
	push @labels, "$_->{firstname} $_->{lastname}";
        $seen_clients{$_->{client_id}} = "1";
	$_->{client_id};
    } @{$self->mid->pid->clients_data()};
    # handle the special case of services projects where
    # items may have a client that hasn't been added
    # to the project. the select list needs to also include
    # that client so it doesn't get lost.
    foreach my $client ($self->clients()) {
        my $c = PMT::Client->retrieve($client->client_id);
        next if $seen_clients{$c->client_id};
        push @labels, $c->firstname . " " . $c->lastname;
        push @values, $c->client_id;
    }
    return selectify(\@values,\@labels,$clients);
}

sub last_mod_clean {
    my $self = shift;
    my $last_mod = $self->last_mod;
    $last_mod =~ s/(\.\d+)$//;
    my $t = Time::Piece->strptime($last_mod, "%Y-%m-%d %T");
    return $t->ymd . " " . $t->hms;
}

sub priority_select {
    my $self = shift;
    my @ps = qw/4 3 2 1 0/;
    return [map {
        {
            value => $_,
            label => $PRIORITIES{$_},
            selected => ($_ == $self->priority),
        }
    } @ps];
}

sub status_select {
    my $self     = shift;
    my $status   = $self->status;
    my $r_status = $self->r_status;

    # REFACTOR: it would be nice to have these mappings
    # in a  config file somewhere
    my %labels = (OPEN                => 'OPEN',
                  UNASSIGNED          => 'UNASSIGNED',
                  INPROGRESS          => 'IN PROGRESS',
                  RESOLVED_FIXED      => 'RESOLVED (FIXED)',
                  RESOLVED_INVALID    => 'RESOLVED (INVALID)',
                  RESOLVED_WONTFIX    => 'RESOLVED (WONTFIX)',
                  RESOLVED_DUPLICATE  => 'RESOLVED (DUPLICATE)',
                  RESOLVED_WORKSFORME => 'RESOLVED (WORKSFORME)',
                  RESOLVED_NEEDINFO   => 'RESOLVED (NEEDINFO)',
                  VERIFIED            => 'VERIFIED',
                  CLOSED              => 'CLOSED');

    my %options = (OPEN                => ['OPEN','INPROGRESS','RESOLVED_FIXED',
                                           'RESOLVED_INVALID','RESOLVED_WONTFIX',
                                           'RESOLVED_DUPLICATE','RESOLVED_WORKSFORME',
                                           'RESOLVED_NEEDINFO'],
                   UNASSIGNED          => ['UNASSIGNED', 'OPEN', 'INPROGRESS', 
                                           'RESOLVED_FIXED', 'RESOLVED_INVALID',
                                           'RESOLVED_WONTFIX', 'RESOLVED_DUPLICATE',
                                           'RESOLVED_NEEDINFO', 'RESOLVED_WORKSFORME'],
                   INPROGRESS          => ['INPROGRESS','OPEN','RESOLVED_FIXED',
                                           'RESOLVED_INVALID','RESOLVED_WONTFIX',
                                           'RESOLVED_DUPLICATE','RESOLVED_WORKSFORME',
                                           'RESOLVED_NEEDINFO'],
                   RESOLVED_FIXED      => ['RESOLVED_FIXED','RESOLVED_INVALID',
                                           'RESOLVED_WONTFIX','RESOLVED_DUPLICATE',
                                           'RESOLVED_WORKSFORME','RESOLVED_NEEDINFO',
                                           'OPEN','VERIFIED'],
                   RESOLVED_INVALID    => ['RESOLVED_INVALID','RESOLVED_FIXED',
                                           'RESOLVED_WONTFIX','RESOLVED_DUPLICATE',
                                           'RESOLVED_WORKSFORME','RESOLVED_NEEDINFO',
                                           'OPEN','VERIFIED'],
                   RESOLVED_WONTFIX    => ['RESOLVED_WONTFIX','RESOLVED_INVALID',
                                           'RESOLVED_FIXED','RESOLVED_DUPLICATE',
                                           'RESOLVED_WORKSFORME','RESOLVED_NEEDINFO',
                                           'OPEN','VERIFIED'],
                   RESOLVED_DUPLICATE  => ['RESOLVED_DUPLICATE','RESOLVED_INVALID',
                                           'RESOLVED_WONTFIX','RESOLVED_FIXED',
                                           'RESOLVED_WORKSFORME','RESOLVED_NEEDINFO',
                                           'OPEN','VERIFIED'],
                   RESOLVED_WORKSFORME => ['RESOLVED_WORKSFORME','RESOLVED_INVALID',
                                           'RESOLVED_WONTFIX','RESOLVED_DUPLICATE',
                                           'RESOLVED_FIXED','RESOLVED_NEEDINFO',
                                           'OPEN','VERIFIED'],
                   RESOLVED_NEEDINFO   => ['RESOLVED_NEEDINFO','RESOLVED_INVALID',
                                           'RESOLVED_WORKSFORME','RESOLVED_WONTFIX',
                                           'RESOLVED_DUPLICATE','RESOLVED_FIXED',
                                           'OPEN','VERIFIED'],
                   VERIFIED            => ['VERIFIED','OPEN'],
                   CLOSED              => ['CLOSED','OPEN']);
    my $combined;
    if(defined($r_status) && $r_status ne "" && $status eq "RESOLVED") {
        $combined = $status . "_" . $r_status;
    } else {
        $combined = $status;
    }

    return [map {
        { 
            value => $_,
            label => $labels{$_},
            selected => ($_ eq $combined),
        }
    } @{$options{$combined}}]
}

sub keywords_select {
    my $self     = shift;
    my $selected = shift;
    my %selected = map {$_->{keyword} => 1} @$selected;
    my $project = $self->mid->pid;
    return [map {
	{
	    value => $_->{keyword},
	    label => $_->{keyword},
	    selected => exists $selected{$_->{keyword}},
	}
    } @{$project->keywords()}];
}

# returns 1 if any of the item's dependencies are still open
# returns 0 if all resolved or closed
sub check_dependencies {
    my $self = shift;
    foreach my $d ($self->dependencies()) {
        my $dest = PMT::Item->retrieve($d->dest);
	return 1 if $dest->status eq "OPEN" || $dest->status eq "UNASSIGNED" 
	    || $dest->status eq "INPROGRESS";
    }
    return 0;
}

sub close {
    my $self = shift;
    my $user = shift;
    if ($self->status eq "VERIFIED") {
        $self->status('CLOSED');
        $self->touch();
        $self->add_event('CLOSED',"<b>milestone closed</b><br />",$user);
    }
}

sub add_event {
    my $self = shift;
    my $status = shift;
    my $comment = shift;
    my $user = shift;
    my $event = $self->add_to_events({status => $status});
    my $c = $event->add_to_comments({comment => $comment, 
            username => $user}); 
}

sub add_comment {
    my $self     = shift;
    my $user     = shift;
    my $comment  = shift || return; # if there's no comment to add, don't add it
    $self->add_to_comments({username => $user, comment => $comment});
}


sub touch {
    my $self = shift;
    use Time::Piece;
    my $t = localtime();
    $self->last_mod($t->datetime);
    $self->update();
}

sub add_resolve_time {
    my $self = shift;
    my $user = shift;
    my $resolve_time = shift || "";
    my $completed    = shift || "";
    return unless $resolve_time;
    if(!$completed) {
        my ($sec,$min,$hour,$mday,$mon,
            $year,$wday,$yday,$isdst) = localtime(time); 
        $year += 1900;
        $mon += 1;
        $completed = "$year-$mon-$mday $hour:$min:$sec";
    } 
    my $at = PMT::ActualTime->create({
            iid => $self->iid, resolver => $user->username, actual_time =>
            $resolve_time, completed => $completed});
    
}

sub add_cc {
    my $self     = shift;
    my $user     = shift;
    my $n = PMT::Notify->find_or_create({iid => $self->iid, 
            username => $user->username});
}

sub drop_cc {
    my $self     = shift;
    my $user     = shift;

    #Min's changes to implement email notification opt in/out
    #check first if user is assigned to the item
    my @notifies = PMT::Item->search(iid => $self->iid, 
        assigned_to => $user->username);

    #if the user is not assigned to the item, delete from notify table 
    unless (scalar @notifies) {
        PMT::Notify->search(iid => $self->iid, username =>
            $user->username)->delete_all;
    } 
}

# returns boolean on whether or not $username is on notify list for item $iid
sub cc {
    my $self     = shift;
    my $user     = shift;
    my @res = PMT::Notify->search(iid => $self->iid, 
        username => $user->username);
    if (scalar @res) {
        return 1;
    } else {
        return 0;
    }
}

# upgrades the priority and target date of all dependencies to make sure
# they are at least as high a priority and at least as soon a target date
sub prioritize_dependent {
    my $self        = shift;
    my $priority    = shift;
    my $target_date = shift;

    if ($priority > $self->priority) {
        $self->priority($priority);
    }
    if (($target_date cmp $self->target_date) == -1) {
        $self->target_date($target_date);
    }
    foreach my $d ($self->dependencies()) {
        my $dest = PMT::Item->retrieve($d->dest);
	$dest->prioritize_dependent($priority,$target_date);
    }
}

# sets up notification for an item
# owner, assigned_to, and all managers for project
# are added by default (without duplication)
sub add_notification {
    my $self = shift;
    
    my $owner = $self->owner;
    my $assigned_to = $self->assigned_to;
    my %notified;

    #Min's changes to implement email notification opt in/out
    #check if the owner wants to be notified of anything about this item 
    if ($self->project_notification($owner) > 0) {
        $notified{$owner->username} = 1;
    }

    #assignees will be notified of anything regarding this item
    $notified{$assigned_to->username} = 1;

    my $project = $self->mid->pid;
    foreach my $m ($project->managers()) {
        #check if manager wants to be notified of anything about this item 
        if ($self->project_notification($m) > 0) {  
	    $notified{$m->username} = 1;
	}
    }

    my @notify = keys %notified;
    $self->notify(\@notify);
}

# Min's addition to implement email notification opt in/out
# queries if the user's name and pid exists in notify_project table
sub project_notification {
    my $self = shift;
    my $user = shift;

    my @notifies = PMT::NotifyProject->retrieve(pid => $self->mid->pid->pid, 
        username => $user->username);
    return scalar @notifies;
}


# Min's addition to implement email notification opt in/out
# called by item.pl line 58
sub notify_item {
    my $self     = shift;
    my $username = shift;

    my @notifies = PMT::Notify->search(iid => $self->iid, 
        username => $username);

    if (scalar @notifies) {
       return 1;
    } else {
       return 0;
    }
}


# specifies a list of users to be notified when an
# item is modified or updated
sub notify {
    my $self  = shift;
    my $users = shift;
    foreach my $u (@$users) {
        my $n = PMT::Notify->find_or_create({username => $u, iid =>
                $self->iid});
    }
}

# {{{ update_dependencies

sub update_dependencies {
    my $self = shift;
    my $r    = shift;
    my @dependencies = @$r;
    # clear out the old ones first.
    for my $d ($self->dependencies()) {
        $d->delete;
    }
    
    # put the new ones back in
    foreach my $d (@dependencies) {
	next unless $d;
        my $item = PMT::Item->retrieve($d);
	# skip it if it will create a cycle

	next if $item->cycle([$self->iid]);
        $self->add_to_dependencies({ dest => $item->iid });

	# make sure priorities are in order
    	$item->prioritize_dependent($self->priority,$self->target_date);
    }
}

# recursively goes through the dependency tree and looks 
# for cycles.
sub cycle {
    my $self = shift;
    my $seen = shift;
    return 1 if grep {$_ == $self->iid} @$seen;
    foreach my $d ($self->dependencies()) {
	my @trail = @$seen;
	push @trail, $self->iid;
        my $dest = PMT::Item->retrieve($d->dest);
	return 1 if $dest->cycle(\@trail);
    }
    return 0;
}

sub update_keywords {
    my $self = shift;
    my $r    = shift;
    my @keywords = @$r;
    # clear out old ones first
    $self->keywords()->delete_all;
    # put the new ones back in
    foreach my $k (@keywords) {
	next if $k eq "";
        $self->add_to_keywords({keyword => $k});
    }
}

# }}}

# {{{ clear_clients
# clears the list of clients associated with an item
sub clear_clients {
    my $self = shift;
    $self->clients()->delete_all;
}
# }}}
# {{{ update_clients
sub update_clients {
    my $self = shift;
    my $clients = shift;
    $self->clear_clients();
    foreach my $client (@$clients) {
        my $ic = PMT::ItemClients->create({iid => $self->iid, 
                client_id => $client});
    }
}
# }}}


sub add_client_by_uni {
    my $self = shift;
    my $uni = shift;
    my @clients = PMT::Client->find_by_uni($uni);
    return unless $clients[0];
    
    my @ics = PMT::ItemClients->search(iid => $self->iid, client_id => $clients[0]->client_id);
    return if @ics;

    my $ic = PMT::ItemClients->create({iid => $self->iid,
				       client_id => $clients[0]->client_id});
    
}

sub full_data {
    my $item = shift;

    my %data = %{$item->data()};
    my $owner       = PMT::User->retrieve($data{owner});
    my $assigned_to = PMT::User->retrieve($data{assigned_to});
    my $milestone   = PMT::Milestone->retrieve($data{mid});
    my $project        = $milestone->pid;

    $data{owner_fullname}       = $owner->fullname;
    $data{assigned_to_fullname} = $assigned_to->fullname;
    $data{milestone}            = $milestone->name;
    $data{pid}                  = $milestone->pid->pid;
    $data{project}              = $project->name;
    my $tiki = new Text::Tiki;
    $data{description} = $data{description} || "";
    $data{description_html} = $tiki->format($data{description});
    $data{$data{type}}         = 1;
    $data{keywords}            = [map {$_->data()} $item->keywords()];
    $data{can_resolve}         = ($data{status} eq 'OPEN' || 
				  $data{status} eq 'INPROGRESS' || 
				  $data{status} eq 'RESOLVED');
    $data{resolve_times}       = $item->resolve_times();
    $data{keywords_select}     = $item->keywords_select($data{keywords});
    $data{dependencies}        = [map {PMT::Item->retrieve($_->dest)->data()} $item->dependencies()];
    $data{dependents}          = [map {PMT::Item->retrieve($_->source)->data()} $item->dependents()];
    $data{history}             = $item->history();
    $data{comments}            = $item->get_comments();

    my @full_history = ();

    my %history_items = ();

    foreach my $h (@{$data{history}}) {
	$history_items{$h->{event_date_time}} = $h;
    }
    foreach my $c (@{$data{comments}}) {
	$history_items{$c->{add_date_time}} = $c;
    }

    foreach my $i (sort keys %history_items) {
	my $t = $history_items{$i};
	$t->{timestamp} = $i;
	push @full_history, $t; 
    }

    $data{full_history}        = \@full_history;
    $data{milestone_select}    = $project->milestone_select($milestone);
    $data{assigned_to_select}  = $project->assigned_to_select($assigned_to);
    $data{owner_select}        = $project->owner_select($owner);
    $data{status_select}       = $item->status_select();
    $data{priority_select}     = $item->priority_select();
    $data{dependencies_select} = $project->dependencies_select($data{'iid'}, $data{dependencies});
    if(exists $data{pub_view}) {
	$data{pub_view}            = $data{pub_view} == 1; 
    } else {
	$data{pub_view} = 0;
    }

    $data{clients}        = $item->clients_data();
    $data{clients_select} = $item->clients_select();

    return \%data;
}


1;
