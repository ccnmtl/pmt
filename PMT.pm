use lib qw(/home/httpd/html/lib /var/www/pmt/lib/ .);
use strict;
use CGI;
use PMT::Error;
use PMT::Config;
use PMT::User;
use PMT::Milestone;
use PMT::Item;
use PMT::Client;
use PMT::Document;
use PMT::Project;
use PMT::Group;
use PMT::Notify;
use PMT::NotifyProject;
use XML::Simple;
use HTML::Template;
use Text::Wrap;
use Text::Tiki;

package PMT;

# use PMT::Common inside the package so functions are exported to 
# the package namespace rather than to the global namespace.

use PMT::Common;


# {{{ global variables

my $cgi = CGI->new();

my @PROJECT_STATUSES = qw/Discovery Design Development
    Deployment Deferred Maintenance Complete/;


# }}}

# {{{ new

sub new {
    my $pkg = shift;

    # read in configuration info

    my $config = new PMT::Config();
    my $self = bless {}, $pkg;
    $self->{error_message} = "";
    $self->{verified} = 0;
    $self->{config} = $config;
    return $self;
}

# }}}

# {{{ add_item

sub add_item {
    my $self = shift;
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
    
    $item->update_keywords(@{$args{keywords}});
    $item->update_dependencies($args{dependencies});
    $item->add_clients(@{$args{clients}});

    # add notification (owner, assigned_to, @managers)
    $item->add_notification();

    $item->add_event($status,"<b>$args{'type'} added</b>",$user);
    $item->email("new $args{'type'}: $args{'title'}",$username);

    # the milestone may need to be reopened
    $milestone->update_milestone($user);
}

# }}}
# {{{ add_tracker 

sub add_tracker {
    my $self = shift;
    my %args = @_;

    my $milestone = PMT::Milestone->retrieve($args{mid});
    my $user = PMT::User->retrieve($args{owner});

    my $item = PMT::Item->create({
            type => 'action item', owner => $user, assigned_to => $user,
            title => escape($args{title}), mid => $milestone, status =>
            'VERIFIED', priority => 0, target_date => $args{'target_date'}, 
            estimated_time => $args{'time'}});
    my $iid = $item->iid;

    $item->add_clients(@{$args{clients}});
    $item->add_resolve_time($user,$args{time},$args{completed});
}

# }}}
# {{{ add_todo 

sub add_todo {
    my $self = shift;
    my %args = @_;

    my $milestone = PMT::Milestone->retrieve($args{mid});
    my $user = PMT::User->retrieve($args{owner});
    my $item = PMT::Item->create({
            type => 'action item', owner => $user, assigned_to => $user,
            title => escape($args{title}), mid => $milestone, status =>
            'OPEN', priority => 1, target_date => $args{'target_date'}, 
            estimated_time => '0h'});
    
    # add history event
    $item->add_event('OPEN',"<b>$args{'type'} added</b>",$user);

    # the milestone may need to be reopened
    $milestone->update_milestone($user);

}

# }}}

# pass in two hashrefs with the data for each item
sub compare_items {
    my $self = shift;
    my $item = shift;
    my $old = shift;
    my $project = shift;
    my $changed = 0;
    my $add_notification = 0;
    my $message = "";
    my $comment = "";

    # compare with new
    ($item,$old,$changed,$add_notification,$comment,$message) 
	= $self->compare_assigned_to($item,$old,$changed,$add_notification,$comment,$message,$project);
    ($item,$old,$changed,$add_notification,$comment,$message) 
	= $self->compare_owners($item,$old,$changed,$add_notification,$comment,$message,$project);
    ($item,$old,$changed,$add_notification,$comment,$message) 
	= $self->compare_statuses($item,$old,$changed,$add_notification,$comment,$message,$project);
    ($changed,$comment,$message) = $self->compare_milestones($item,$old,$changed,$comment,$message);
    ($item,$old,$changed,$add_notification,$comment,$message) 
	= $self->compare_fields($item,$old,$changed,$add_notification,$comment,$message,$project);

    ($changed,$comment,$message) = $self->compare_keywords($item,$old,$changed,$comment,$message);
    ($changed,$comment,$message) = $self->compare_dependencies($item,$old,$changed,$comment,$message);
    ($changed,$comment,$message) = $self->compare_clients($item,$old,$changed,$comment,$message);

    ($item,$old,$changed,$comment,$message) = $self->check_assigned_to_active($item,$old,$project,$changed,$comment,$message);
    ($item,$old,$changed,$comment,$message) = $self->check_owner_active($item,$old,$project,$changed,$comment,$message);

    return ($item,$old,$changed,$add_notification,$message,$comment);
}

