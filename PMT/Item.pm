use lib qw(..);

package PMT::Item;
use base 'CDBI::DBI';
use PMT::Common;
use Text::Wrap;

__PACKAGE__->table("items");
__PACKAGE__->sequence("items_s");
__PACKAGE__->columns(All => qw/iid type owner assigned_to title mid url
status description priority r_status last_mod target_date estimated_time/);
__PACKAGE__->has_a(mid => 'PMT::Milestone');
__PACKAGE__->has_a(owner => 'PMT::User');
__PACKAGE__->has_a(assigned_to => 'PMT::User');
__PACKAGE__->has_many(actual_times => 'PMT::ActualTime', 'iid');
__PACKAGE__->has_many(notifies => 'PMT::Notify', 'iid');
__PACKAGE__->has_many(events => 'PMT::Event', 'item');
__PACKAGE__->has_many(comments => 'PMT::Comment', 'item');
__PACKAGE__->has_many(clients => 'PMT::ItemClients', 'iid');
__PACKAGE__->has_many(attachments => 'PMT::Attachment', 'item_id');

__PACKAGE__->add_constructor(assigned_to_user => qq{status in
('OPEN','INPROGRESS','UNASSIGNED') and assigned_to = ?});

__PACKAGE__->add_constructor(unclosed_items_in_milestone => qq{
mid = ? and status in ('UNASSIGNED','OPEN','RESOLVED','INPROGRESS')});

__PACKAGE__->set_sql(is_notifying_user => qq{select count(*) from notify where username = ? and iid = ?});


my %PRIORITIES = (4 => 'CRITICAL', 3 => 'HIGH', 2 => 'MEDIUM', 1 => 'LOW',
0 => 'ICING');


sub add_item {
    my $args = shift || throw Error::NO_ARGUMENTS "no arguments given to add_item()";
    my %args = %$args;
    my $status;
    my $username = untaint_username($args{'owner'});
    my $milestone = PMT::Milestone->retrieve($args{mid});
    my $project = $milestone->pid;
    my $user = PMT::User->retrieve($username);
    my $owner = PMT::User->retrieve($args{owner});
    my $assigned_to = PMT::User->retrieve($args{assigned_to});

    if($args{'assigned_to'} eq 'caretaker') {
        $args{'assigned_to'} = $project->caretaker->username;
        $status = 'UNASSIGNED';
    }
    if(!$project->project_role($username)) {
        # if the person submitting the item isn't on the project
        # team, we need to add them as a guest on the project
        my $w = PMT::WorksOn->create({username => $username,pid => $project->pid, auth => 'guest'});
        $status = 'UNASSIGNED';
    }

    $status = $status || 'OPEN';

    $args{priority} = $args{priority} || "0";

    my $item = PMT::Item->create({
            type => $args{type}, owner => $owner, assigned_to =>
            $assigned_to, title => $args{title}, mid => $milestone, url =>
            $args{url}, status => $status, description =>
            escape($args{description}), priority => $args{priority},
            target_date => $args{target_date}, estimated_time =>
            $args{estimated_time}});

    $item->update_tags($args{tags},$username);
    $item->add_clients(@{$args{clients}});

    $item->setup_default_notification();
    $item->add_project_notification();

    $item->add_event($status,"<b>$args{'type'} added</b>",$user);
    $item->email("new $args{'type'}: $args{'title'}",$username);

    # the milestone may need to be reopened
    $milestone->update_milestone($user);
    return $item->iid;
}


sub tags {
    my $self = shift;
    my $iid = $self->{iid};
    my $url = "item/item_$iid/";
    my $r = tasty_get($url);
    if ($r->{tags}) {
        return [sort {lc($a->{tag}) cmp lc($b->{tag})} @{$r->{tags}}];
    } else {
        return [];
    }
}

