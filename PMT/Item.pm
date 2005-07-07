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

__PACKAGE__->set_sql(resolve_times => qq{select 
    to_char(date_part('day',a.actual_time)*24 + date_part('hour',a.actual_time),'FM00') || ':' || to_char(date_part('minute',a.actual_time),'FM00') as actual_time,
    date_trunc('minute',a.completed) as completed,
    a.resolver as resolver_username,
    u.fullname as resolver_fullname
    from   actual_times a, users u 
    where  a.iid = ?
    and  u.username = a.resolver 
    order by completed ASC;}, 'Main');

sub resolve_times {
    my $self = shift;
    my $sth = $self->sql_resolve_times;
    $sth->execute($self->iid);
    return $sth->fetchall_arrayref({});
}

__PACKAGE__->set_sql(history => qq{
SELECT e.status,date_trunc('second',e.event_date_time) as event_date_time,
c.username,u.fullname,c.comment
FROM events e, users u, comments c
WHERE e.eid = c.event AND e.item = ? AND c.username = u.username
ORDER BY e.event_date_time ASC;},'Main');

sub history {
    my $self = shift;
    my $sth = $self->sql_history;
    $sth->execute($self->iid);
    use Text::Tiki;
    my $tiki = new Text::Tiki();
    return [map {
        $_->{comment} = $_->{comment} || "";
        $_->{comment} = $tiki->format($_->{comment});
        $_->{comment} =~ s{&lt;br /&gt;\s*}{\n}g;
        $_->{comment} =~ s{&lt;(/?)b&gt;}{<$1b>}g;
        $_;
    } @{$sth->fetchall_arrayref({})}];
}

__PACKAGE__->set_sql(comments => qq{
SELECT c.comment,date_trunc('second',c.add_date_time) as add_date_time,
       c.username, u.fullname
FROM comments c, users u
WHERE c.item = ? AND c.username = u.username
ORDER BY c.add_date_time DESC;}, 'Main');

sub get_comments {
    my $self = shift;
    my $sth = $self->sql_comments;
    $sth->execute($self->iid);
    use Text::Tiki;
    my $tiki = new Text::Tiki();
    return [map {
        $_->{comment} = $_->{comment} || "";
	$_->{comment} = $tiki->format($_->{comment});
	$_;
    } @{$sth->fetchall_arrayref({})}];
}