sub compare_assigned_to {
    my $self = shift;
    my $item = shift;
    my $old = shift;
    my $changed = shift;
    my $add_notification = shift;
    my $comment = shift;
    my $message = shift;
    my $project = shift;

    if ($old->{assigned_to} ne $item->{assigned_to}){
	$changed = 1;
	$add_notification = 1;
	if($old->{status} eq "UNASSIGNED") {
	    $item->{status} = "OPEN";
	    $comment .= "<b>assigned to " . $item->{assigned_to} . "</b><br />\n";
	    $message .= "reassigned to " . $item->{assigned_to} . ". ";
	    $old->{status} = "OPEN"; # keep it from matching again later
	} else {
	    $comment .= "<b>reassigned to " . $item->{assigned_to} . "</b><br />\n";
	    $message = "reassigned to " . $item->{assigned_to} . ". ";
	}
	# if it's being reassigned from a group to a 
	# user in the group,
	# make sure that the person it's assigned to is
	# added to the project in the same capacity
	# that the group was.
	my $old_assigned_to = PMT::User->retrieve($old->{assigned_to});
	my $new_assigned_to = PMT::User->retrieve($item->{assigned_to});

	if($old_assigned_to->grp &&
	   !$new_assigned_to->grp) {
	    $project->add_user_from_group_to_project($item->{assigned_to},
                $old->{assigned_to});
	}
    }
    return ($item,$old,$changed,$add_notification,$comment,$message);
}

sub compare_owners {
    my $self = shift;
    my $item = shift;
    my $old = shift;
    my $changed = shift;
    my $add_notification = shift;
    my $comment = shift;
    my $message = shift;
    my $project = shift;

    if ($old->{owner} ne $item->{owner}) {
	$changed = 1;
	$add_notification = 1;
	$comment .= "<b>changed ownership to " . $item->{owner} . "</b><br />\n";
	$message .= "changed ownership to " . $item->{owner} . ". ";
	
	my $old_owner = PMT::User->retrieve($old->{owner});
	my $new_owner = PMT::User->retrieve($item->{owner});

	if($old_owner->grp && !$new_owner->grp) {
	    $project->add_user_from_group_to_project($item->{owner},$old->{owner});
	}
    }
    return ($item,$old,$changed,$add_notification,$comment,$message);
}

sub compare_statuses {
    my $self = shift;
    my $item = shift;
    my $old = shift;
    my $changed = shift;
    my $add_notification = shift;
    my $comment = shift;
    my $message = shift;
    my $project = shift;

    if ($old->{status} ne $item->{status}) {
	$changed = 1;
	if($item->{status} eq "OPEN" && $old->{status} eq "UNASSIGNED") {
	    $comment .= "<b>assigned to " . $item->{assigned_to} . "</b><br />\n";
	    $message .= "assigned to " . $item->{assigned_to} . ". ";
	    $add_notification = 1;
	} elsif ($item->{status} eq "OPEN" && $old->{status} ne "OPEN") {
	    $comment .= "<b>reopened</b><br />\n";
	    $message .= "reopened. ";
	} elsif ($item->{status} eq "RESOLVED" && $old->{status} ne "RESOLVED") {
	    $comment .= "<b>resolved " . $item->{r_status} . "</b><br />\n";
	    $message .= "resolved " . $item->{r_status} . ". ";
	    $old->{r_status} = $item->{r_status}; # prevent it from re-matching later
	} elsif ($item->{status} eq "VERIFIED" && $old->{status} ne "VERIFIED") {
	    $comment .= "<b>verified</b><br />\n";
	    $message .= "verified. ";
	} elsif ($item->{status} eq "CLOSED" && $old->{status} ne "CLOSED") {
	    $comment .= "<b>closed</b><br />\n";
	    $message .= "closed. ";
	} elsif ($item->{status} eq "INPROGRESS" && $old->{status} ne "INPROGRESS") {
	    $comment .= "<b>marked in progress</b><br />\n";
	    $message .= "marked in progress.  ";
	} else {
	    throw Error::INVALID_STATUS "invalid status";
	}
	if($old->{status} eq "RESOLVED" && $item->{status} ne "RESOLVED") {
	    $old->{r_status} = ""; # prevent double matching
	}
    }
    return ($item,$old,$changed,$add_notification,$comment,$message);
}