sub user_tags {
    # return only the tags that the specified user has tagged the item with
    my $self = shift;
    my $username = shift;
    my $iid = $self->{iid};
    my $url = "item/item_$iid/user/user_$username/";
    my $r = tasty_get($url);
    if ($r->{tags}) {
        return [sort {lc($a->{tag}) cmp lc($b->{tag})} @{$r->{tags}}];
    } else {
        return [];
    }
}

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
c.username,u.fullname,c.comment,c.cid
FROM events e, users u, comments c
WHERE e.eid = c.event AND e.item = ? AND c.username = u.username
ORDER BY e.event_date_time ASC;},'Main');

sub history {
    my $self = shift;
    my $sth = $self->sql_history;
    $sth->execute($self->iid);
    return [map {
        $_->{comment} = $_->{comment} || "";
        $_;
    } @{$sth->fetchall_arrayref({})}];
}

__PACKAGE__->set_sql(comments => qq{
SELECT c.comment,date_trunc('second',c.add_date_time) as add_date_time,
       c.username, u.fullname, c.cid
FROM comments c, users u
WHERE c.item = ? AND c.username = u.username
ORDER BY c.add_date_time DESC;}, 'Main');

sub get_comments {
    my $self = shift;
    my $sth = $self->sql_comments;
    $sth->execute($self->iid);
    return [map {
        $_->{comment} = $_->{comment} || "";
        $_;
    } @{$sth->fetchall_arrayref({})}];
}

__PACKAGE__->set_sql(all_items => qq{
    SELECT i.iid 
    FROM items i order by i.iid DESC;},
                     'Main');

sub all_items {
    my $self = shift;
    my $sth = $self->sql_all_items;
    $sth->execute();
    my %results = ();
    return $sth->fetchall_arrayref({});
}

sub timed_out {
    die "TIMED OUT";
}

sub detiki_comments {
    my $self = shift;
    use Text::Tiki;
    use Data::Dumper;
    my $tiki = new Text::Tiki();

    my $sth = $self->sql_history;
    $sth->execute($self->iid);
    foreach my $comment (@{$sth->fetchall_arrayref({})}) {
	my $text = $comment->{comment} || "";
	if ($text =~ /^<p>/) {
	    # guessing that it's already converted
	    next;
	}

	$SIG{ALRM} = \&timed_out;
	eval {
	    alarm (10); # give it 10 seconds to complete. Text::Tiki likes to go into infinite loops on occasion.

	    $text =~ s/\(([^\)\(]+\@[^\)\(]+)\)/( $1 )/g; # workaround horrible bug in Text::Tiki
	    $text =~ s/(\w+)\+(\w+)\@/$1&plus;$2@/g; # workaround for second awful Text::Tiki bug
	    $text = $tiki->format($text);
	    $text =~ s{&lt;br /&gt;\s*}{\n}g;
	    $text =~ s{&lt;(/?)b&gt;}{<$1b>}g;
	    my $co = PMT::Comment->retrieve($comment->{cid});
	    $co->comment($text);
	    $co->update();
	    alarm(0);           # Cancel the pending alarm if conversion succeeds
	};
	if ($@ =~ /TIMED OUT/) {
	    print "Timed out. on comment ", $comment->{cid}, "\n";
	}
    }
}



sub data {
    my $self = shift;
    my $username = shift || "";

    my $data = $self->simple_data($username);

    $data->{priority_select} = $self->priority_select();
    $data->{status_select} = $self->status_select();
    $data->{assigned_to_select} = $self->assigned_to_select();
    $data->{milestone_select} = $self->milestone_select();

    return $data;
}

# more efficient version that doesn't do all the 
# extra queries to create select boxes
sub simple_data {
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
        notify               => $notify,
	assignee             => $username eq $self->assigned_to->username,
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
                  VERIFIED            => 'VERIFIED');

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
                   VERIFIED            => ['VERIFIED','OPEN']);
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

sub assigned_to_select {
    my $self = shift;
    my $project = $self->mid->pid;
    return $project->assigned_to_select($self->assigned_to);
}