sub data {
    my $self = shift;
    my $username = shift || "";

    my %type_classes = (bug => 'bug', 'action item' => 'actionitem');
    my $notify = "";
    if ($username ne "") {
	$notify = $self->is_notifying_user($username);
    }
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
	notify               => $notify,
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


# queries if the user's name and pid exists in notify_project table
sub project_notification {
    my $self = shift;
    my $user = shift;

    my @notifies = PMT::NotifyProject->retrieve(pid => $self->mid->pid->pid, 
        username => $user->username);
    return scalar @notifies;
}

# boolean test if a user gets notified about an item
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


sub clear_clients {
    my $self = shift;
    $self->clients()->delete_all;
}

sub update_clients {
    my $self = shift;
    my $clients = shift;
    $self->clear_clients();
    $self->add_clients(@$clients);
}


sub add_clients {
    my $self = shift;
    my @clients = @_;
    foreach my $client (@clients) {
	$self->add_to_clients({client_id => $client});
    }
}

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

__PACKAGE__->set_sql(users_to_email => 
		     qq{SELECT u.username,u.email 
			    FROM notify n, users u
			    WHERE n.username = u.username
			    AND u.status = 'active' AND u.grp = 'f'
			    AND n.iid = ? AND u.username <> ?;},
		     'Main');

# emails relevant parties with info for an item
sub email {
    my $self    = shift;
    my $subject = shift;
    my $skip    = shift;

    my $r = $self->full_data();
    my %item = %$r;

    my $project_title = &truncate_string($item{'project'});  
    my $subject_title = &truncate_string($item{'title'});  

    if ($subject =~ /^new/) {
        $subject_title = $subject_title . "(NEW)";  
    } 

    my $email_subj = "[PMT:$project_title] Attn:$item{'assigned_to_fullname'}-$subject_title";
    my $send_to;

    my $owner = $self->owner;
    my $owner_email = $owner->username . " (" . $owner->email . ")";

    my $sth = $self->sql_users_to_email;
    $sth->execute($self->iid,$skip);
    my @users = @{$sth->fetchall_arrayref({})};
    $r = $item{keywords};
    my @keywords = map {$$_{'keyword'};} @$r;
    my $keywords = join ', ', @keywords;
    $r = $item{dependencies};
    my @dependencies = map {$$_{'dest'};} @$r;
    my $dependencies = '';
    if($#dependencies >= 0) {
	my $dependencies = join ', ', @dependencies;
    }

    foreach my $user (@users) {
	$ENV{PATH} = "/usr/sbin";
	open(MAIL,"|/usr/sbin/sendmail -t");
	print MAIL <<END_MESSAGE;
To: $$user{'email'}
From: $owner_email 
Subject: $email_subj

$item{'type'} #: $item{'iid'}
title:\t\t$item{'title'}
owner:\t\t$item{'owner_fullname'}
assigned to:\t$item{'assigned_to_fullname'}\n
status:\t\t$item{'status'}
project:\t$item{'project'}
priority:\t$item{'priority'}
target date:\t$item{'target_date'}
milestone:\t$item{'milestone'}
last modified:\t$item{'last_mod'}\n
url:\t\t$item{'url'}
keywords:\t$keywords
dependencies:\t$dependencies
description: 
$item{'description'}

view $item{'type'}: http://pmt.ccnmtl.columbia.edu/item.pl?iid=$item{'iid'}

please do not reply to this message.
END_MESSAGE
        CORE::close MAIL;
    }
}


# emails relevant parties with info for an item
# when it is updated.
sub update_email {
    my $self    = shift;
    my $subject = shift;
    my $comment = shift;
    my $skip    = shift || "";  #username
    my $r = $self->full_data();
    my %item = %$r;

    $comment =~ s/<b>//g;
    $comment =~ s/<\/b>//g;
    $comment =~ s/<br \/>/\n/g;

    $Text::Wrap::columns = 72;
    my $body = Text::Wrap::wrap("","",$comment);

    my $updater = $skip; 

    if ($skip eq "") {
       $updater = "pmt\@www2.ccnmtl.columbia.edu (Project Management Tool)";
    }

    my $u = PMT::User->retrieve($updater);
    my $updater_info = $updater . "<" . $u->email . ">";

    my $project = $item{'project'};

    my $project_title = &truncate_string($project);
    my $subject_title = &truncate_string($item{'title'});

    my $email_subj = "[PMT:$project_title] Attn:$item{'assigned_to_fullname'}-$subject_title";

    my $sth = $self->sql_users_to_email;
    $sth->execute($self->iid,$skip);
    my @users = @{$sth->fetchall_arrayref({})};

    foreach my $user (@users) {
	$ENV{PATH} = "/usr/sbin";
	open(MAIL,"|/usr/sbin/sendmail -t");
	print MAIL <<END_MESSAGE;
To: $$user{'email'}
From: $updater_info 
Subject: $email_subj

updater: $updater
updater: $updater_info 
project:\t$project
by:\t\t$skip
$item{'type'}:\t$item{'iid'}
title:\t\t$item{'title'}

$body

$item{'type'} URL: http://pmt.ccnmtl.columbia.edu/item.pl?iid=$item{'iid'}

Please do not reply to this message.

END_MESSAGE
        CORE::close MAIL;
    }
}


sub search_items {
    my $self = shift;
    my %args = @_;
    my $pid         = $args{pid};
    my $q           = $args{q};
    my $type        = $args{type};
    my $owner       = $args{owner};
    my $assigned_to = $args{assigned_to};
    my @status      = @{$args{status}};
    my $keyword     = $args{keyword};
    my @show        = $args{show};
    my $number      = $args{number};
    my $sortby      = $args{sortby};
    my $order       = $args{order};
    my $limit       = $args{limit};
    my $offset      = $args{offset};
    my $max_date    = $args{max_date};
    my $min_date    = $args{min_date};

    # ignore non iso8601 dates
    if($max_date !~ /\d{4}-\d{2}-\d{2}/) {
	$max_date = "";
    }

    if($min_date !~ /\d{4}-\d{2}-\d{2}/) {
	$min_date = "";
    }
    

    my $rows = 0;

    my %show;
    foreach my $show (@show) {
	$show{$show} = 1;
    }



    if ($pid ne "" || $q ne "" || $type ne "" || $owner ne "" 
	|| $assigned_to ne "" || $number ne "" || $sortby ne "" || $order ne "") 
    {
	$pid = $pid || "%";
	$owner = $owner || "%";
	$assigned_to = $assigned_to || "%";
	if($q ne "") {
	    $q = "%$q%";
	} else {
	    $q = "%";
	}

	
	my %orders = (type => "i.type DESC, i.priority $order",
		      priority => "i.priority $order, i.target_date ASC",
		      target_date => "i.target_date $order, i.priority DESC",
		      project => "upper(p.name) $order, i.priority DESC, i.target_date ASC",
		      owner => "upper(uo.fullname) $order, i.priority DESC, i.target_date ASC",
		      assigned_to => "upper(ua.fullname) $order, i.priority DESC, i.target_date ASC",
		      status => "i.status $order, i.r_status $order, i.priority DESC, i.target_date ASC",
		      last_mod => "i.last_mod $order",
		      milestone => "upper(m.name) $order, i.priority DESC, i.target_date ASC",
		      created => "i.iid $order",
		      );

	my $order_string = $orders{$sortby} || die "bad sortby";
	my $query_string;
	$query_string = qq{
	    SELECT i.iid,i.title,i.description,i.type,i.owner,i.assigned_to,uo.fullname as owner_fullname,
                   ua.fullname as assigned_to_fullname,i.priority,i.target_date,i.url,i.last_mod,
	           i.mid,m.name as milestone,m.pid,p.name as project,i.status,i.r_status
		FROM items i, milestones m, projects p, users uo, users ua
		WHERE i.mid = m.mid
		AND m.pid = p.pid 
		AND i.owner = uo.username 
		AND i.assigned_to = ua.username
	    };
	my @args;
	if($type ne '%') {
	    $query_string .= qq{ AND i.type = ? };
	    push @args, $type;
	}

	if($max_date ne "") {
	    $query_string .= qq{ AND i.target_date <= ? };
	    push @args, $max_date;
	}

	if($min_date ne "") {
	    $query_string .= qq{ AND i.target_date >= ? };
	    push @args, $min_date;
	}

	my $status_string = "";
	foreach my $stat (@status) {
	    if ($stat =~ /_/) {
		my ($s,$r) = split /_/, $stat;
		$status_string .= "OR (i.status = 'RESOLVED' AND i.r_status like ?) ";
		push @args, $r;
	    } else {
		$status_string .= "OR i.status = ? ";
		push @args, $stat;
	    }
	}
	# remove the extra "OR" at the beginning
	if($status_string ne "") { 
	    $status_string = substr($status_string,2);
	    $query_string .= qq{ AND ($status_string) };
	}
	if($pid ne '%') {
	    $query_string .= qq{ AND p.pid = ? };
	    push @args, $pid;
	}
	if($owner ne "%") {
	    $query_string .= qq{ AND uo.username = ? };
	    push @args, $owner;
	}
	if($assigned_to ne "%") {
	    $query_string .= qq{ AND ua.username = ? };
	    push @args, $assigned_to;
	}
	if($q ne "%") {
	    $query_string .= qq{
		AND ( (i.iid IN (select k.iid 
				 from keywords k 
				 where upper(k.keyword) like upper(?)
				 )) OR
		      upper(i.title) LIKE upper(?) 
		      OR upper(i.description) LIKE upper(?))	    
		};
	    push @args, ($q,$q,$q);
	}
	$query_string .= qq{
		AND (p.pid IN (select w.pid 
			       from works_on w 
			       where username = ?) 
		     OR p.pub_view = 'true')
		ORDER BY $order_string
		LIMIT $limit OFFSET $offset;
	};
	push @args, $username;
	$self->set_sql(items_search => $query_string, 'Main');
	my $sth = $self->sql_items_search;
	$sth->execute(@args);
	return $sth->fetchall_arrayref({});
    }
}

__PACKAGE__->set_sql(recent_items => qq{select i.iid,i.type,i.title,i.status,p.name as project,p.pid 
		     from items i, projects p, milestones m 
		     where i.mid = m.mid AND m.pid = p.pid
		     AND (p.pid in (select w.pid from works_on w 
				    where username = ?) 
			  OR p.pub_view = 'true')
		     order by last_mod desc limit 10;}, 'Main');

sub recent_items {
    my $self = shift;
    my $username = shift;
    my $sth = $self->sql_recent_items;
    $sth->execute($username);
    return $sth->fetchall_arrayref({});
}


1;