sub compare_milestones {
    my $self = shift;
    my $item = shift;
    my $old = shift;
    my $changed = shift;
    my $comment = shift;
    my $message = shift;

    if ($item->{mid} ne $old->{mid}) {
	$changed = 1;
	$comment .= "<b>changed milestone</b><br />\n";
	$message .= "changed milestone. ";
    }

    return ($changed,$comment,$message);
}

sub compare_fields {
    my $self = shift;
    my $item = shift;
    my $old = shift;
    my $changed = shift;
    my $add_notification = shift;
    my $comment = shift;
    my $message = shift;
    my $project = shift;

    # normalize time representation
    if($old->{estimated_time} =~ /^\d+$/) {
	$old->{estimated_time} .= "h";
    }

    foreach my $field 
	(qw/title description r_status url target_date type estimated_time/) 
    {
	$item->{$field} ||= "";
	$old->{$field} ||= "";
	if($item->{$field} ne $old->{$field}) { 
	    $changed = 1;
	    $comment .= "<b>$field updated</b><br />\n";
	    $message .= "$field updated. ";
	}
    }
    $item->{priority} ||= 0;
    $old->{priority} ||= 0;
    if($item->{priority} != $old->{priority}) {
	$changed = 1;
	$comment .= "<b>priority changed</b><br />\n";
	$message .= "priority changed. ";
    }

    return ($item,$old,$changed,$add_notification,$comment,$message);
}

sub compare_keywords {
    my $self = shift;
    my $item = shift;
    my $old = shift;
    my $changed = shift;
    my $comment = shift;
    my $message = shift;
    if (diff($item->{keywords},[map {$$_{keyword}} @{$old->{keywords}}])) {
	$changed = 1;
	$comment .= "<b>keywords changed</b><br />\n";
	$message .= "keywords changed. ";
    }
    return ($changed,$comment,$message);
}
sub compare_dependencies {
    my $self = shift;
    my $item = shift;
    my $old = shift;
    my $changed = shift;
    my $comment = shift;
    my $message = shift;
    if (diff($item->{dependencies},[map {$$_{iid}} @{$old->{dependencies}}])) {
	$changed = 1;
	$comment .= "<b>dependencies changed</b><br />\n";
	$message .= "dependencies changed. ";
    }
    return ($changed,$comment,$message);
}
sub compare_clients {
    my $self = shift;
    my $item = shift;
    my $old = shift;
    my $changed = shift;
    my $comment = shift;
    my $message = shift;
    if (diff($item->{clients}, [map {$_->{client_id}} @{$old->{clients}}]) || $item->{client_uni} ne "") {
	$changed = 1;
	$comment .= "<b>clients changed</b><br />\n";
	$message .= "clients changed. ";
    }
    return ($changed,$comment,$message);
}

sub check_assigned_to_active {
    my $self = shift;
    my $item = shift;
    my $old = shift;
    my $project = shift;
    my $changed = shift;
    my $comment = shift;
    my $message = shift;
    my $assigned_to = PMT::User->retrieve($item->{assigned_to});

    if ($assigned_to->status ne "active") {
	# the assigned user is inactive, so 
	# we need to reassign to the caretaker
	$changed = 1;
	my $old_user = $item->{'assigned_to'};
	$item->{'assigned_to'} = $project->caretaker;
	$comment .= "<b>reassigned to caretaker ($old_user is inactive)</b><br />\n";
	$message .= "reassigned to caretaker ($old_user is inactive). ";
    }
    return ($item,$old,$changed,$comment,$message);
}