sub milestone_select {
    my $self = shift;
    my $project = $self->mid->pid;
    return $project->milestone_select($self->mid);
}

sub close {
    # no-op now
    my $self = shift;
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
    if ($user->status eq "active") {
	my $n = PMT::Notify->find_or_create({iid => $self->iid,
					     username => $user->username});
    }
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

# sets up notification for an item
# owner, assigned_to
# are added by default (without duplication)
sub setup_default_notification {
    my $self = shift;
    $self->add_cc($self->owner);
    $self->add_cc($self->assigned_to);
}

# only called when item is first added
# adds all users who are on the project's cc list
# to the item's cc list

sub add_project_notification {
    my $self = shift;
    foreach my $n (PMT::NotifyProject->search(pid => $self->mid->pid->pid)) {
	$self->add_cc(PMT::User->retrieve($n->username));
    }
}

sub update_tags {
    my $self     = shift;
    my $r        = shift;
    my $username = shift || "";
    my @tags = @$r;
    # clear out old ones first
    $self->clear_tags($username);
    # put the new ones back in
    foreach my $t (@tags) {
        next if $t eq "";
        $self->add_tag($t,$username);
    }
}

sub clear_tags {
    my $self = shift;
    my $username = shift;
    my $iid = $self->{iid};

    my @unique_tags = ();
    my $tags = tasty_get("item/item_$iid/");
    my @tagusers = @{$tags->{tag_users}};
    my %mytags = ();
    my %otherstags = ();
    foreach my $o (@tagusers) {
        my $t = $o->[0]->{tag};
        my $u = $o->[1]->{user};
        if ($u eq "user_$username") {
            $mytags{$t} = 1;
        } elsif ($u =~ /^user_/) {
            $otherstags{$t} = 1;
        } else {
            # it's a project tag
        }
    }

    foreach my $t (keys %mytags) {
        if (!defined $otherstags{$t}) {
            push @unique_tags, $t;
        }
    }

    my $url = "item/item_$iid/user/user_$username/";
    tasty_delete($url);
    # delete an project associations if the project is the
    # only user left with that tag for the item

    $url = "item/item_$iid/";
    foreach my $t (@unique_tags) {
        tasty_delete($url . "tag/$t/");
    }
}

use URI::Escape;
sub add_tag {
    my $self = shift;
    my $tag = shift;
    $tag =~ s/[\r\n]+//g;
    $tag =~ s/^\s+//;
    $tag =~ s/\s+$//;
    $tag =~ s/\s+/ /g;
    return if $tag eq "";
    $tag = uri_escape($tag);
    my $username = shift;
    my $iid = $self->{iid};
    my $pid = $self->mid->pid->pid;
    my $url = "item/item_$iid/tag/$tag/user/user_$username/user/project_$pid/";
    tasty_put($url);
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
        if ($client ne "") {
            $self->add_to_clients({client_id => $client});
        }
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
    $data{description} =~ s/\(([^\)\(]+\@[^\)\(]+)\)/( $1 )/g; # workaround horrible bug in Text::Tiki
    $data{description} =~ s/(\w+)\+(\w+)\@/$1&plus;$2@/g; # workaround for second awful Text::Tiki bug
    $data{description_html} = $tiki->format($data{description});
    $data{$data{type}}         = 1;
    $data{tags}                = $item->tags();
    $data{can_resolve}         = ($data{status} eq 'OPEN' ||
                                  $data{status} eq 'INPROGRESS' ||
                                  $data{status} eq 'RESOLVED');
    $data{resolve_times}       = $item->resolve_times();
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
    if(exists $data{pub_view}) {
        $data{pub_view}            = $data{pub_view} == 1;
    } else {
        $data{pub_view} = 0;
    }

    $data{clients}        = $item->clients_data();
    $data{clients_select} = $item->clients_select();

    return \%data;
}


# emails relevant parties with info for an item
sub email {
    my $self    = shift;
    my $subject = shift;
    my $skip    = shift;

    my $owner       = $self->owner;
    my $owner_email = $owner->username . " (" . $owner->email . ")";
    my $email_subj = $self->email_subject($subject);
    my $body = $self->email_message_body();

    foreach my $user (@{$self->which_users_to_email($skip)}) {
	$self->send_email($body,$email_subj,$owner_email,$user->{'email'});
    }
}

__PACKAGE__->set_sql(users_to_email =>
                     qq{SELECT u.username,u.email
                            FROM notify n, users u
                            WHERE n.username = u.username
                            AND u.status = 'active' AND u.grp = 'f'
                            AND n.iid = ? AND u.username <> ?;},
                     'Main');

# when an item is added/updated, use this to get a list
# of users that need to be emailed
sub which_users_to_email {
    my $self = shift;
    my $skip = shift;
    my $sth = $self->sql_users_to_email;
    $sth->execute($self->iid,$skip);
    return $sth->fetchall_arrayref({});    
}

sub email_subject {
    my $self = shift;
    my $subject = shift;
    my $r = $self->full_data();
    my %item = %$r;

    my $project_title = &truncate_string($item{'project'});
    my $subject_title = &truncate_string($item{'title'});

    if ($subject =~ /^new/) {
        $subject_title = $subject_title . "(NEW)";
    }

    return "[PMT:$project_title] Attn:$item{'assigned_to_fullname'}-$subject_title";
}

sub email_message_body {
    my $self = shift;
    my $r = $self->full_data();
    my %item = %$r;
    $r = $item{tags};
    my @tags = map {$_->{tag};} @$r;
    my $tags = join ', ', @tags;

    return qq{
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
tags:\t$tags
description:
$item{'description'}

view $item{'type'}: http://$ENV{'SERVER_NAME'}/item/$item{'iid'}/

please do not reply to this message.
};

}

# do the actual sending of the mail
sub send_email {
    my $self    = shift;
    my $message = shift;
    my $subject = shift;
    my $from    = shift;
    my $to      = shift;

    $ENV{PATH} = "/usr/sbin";
    open(MAIL,"|/usr/sbin/sendmail -t");
    print MAIL <<END_MESSAGE;
To: $to
From: $from
Subject: $subject

$message;
END_MESSAGE
    CORE::close MAIL;
    print STDERR "sent email out";
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

$item{'type'} URL: http://$ENV{'SERVER_NAME'}/item/$item{'iid'}/

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
    my @show        = @{$args{show}};
    my $number      = $args{number};
    my $sortby      = $args{sortby};
    my $order       = $args{order};
    my $limit       = $args{limit};
    my $offset      = $args{offset};
    my $max_date    = $args{max_date};
    my $min_date    = $args{min_date};
    my $max_mod_date= $args{max_mod_date};
    my $min_mod_date= $args{min_mod_date};

    # ignore non iso8601 dates
    if($max_date !~ /\d{4}-\d{2}-\d{2}/) {
        $max_date = "";
    }

    if($min_date !~ /\d{4}-\d{2}-\d{2}/) {
        $min_date = "";
    }

    if($max_mod_date !~ /\d{4}-\d{2}-\d{2}/) {
        $max_mod_date = "";
    }

    if($min_mod_date !~ /\d{4}-\d{2}-\d{2}/) {
        $min_mod_date = "";
    }

    my $rows = 0;

    my %show = ();

    foreach my $s (@show) {
        $show{$s} = 1;
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

        if($max_mod_date ne "") {
            $query_string .= qq{ AND i.last_mod <= ? };
            push @args, $max_mod_date;
        }

        if($min_mod_date ne "") {
            $query_string .= qq{ AND i.last_mod >= ? };
            push @args, $min_mod_date;
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
                AND (
                      upper(i.title) LIKE upper(?)
                      OR upper(i.description) LIKE upper(?))
                };
            push @args, ($q,$q);
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
