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


# }}}

# pass in two hashrefs with the data for each item
sub compare_items {
    my $self = shift;
    my $item = shift;
    my $old = shift;
    my $project = shift;
    my $changed = 0;
    my $message = "";
    my $comment = "";

    # compare with new
    ($item,$old,$changed,$comment,$message)
        = $self->compare_assigned_to($item,$old,$changed,$comment,$message,$project);
    ($item,$old,$changed,$comment,$message)
        = $self->compare_owners($item,$old,$changed,$comment,$message,$project);
    ($item,$old,$changed,$comment,$message)
        = $self->compare_statuses($item,$old,$changed,$comment,$message,$project);
    ($changed,$comment,$message) = $self->compare_milestones($item,$old,$changed,$comment,$message);
    ($item,$old,$changed,$comment,$message)
        = $self->compare_fields($item,$old,$changed,$comment,$message,$project);

    ($changed,$comment,$message) = $self->compare_clients($item,$old,$changed,$comment,$message);

    ($item,$old,$changed,$comment,$message) = $self->check_assigned_to_active($item,$old,$project,$changed,$comment,$message);
    ($item,$old,$changed,$comment,$message) = $self->check_owner_active($item,$old,$project,$changed,$comment,$message);

    return ($item,$old,$changed,$message,$comment);
}

sub compare_assigned_to {
    my $self = shift;
    my $item = shift;
    my $old = shift;
    my $changed = shift;
    my $comment = shift;
    my $message = shift;
    my $project = shift;

    if ($old->{assigned_to} ne $item->{assigned_to}){
        $changed = 1;
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
    return ($item,$old,$changed,$comment,$message);
}

sub compare_owners {
    my $self = shift;
    my $item = shift;
    my $old = shift;
    my $changed = shift;
    my $comment = shift;
    my $message = shift;
    my $project = shift;

    if ($old->{owner} ne $item->{owner}) {
        $changed = 1;
        $comment .= "<b>changed ownership to " . $item->{owner} . "</b><br />\n";
        $message .= "changed ownership to " . $item->{owner} . ". ";

        my $old_owner = PMT::User->retrieve($old->{owner});
        my $new_owner = PMT::User->retrieve($item->{owner});

        if($old_owner->grp && !$new_owner->grp) {
            $project->add_user_from_group_to_project($item->{owner},$old->{owner});
        }
    }
    return ($item,$old,$changed,$comment,$message);
}

sub compare_statuses {
    my $self = shift;
    my $item = shift;
    my $old = shift;
    my $changed = shift;
    my $comment = shift;
    my $message = shift;
    my $project = shift;

    if ($old->{status} ne $item->{status}) {
        $changed = 1;
        if($item->{status} eq "OPEN" && $old->{status} eq "UNASSIGNED") {
            $comment .= "<b>assigned to " . $item->{assigned_to} . "</b><br />\n";
            $message .= "assigned to " . $item->{assigned_to} . ". ";
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
    return ($item,$old,$changed,$comment,$message);
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

    return ($item,$old,$changed,$comment,$message);
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

    # handle someday/maybe items

    if ($item->{status} eq "someday") {
        # change the milestone and reset the status
        $item->{mid} = $project->someday_maybe_milestone()->mid;
        $item->{status} = $i->status;
        $item->{r_status} = $i->r_status;
        $milestone = PMT::Milestone->retrieve($item->{mid});
    }


    # streamline the resolving of self-assigned items
    if(($item->{assigned_to} eq $old->{owner}) &&
       ($old->{owner} eq $username) &&
       ($item->{status} eq "RESOLVED")) {
        $item->{status} = "VERIFIED";
        $item->{r_status} = "";
    }

    # changed if any fields have been changed
    my $changed = 0;
    my $comment = "";
    my $message = "";

    ($item,$old,$changed,$message,$comment)
        = $self->compare_items($item,$old,$project);
    # update what needs it

    # just make sure the owner/assignee are on the cc list no matter what
    $i->setup_default_notification();

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
        $i->update_clients($item->{'clients'});
        $i->add_client_by_uni($item->{client_uni});
        # add history event
        $i->add_event($item->{'status'},"$comment " . $item->{comment},$user);
        my $new_milestone = PMT::Milestone->retrieve($item->{mid});
        $i->touch();
        $milestone->update_milestone($user);
        if($item->{mid} != $old->{mid}) {
            my $old_milestone = PMT::Milestone->retrieve($old->{mid});
            $old_milestone->update_milestone($user);
        }
        $i->update_email($item->{'type'} . " #" . $item->{'iid'} . " " . $item->{'title'} . " updated",
                         "$comment---------------\n" . dehtml($item->{'comment'}),$username);
    } elsif ($item->{'comment'} ne "") {
        # add comment if needed
        $i->add_comment($user,$item->{'comment'});
        if($changed == 0) {
            $i->update_email("comment added to " . $item->{'type'} . " #" . $item->{'iid'} . " " . $item->{'title'},
                             dehtml($item->{'comment'}),$username);
            $message .= "comment added. ";
        }
    }
    $i->touch();
    return $message;
}

# {{{ update_user

sub update_user {
    my $self      = shift;
    my $username  = untaint_username(shift);
    my $password  = shift || throw Error::NO_PASSWORD "no password specified in update_user()";
    my $new_pass  = shift;
    my $new_pass2 = shift;
    my $fullname  = escape(shift);
    my $email     = escape(shift);
    my $type      = shift;
    my $title	     = shift;
    my $phone	     = shift;
    my $bio	     = shift;
    my $campus       = shift;
    my $building     = shift;
    my $room         = shift;
    my $photo_url    = shift;
    my $photo_width  = shift || 0;
    my $photo_height = shift || 0;

    throw Error::NO_EMAIL "email address is necessary."
        unless $email;

    if ($new_pass eq "") { $new_pass = $password; $new_pass2 = $password; }

    if ($new_pass eq $new_pass2) {
        my $u = PMT::User->retrieve($username);
        $u->fullname($fullname);
        $u->email($email);
        $u->password($new_pass);
	$u->type($type);
	$u->title($title);
	$u->phone($phone);
	$u->bio($bio);
	$u->campus($campus);
	$u->building($building);
	$u->room($room);
	$u->photo_url($photo_url);
	$u->photo_width($photo_width);
	$u->photo_height($photo_height);
        $u->update();
    }
    return;
}

# }}}

sub error {
    my $self = shift;
    my $message = shift;
}

sub DESTROY {
    my $self = shift;
    # check if it's defined first to get rid of some
    # annoying warning messages.
}

1;