sub check_owner_active {
    my $self = shift;
    my $item = shift;
    my $old = shift;
    my $project = shift;
    my $changed = shift;
    my $comment = shift;
    my $message = shift;
    my $owner = PMT::User->retrieve($item->{owner});

    if ($owner->status ne "active") {
	$changed = 1;
	my $old_user = $item->{'owner'};
	$item->{'owner'} = $project->caretaker;
	$comment .= "<b>changed ownership to caretaker ($old_user is inactive)</b><br />\n";
	$message .= "changed ownership to caretaker ($old_user is inactive). ";
    }
    return ($item,$old,$changed,$comment,$message);
}

# {{{ update_item

sub update_item {
    my $self     = shift;
    my $item     = shift;
    my $username = untaint_username(shift);

    # get old item info

    my $i  = PMT::Item->retrieve($item->{iid});
    my $old = $i->full_data();
    my $milestone = PMT::Milestone->retrieve($item->{mid});
    my $project = $milestone->pid;
    my $user = PMT::User->retrieve($username);


    # streamline the resolving of self-assigned items
    if(($item->{assigned_to} eq $old->{owner}) &&
       ($old->{owner} eq $username) && 
       ($item->{status} eq "RESOLVED")) {
	$item->{status} = "VERIFIED";
	$item->{r_status} = "";
    } 

    # changed if any fields have been changed
    my $changed = 0;
    # changed if (re)assigned and we may need to add someone 
    # to the notification list
    my $add_notification = 0;
    my $comment = "";
    my $message = "";

    ($item,$old,$changed,$add_notification,$message,$comment) 
	= $self->compare_items($item,$old,$project);
    # update what needs it

    if($add_notification) {
        my $ass_to = $i->assigned_to;
	$i->add_cc($ass_to);
    }
    if($item->{'resolve_time'} ne "") {
	$i->add_resolve_time($user,$item->{'resolve_time'});
    }

    if($changed != 0) {
	$i->title($item->{title});
	$i->description($item->{description});
	$i->priority($item->{priority});
	$i->r_status($item->{r_status});
	$i->url($item->{url});
	$i->target_date($item->{target_date});
	$i->type($item->{type});
	$i->assigned_to(PMT::User->retrieve($item->{assigned_to}));
	$i->owner(PMT::User->retrieve($item->{owner}));
	$i->status($item->{status});
	$i->mid($milestone);
	$i->estimated_time($item->{estimated_time});
	$i->update_keywords($item->{'keywords'});
	$i->update_dependencies($item->{'dependencies'});
	$i->update_clients($item->{'clients'});
	$i->add_client_by_uni($item->{client_uni});
	# add history event				 
	$i->add_event($item->{'status'},"$comment " . $item->{comment},$user);
	my $new_milestone = PMT::Milestone->retrieve($item->{mid});
	$milestone->update_milestone($user);
	if($item->{mid} != $old->{mid}) {
	    my $old_milestone = PMT::Milestone->retrieve($old->{mid});
	    $old_milestone->update_milestone($user);
	}
	$i->update_email($item->{'type'} . " #" . $item->{'iid'} . " " . $item->{'title'} . " updated",
			 "$comment---------------\n" . $item->{'comment'},$username);
    } elsif ($item->{'comment'} ne "") {
	# add comment if needed
	$i->add_comment($user,$item->{'comment'});
	if($changed == 0) {
	    $i->update_email("comment added to " . $item->{'type'} . " #" . $item->{'iid'} . " " . $item->{'title'},
			     $item->{'comment'},$username);
	    $message .= "comment added. ";
	}
    } 
    $i->update();
    return $message;
}

sub weekly_summary {
    my $self = shift;
    my $week_start = shift;
    my $week_end = shift;
    my $groups = shift;
    my @GROUPS = @{$groups};
    my @group_names = map {$_->{group}} @GROUPS;
    my $projects = PMT::Project->projects_active_during($week_start,$week_end,\@group_names);
    my $grand_total = interval_to_hours(PMT::ActualTime->interval_total_time($week_start,$week_end));

    foreach my $p (@$projects) {
	my $project = PMT::Project->retrieve($p->{pid});
        $p->{group_times} = [map {{time =>
                interval_to_hours($project->group_hours($_->{group},$week_start,$week_end))
                || '-'};} @{$groups}];
	$p->{total_time} = interval_to_hours($project->interval_total($week_start,$week_end));
    }

    my %data = (
		total_time => $grand_total,
		project_times => $projects,
		);
    $data{group_totals} = [map {
	my $gu = PMT::User->retrieve($_->{group});
	{
	    time => interval_to_hours($gu->total_group_time($week_start,$week_end)) || "-"
	    };
    } @{$groups}];

    return \%data;

}

sub staff_report {
    my $self = shift;
    my $start = shift;
    my $end = shift;
    my @GROUPS = qw/programmers video webmasters educationaltechnologists management/;
    my @group_reports = ();

    foreach my $grp (@GROUPS) {
	my $group_user = PMT::User->retrieve("grp_$grp");
	my %data = (group => $grp,
		    total_time => interval_to_hours($group_user->total_group_time($start,$end)),
		    );
        my $g = PMT::User->retrieve("grp_$grp");
        my @users = ();
	foreach my $u (map {$_->data()} $g->users_in_group()) {
	    my $user = PMT::User->retrieve($u->{username});
	    $u->{user_time} = interval_to_hours($user->interval_time($start,$end)) || 0;
            push @users, $u;
	}
	$data{user_times} = \@users;
	push @group_reports, \%data;
    }

    return {groups => \@group_reports};
}

# }}}
# {{{ edit_project

sub edit_project {
    my $self        = shift;
    my %args = @_;
    my $pid         = $args{pid};
    my $name        = escape($args{name}) 
	|| throw Error::NO_NAME "no name specified in edit_project()";
    my $description = escape($args{description});
    my $caretaker   = untaint_username($args{caretaker});
    my $mr          = $args{managers};
    my $dr          = $args{developers};
    my $gr          = $args{guests};
    my $cr          = $args{clients};
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

    my $project = PMT::Project->retrieve($pid);
    $project->name($name);
    $project->description($description);
    $project->caretaker(PMT::User->retrieve($caretaker));
    $project->pub_view($pub_view);
    $project->status($status);
    $project->projnum($projnum);
    $project->area($area);
    $project->url($url);
    $project->restricted($restricted);
    $project->approach($approach);
    $project->info_url($info_url);
    $project->entry_rel($entry_rel);
    $project->eval_url($eval_url);
    $project->scale($scale);
    $project->distrib($distrib);
    $project->type($type);
    $project->poster($poster);
    
    # clear users
    $project->works_on()->delete_all();
    my $got_caretaker = 0;
    # put them back in

    # since people are bad about accidently selecting the same
    # person as both a manager and a developer, we want things
    # to fail gracefully if they do that. ie, we'll silently
    # just not add them as the lower form. 
    
    my %seen;

    foreach my $manager (@$mr) {
	next if $manager eq "-1";
	next if $manager eq "";
	next if $seen{$manager};
	my $w = PMT::WorksOn->create({username => $manager,
				      pid => $project->pid, auth => 'manager'});
	$seen{$manager} = 1;
	$got_caretaker = 1 if $manager eq $caretaker;
    }
    # make sure that at least the caretaker is a manager.
    if(!$got_caretaker) {
	my $w = PMT::WorksOn->create({username => $caretaker,
				      pid => $project->pid, auth => 'manager'});
	$seen{$caretaker} = 1;
    }
    foreach my $developer (@$dr) {
	next if $developer eq "";
	next if $developer eq "-1";
	next if $seen{$developer};
	my $w = PMT::WorksOn->create({username => $developer,
				      pid => $project->pid, auth => 'developer'});
	$seen{$developer} = 1;
    }
    foreach my $guest (@$gr) {
	next if $guest eq "";
	next if $guest eq "-1";
	next if $seen{$guest};
	my $w = PMT::WorksOn->create({username => $guest,
				      pid => $project->pid, auth => 'guest'});
	$seen{$guest} = 1;
    }

    $project->clients()->delete_all;
    foreach my $client (@$cr) {
	next if $client eq "";
	my $p = PMT::ProjectClient->create({pid => $project->pid, client_id => $client});
    }
    $project->update();

}

# }}}
# {{{ update_user

sub update_user {
    my $self      = shift;
    my $username  = untaint_username(shift);
    my $password  = shift || throw Error::NO_PASSWORD "no password specified in update_user()";
    my $new_pass  = shift;
    my $new_pass2 = shift;
    my $fullname  = escape(shift);
    my $email     = escape(shift);

    throw Error::NO_EMAIL "email address is necessary." 
	unless $email;
    
    if ($new_pass eq "") { $new_pass = $password; $new_pass2 = $password; }

    if ($new_pass eq $new_pass2) {
	my $u = PMT::User->retrieve($username);
	$u->fullname($fullname);
	$u->email($email);
	$u->password($new_pass);
	$u->update();
    } 
    return;
}

# }}}
# {{{ group stuff

# {{{ add_group

# adds a group. returns normalized group name.
sub add_group {
    my $self = shift;
    my $group_name = shift;
    my $normalized = $group_name;

    $normalized =~ s/\W//g;
    $normalized = "grp_$normalized";
    $group_name = "$group_name (group)";
    my $email = 'nobody@localhost';
    my $password = 'nopassword';

    my $u = PMT::User->create({username => $normalized, fullname => $group_name, email => $email, 
			       password => $password});
    $u->grp('t');
    $u->update();
    return $normalized;
}

# }}}

# {{{ group

sub group {
    my $self = shift;
    my $group = untaint_username(shift);
    my $gu = PMT::User->retrieve($group);
    my $data = $gu->user_info();
    $data->{group} = $group;
    $data->{group_name} = $data->{user_fullname};
    $data->{group_select_list} = $self->group_users_select_list($group);
    $data->{users} = [map {$_->data()} $gu->users_in_group()];
    $data->{group_nice_name} = $data->{group_name};
    $data->{group_nice_name} =~ s/\s+\(group\)\s*$//g;
    return $data;
}

# }}}

# {{{ group_users_select_list

# creates a datastructure that can be used to
# create a select list of users for a group.
# lists every active user with
#   value => their username
#   label => their fullname
#   selected => whether or not they are part of the group
sub group_users_select_list {
    my $self = shift;
    my $group = untaint_username(shift);
    
    my $g = PMT::User->retrieve($group);
    my %in_group;
    foreach my $u ($g->users_in_group()) {
	$in_group{$u->username} = 1;
    }
    return [grep {$_->{value} ne $group}
	    map {my %t = (value => $_->username,
			  label => $_->fullname,
			  selected => exists $in_group{$_->username});
		 \%t;
	     } PMT::User->all_active()];
}

# }}}


# {{{ update_group

sub update_group {
    my $self = shift;
    my $group = untaint_username(shift);
    my $users = shift;

    my @u = PMT::Group->search({grp => $group});
    foreach my $u (@u) {$u->delete()}
    
    foreach my $u (@$users) {
	my $g = PMT::Group->create({grp => $group, username => $u});
    }

}

# }}}

# }}}
# {{{ redirect_with_cookie

sub redirect_with_cookie {
    my $self     = shift;
    my $url      = shift || throw Error::NO_URL "no url specified in redirect_with_cookie()";
    my $username = shift || "";
    my $password = shift || "";

    my $lcookie = $cgi->cookie(-name => 'pmtusername',
			       -value => $username,
			       -path => '/',
			       -expires => '+10y');
    my $pcookie = $cgi->cookie(-name => 'pmtpassword',
			       -value => $password,
			       -path => '/',
			       -expires => '+10y');
    if($url ne "") {
	print $cgi->redirect(-location => $url, 
			     -cookie => [$lcookie,$pcookie]);
    } else {
	print $cgi->header(-cookie => [$lcookie,$pcookie]);
    }
}

# }}}

# {{{ clean_username

# removes whitespace and lowercases
sub clean_username {
    my $self = shift;
    my $text = shift || return "";
    $text =~ s/\W//g;
    $text =~ tr/A-Z/a-z/;
    return $text;
}

# }}}


# {{{ --- logging functions

sub debug {
    my $self = shift;
    my $message = shift;
}
sub error {
    my $self = shift;
    my $message = shift;
}
sub warn {
    my $self = shift;
    my $message = shift;
}
sub info {
    my $self = shift;
    my $message = shift;
}

# }}}

# {{{ fatal
# called when we can't figure out what else to do

sub fatal {
    my $self = shift;
    my $message = shift || "";
    print "content-type: text/html\n\n";
    print "<h1>error:</h1><p>$message</p>";
    $self->error($message);
}

# }}}

sub DESTROY {
    my $self = shift;
    # check if it's defined first to get rid of some
    # annoying warning messages.
}

1;
