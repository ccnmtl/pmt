use lib qw(/home/httpd/html/lib /var/www/pmt/lib/ .);
use strict;
use CGI;
use PMT::DB;
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


@PMT::ISA = qw(Util);

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
    $self->{db} = new PMT::DB();
    $self->{error_message} = "";
    $self->{verified} = 0;
    $self->{config} = $config;
    $self->debug("{{{ new()");
    return $self;
}

# }}}

# {{{ add_item

sub add_item {
    my $self = shift;
    my $args = shift || throw Error::NO_ARGUMENTS "no arguments given to add_item()";
    $self->debug("add_item( ... )");
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
        $self->update("INSERT INTO works_on (username,pid,auth) 
            values (?,?,'guest');",
            [$username,$project->pid]);
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
    
    # add keywords
    my @keywords = @{$args{'keywords'}};

    foreach my $keyword (@keywords) {
        $item->add_to_keywords({keyword => $keyword});
    }
    # add dependencies
    
    foreach my $dep (@{$args{'dependencies'}}) {
        my $dependent = PMT::Item->retrieve($dep);
        my $dependency = $item->add_to_dependencies({dest =>
                $dep});
	$dependent->prioritize_dependent($args{priority},$args{target_date});
    }
    
    foreach my $client (@{$args{'clients'}}) {
        my $c = PMT::Client->retrieve($client);
        my $ci = PMT::ItemClients->create({iid => $item->iid, client_id =>
                $c->client_id});
    }

    # add notification (owner, assigned_to, @managers)
    $item->add_notification();

    #Min's changes to implement email notification opt in/out
#    if($username ne $args{'owner'}) {
#	$item->add_cc($user);
#    }

    # add history event
    $item->add_event($status,"<b>$args{'type'} added</b>",$user);
    # email people
    $self->email($item->iid,"new $args{'type'}: $args{'title'}",$username);

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

    foreach my $client (@{$args{'clients'}}) {
        my $c = PMT::Client->retrieve($client);
        my $itemclient = PMT::ItemClients->create({iid => $item->iid, client_id
                => $c->client_id});
    }
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


# {{{ update_item

sub update_item {
    my $self     = shift;
    my $itm     = shift;
    my $username = untaint_username(shift);
    $self->debug("update_item([item],$username)");
    my %item     = %$itm;
    # changed if any fields have been changed
    my $changed = 0;
    # changed if (re)assigned and we may need to add someone 
    # to the notification list
    my $add_notification = 0;
    my $email = 0;
    my $comment = "";
    # get old item info
    print STDERR $item{iid};
    my $i  = PMT::Item->retrieve($item{iid});
    my $o = $i->full_data();
    my $milestone = PMT::Milestone->retrieve($item{mid});
    my $project = $milestone->pid;
    my $user = PMT::User->retrieve($username);
    my %old = %$o;
    my $message = "";

    # streamline the resolving of self-assigned items
    if(($item{assigned_to} eq $old{owner}) &&
       ($old{owner} eq $username) && 
       ($item{status} eq "RESOLVED")) {
	$item{status} = "VERIFIED";
	$item{r_status} = "";
	$self->debug("streamlined resolve");
    } 
    # compare with new
    if ($old{assigned_to} ne $item{assigned_to}){
	$self->debug("reassigned item to $item{assigned_to}");
	$changed = 1;
	$add_notification = 1;
	if($old{status} eq "UNASSIGNED") {
	    $item{status} = "OPEN";
	    $comment .= "<b>assigned to $item{assigned_to}</b><br />\n";
	    $message .= "reassigned to $item{assigned_to}. ";
	    $old{status} = "OPEN"; # keep it from matching again later
	} else {
	    $comment .= "<b>reassigned to $item{assigned_to}</b><br />\n";
	    $message = "reassigned to $item{assigned_to}. ";
	}
	# if it's being reassigned from a group to a 
	# user in the group,
	# make sure that the person it's assigned to is
	# added to the project in the same capacity
	# that the group was.
	my $old_assigned_to = PMT::User->retrieve($old{assigned_to});
	my $new_assigned_to = PMT::User->retrieve($item{assigned_to});

	if($old_assigned_to->grp &&
	   !$new_assigned_to->grp) {
	    $project->add_user_from_group_to_project($item{assigned_to},
                $old{assigned_to});
	}
    }

    if ($old{owner} ne $item{owner}) {
	$self->debug("changed owner to $item{owner}");
	$changed = 1;
	$add_notification = 1;
	$comment .= "<b>changed ownership to $item{owner}</b><br />\n";
	$message .= "changed ownership to $item{owner}. ";
	
	my $old_owner = PMT::User->retrieve($old{owner});
	my $new_owner = PMT::User->retrieve($item{owner});

	if($old_owner->grp && !$new_owner->grp) {
	    $project->add_user_from_group_to_project($item{owner},
                $old{owner});
	}
    }

    if ($old{status} ne $item{status}) {
	$self->debug("changed status to $item{status}");
	$changed = 1;
	if($item{status} eq "OPEN" && $old{status} eq "UNASSIGNED") {
	    $comment .= "<b>assigned to $item{assigned_to}</b><br />\n";
	    $message .= "assigned to $item{assigned_to}. ";
	    $add_notification = 1;
	} elsif ($item{status} eq "OPEN" && $old{status} ne "OPEN") {
	    $comment .= "<b>reopened</b><br />\n";
	    $message .= "reopened. ";
	} elsif ($item{status} eq "RESOLVED" && $old{status} ne "RESOLVED") {
	    throw Error::UNRESOLVED_DEPENDENCIES "dependencies not resolved" 
		if $i->check_dependencies();
	    $comment .= "<b>resolved $item{r_status}</b><br />\n";
	    $message .= "resolved $item{r_status}. ";
	    $old{r_status} = $item{r_status}; # prevent it from re-matching later
	} elsif ($item{status} eq "VERIFIED" && $old{status} ne "VERIFIED") {
	    $comment .= "<b>verified</b><br />\n";
	    $message .= "verified. ";
	} elsif ($item{status} eq "CLOSED" && $old{status} ne "CLOSED") {
	    $comment .= "<b>closed</b><br />\n";
	    $message .= "closed. ";
	} elsif ($item{status} eq "INPROGRESS" && $old{status} ne "INPROGRESS") {
	    $comment .= "<b>marked in progress</b><br />\n";
	    $message .= "marked in progress.  ";
	} else {
	    throw Error::INVALID_STATUS "invalid status";
	}
	if($old{status} eq "RESOLVED" && $item{status} ne "RESOLVED") {
	    $old{r_status} = ""; # prevent double matching
	}
    }

    if ($item{mid} ne $old{mid}) {
	$self->debug("moved to different milestone");
	$changed = 1;
	$comment .= "<b>changed milestone</b><br />\n";
	$message .= "changed milestone. ";
    }

    # normalize time representation
    if($old{estimated_time} =~ /^\d+$/) {
	$old{estimated_time} .= "h";
    }

    foreach my $field 
	(qw/title description r_status url target_date type estimated_time/) 
    {
	$item{$field} ||= "";
	$old{$field} ||= "";
	if($item{$field} ne $old{$field}) { 
	    $self->debug("changed $field");
	    $changed = 1;
	    $comment .= "<b>$field updated</b><br />\n";
	    $message .= "$field updated. ";
	}
    }
    $item{priority} ||= 0;
    $old{priority} ||= 0;
    if($item{priority} != $old{priority}) {
	$changed = 1;
	$comment .= "<b>priority changed</b><br />\n";
	$message .= "priority changed. ";
    }

    if ($self->diff($item{keywords},[map {$$_{keyword}} @{$old{keywords}}])) {
	$changed = 1;
	$comment .= "<b>keywords changed</b><br />\n";
	$message .= "keywords changed. ";
    }

    if ($self->diff($item{dependencies},[map {$$_{iid}} @{$old{dependencies}}])) {
	$changed = 1;
	$comment .= "<b>dependencies changed</b><br />\n";
	$message .= "dependencies changed. ";
    }

    if ($self->diff($item{clients}, [map {$_->{client_id}} @{$old{clients}}]) || $item{client_uni} ne "") {
	$changed = 1;
	$comment .= "<b>clients changed</b><br />\n";
	$message .= "clients changed. ";
    }

    my $assigned_to = PMT::User->retrieve($item{'assigned_to'});
    if ($assigned_to->status ne "active") {
	# the assigned user is inactive, so 
	# we need to reassign to the caretaker
	$changed = 1;
	my $old_user = $item{'assigned_to'};
	$item{'assigned_to'} = $project->caretaker;
	$comment .= "<b>reassigned to caretaker ($old_user is inactive)</b><br />\n";
	$message .= "reassigned to caretaker ($old_user is inactive). ";
    }

    my $owner = PMT::User->retrieve($item{'owner'});
    if ($owner->status ne "active") {
	$changed = 1;
	my $old_user = $item{'owner'};
	$item{'owner'} = $project->caretaker;
	$comment .= "<b>changed ownership to caretaker ($old_user is inactive)</b><br />\n";
	$message .= "changed ownership to caretaker ($old_user is inactive). ";
    }

    # update what needs it

    my $query = <<SQL;
UPDATE items 
SET title = ?, description = ?, priority = ?, r_status = ?, 
url = ?, target_date = ?, type = ?, assigned_to = ?, owner = ?, status = ?,
last_mod = CURRENT_TIMESTAMP, mid = ?, estimated_time = ?
    WHERE iid = ?;
SQL
    if($add_notification) {
        my $ass_to = PMT::User->retrieve($i->{assigned_to});
	$i->add_cc($ass_to);
    }
    if($item{'resolve_time'} ne "") {
	$i->add_resolve_time($user,$item{'resolve_time'});
    }

    if($changed != 0) {
	$self->update($query,
		      [$item{'title'},escape($item{'description'}),
		       $item{'priority'},$item{'r_status'},
		       $item{'url'},$item{'target_date'},
		       $item{'type'},$item{'assigned_to'},
		       $item{'owner'},
		       $item{'status'},$item{'mid'},
		       $item{'estimated_time'},$item{'iid'}]);
	$i->update_keywords($item{'keywords'});
	$i->update_dependencies($item{'dependencies'});
	$i->update_clients($item{'clients'});
	$i->add_client_by_uni($item{client_uni});
	# add history event				 
	$i->add_event($item{'status'},"$comment $item{comment}",$user);
	my $new_milestone = PMT::Milestone->retrieve($item{mid});
	$milestone->update_milestone($user);
	if($item{mid} != $old{mid}) {
	    my $old_milestone = PMT::Milestone->retrieve($old{mid});
	    $old_milestone->update_milestone($user);
	}
	$self->update_email($item{'iid'},"$item{'type'} #$item{'iid'} $item{'title'} updated","$comment---------------\n$item{'comment'}",$username);
    } elsif ($item{'comment'} ne "") {
	# add comment if needed
	$i->add_comment($user,$item{'comment'});
	if($changed == 0) {
	    $self->update_email($item{'iid'},"comment added to $item{'type'} #$item{'iid'} $item{'title'}","$item{'comment'}",$username);
	    $message .= "comment added. ";
	}
    } else {
	$self->debug("no changes were made to the item");
	# no changes were made to the item and no comment was added
    }
    $self->debug("done with update_item()");
    return $message;
}

# }}}
# {{{ subs for comparing complex data structures
# {{{ diff

# drivers to ld and lists_diff

sub diff {
    my $self = shift;
    my $r1 = shift;
    my $r2 = shift;
    # ld expects references to lists
    if ("ARRAY" eq ref $r1 && "ARRAY" eq ref $r2) {
	return $self->ld("","",$r1,$r2,0,1);
    } else {
	# if they're not references to lists, we just make them
	return $self->ld("","",[$r1],[$r2],0,1);
    }
}

# }}}
# {{{ diff_order

# same as diff but not order agnostic
# ['foo','bar'] != ['bar','foo']
sub diff_order {
    my $self = shift;
    my $r1 = shift;
    my $r2 = shift;
    # ld expects references to lists
    if ("ARRAY" eq ref $r1 && "ARRAY" eq ref $r2) {
	return $self->ld("","",$r1,$r2,0,0);
    } else {
	# if they're not references to arrays, we just make them
	return $self->ld("","",[$r1],[$r2],0,0);
    }
}   

# }}}
# {{{ ld

# recursively compares two lists by value
# works for damn near any reasonably complex structure
# including: lists of scalars, lists of lists, lists of hashes, 
# lists of hashes of lists of arrays of scalars, etc, etc.
# arguably should be called data_structures_diff
# argument $order == 1 means that we don't care about the order
# ie ['foo','bar'] == ['bar','foo']

sub ld {
    my $self   = shift;
    my $x      = shift;       # first element of first list
    my $y      = shift;       # first element of second list
    my $r1     = shift;       # reference to rest of first list
    my $r2     = shift;       # reference to rest of second list
    my $sorted = shift;       # whether or not the lists have been sorted
    my $order  = shift;       # whether we're order agnostic with lists

    my $DIFFERENT = 1;
    my $SAME      = 0;

    my @xs = @$r1;
    my @ys = @$r2;

    if(!$sorted && $order) {
	@xs = sort @xs;
	@ys = sort @ys;
	$sorted = 1;
    }

    if ($#xs != $#ys) {
	# lists are different lengths, so we know right off that
	# they must not be the same.
	return $DIFFERENT;
    } else {

	# lists are the same length, so we compare $x and $y
	# based on what they are
	if (!ref $x) {

	    # make sure $y isn't a reference either
	    return $DIFFERENT if ref $y;

	    # both scalars, compare them
	    return $DIFFERENT if $x ne $y;
	} else {

	    # we're dealing with references now
	    if (ref $x ne ref $y) {

		# they're entirely different data types
		return $DIFFERENT;
	    } elsif ("SCALAR" eq ref $x) {

		# some values that we can actually compare
		return $DIFFERENT if $$x ne $$y;
	    } elsif ("REF" eq ref $x) {

		# yes, we even handle references to references to references...
		return $DIFFERENT if $self->ld($$x,$$y,[],[],0,$order);
	    } elsif ("HASH" eq ref $x) {

		# references to hashes are a little tricky
		# we make arrays of keys and values (keeping
		# the values in order relative to the keys)
		# and compare those.
		my @kx = sort keys %$x;
		my @ky = sort keys %$y;
		my @vx = map {$$x{$_}} @kx;
		my @vy = map {$$y{$_}} @ky;
		return $DIFFERENT
		    if $self->ld("", "", \@kx,\@ky,1,$order) || 
			$self->ld("", "", \@vx,\@vy,1,$order);
	    } elsif ("ARRAY" eq ref $x) {
		return $DIFFERENT if $self->ld("","",$x,$y,0,$order);
	    } else {
		# don't know how to compare anything else
		throw Error::UNKNOWN_TYPE "sorry, can't compare type " . ref $x;
	    }
	}
	if (-1 == $#xs) {

	    # no elements left in list, this is the base case.
	    return $SAME;
	} else {
	    return $self->ld(shift @xs,shift @ys,\@xs,\@ys,$sorted,$order);
	}

    }
}

# }}}
# {{{ lists_diff

# recursively compares two lists
# works for damn near any reasonably complex structure
# lists of scalars, lists of lists, lists of hashes, 
# lists of hashes of lists of arrays of scalars, etc, etc.
# doesn't take order into account.

sub lists_diff {
    my $self = shift;
    my $r1 = shift;
    my $r2 = shift;
    my $DIFFERENT = 1;
    my $SAME = 0;

    # sort things so order isn't taken into account.
    my @l1 = sort @$r1;
    my @l2 = sort @$r2;

    if ($#l1 != $#l2) {
	# lists are different lengths, so we know right off that
	# they must not be the same.
	return $DIFFERENT;
    } else {
	for(my $i = 0; $i <= $#l1; $i++) {
	    if (ref $l1[$i] eq ref $l2[$i]) {
		if (ref $l1[$i] eq "SCALAR") {
		    return $DIFFERENT if $l1[$i] ne $l2[$i];
		} elsif (ref $l1[$i] eq "HASH") {
		    return $DIFFERENT 
			if ($self->lists_diff([keys %{$l1[$i]}],
					      [keys %{$l2[$i]}]) 
			    == $DIFFERENT ||
			    $self->lists_diff([values %{$l1[$i]}],
					      [values %{$l2[$i]}])
			    == $DIFFERENT);
		} elsif (ref $l1[$i] eq "ARRAY") {
		    return $DIFFERENT 
			if ($self->lists_diff($l1[$i],$l2[$i]) == $DIFFERENT);
		} else {
		    # don't know how to compare anything else
		}
	    } else {
		return $DIFFERENT;
	    }
	}
    }
    return $SAME;
}

# }}}
# }}}


# extract first x chars of a string
# Min's additions for revising email 
# input 0: string to be truncated
# input 1: max length of string 
sub truncate_string {
  
    my $full_string = shift;
    my $len = shift || 20;
    my $truncated_string;  

    #checks for length of title first
    if ( length($full_string) > $len ) {
        $truncated_string = substr($full_string, 0, $len) . "...";
    } else {
        $truncated_string = $full_string;
    }
}    


# }}}
# {{{ email

# emails relevant parties with info for an item
sub email {
    my $self    = shift;
    my $iid     = shift;
    my $subject = shift;
    my $skip    = shift;

    $self->debug("email($iid,$subject,$skip)");
    my $item_object = PMT::Item->retrieve($iid);
    my $r = $item_object->full_data();
    my %item = %$r;

    #Min's additions to revise email subject and source
    my $project_title = &truncate_string($item{'project'});  
    my $subject_title = &truncate_string($item{'title'});  

    if ($subject =~ /^new/) {
        $subject_title = $subject_title . "(NEW)";  
    } 

    my $email_subj = "[PMT:$project_title] Attn:$item{'assigned_to_fullname'}-$subject_title";
    my $send_to;

    #extract item owner's name and email
    my $sql1 = qq {SELECT email, username 
		      FROM users 
		          WHERE fullname = ?;};
    my $own = $self->s($sql1,[$item{'owner_fullname'}],['username','email']);
    my @owner = @$own;
    my $owner_email = $owner[0]->{username} . " (" . $owner[0]->{email} . ")";

    my $sql = qq {SELECT u.username,u.email 
		      FROM notify n, users u
			  WHERE n.username = u.username
			  AND u.status = 'active' AND u.grp = 'f'
			      AND n.iid = ? AND u.username <> ?;};
    $r = $self->s($sql,[$iid,$skip],['username','email']);
    my @users = @$r;
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
	$self->debug("sending mail to $user->{username}");
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
        close MAIL;
    }
}

# }}}
# {{{ update_email

# emails relevant parties with info for an item
# when it is updated.
sub update_email {
    my $self    = shift;
    my $iid     = shift;
    my $subject = untaint_ascii(shift);
    my $comment = shift;
    my $skip    = shift || "";  #username
    $self->debug("update_email($iid,$subject,[comment],$skip)");
    my $item_object = PMT::Item->retrieve($iid);
    my $r = $item_object->full_data();
    my %item = %$r;

    $comment =~ s/<b>//g;
    $comment =~ s/<\/b>//g;
    $comment =~ s/<br \/>/\n/g;

    $Text::Wrap::columns = 72;
    my $body = Text::Wrap::wrap("","",$comment);

    #Min's additions to revise email subject and source
    my $updater = $skip; 
#From: pmt\@www2.ccnmtl.columbia.edu (Project Management Tool)
    if ($skip eq "") {
       $updater = "pmt\@www2.ccnmtl.columbia.edu (Project Management Tool)";
    }

    #extract updater's email
    my $sql1 = qq {SELECT email 
		      FROM users 
		          WHERE username = ?;};
    my $upd = $self->s($sql1,[$updater],['email']);
    my @u = @$upd; 
    #my $updater_info = $u[0]->{email};
    #my $updater_info = "(" . $u[0]->{email} . ")" . $updater;
    my $updater_info = $updater . "<" . $u[0]->{email} . ">";

    my $project = $item{'project'};

    my $project_title = &truncate_string($project);
    my $subject_title = &truncate_string($item{'title'});

    my $email_subj = "[PMT:$project_title] Attn:$item{'assigned_to_fullname'}-$subject_title";

    my $sql = qq {SELECT u.username,u.email 
		      FROM notify n, users u
			  WHERE n.username = u.username
			  AND u.status = 'active' AND u.grp = 'f'
			      AND n.iid = ? AND u.username <> ?;};
    $r = $self->s($sql,[$iid,$skip],['username','email']);
    my @users = @$r;

    foreach my $user (@users) {
	$self->debug("sending mail to $$user{'username'}");
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
        close MAIL;
    }
}

# }}}

# {{{ weekly_summary

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

# }}}
# {{{ staff_report

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

    $self->debug("edit_project($pid,$name,$caretaker,$pub_view,$status,$projnum)");
    $self->update(qq{UPDATE projects SET name = ?, description = ?, caretaker = ?,pub_view =?, status = ?,
		     projnum = ?, area = ?, url = ?, restricted = ?, approach = ?,
		     info_url = ?, entry_rel = ?, eval_url = ?, 
		     scale = ?, distrib = ?, type = ?, poster = ? where pid = ?;},
		     [$name,$description,$caretaker,$pub_view,
		      $status,$projnum,$area,$url,$restricted,$approach,
		      $info_url,$entry_rel,$eval_url,$scale,$distrib,
		      $type,$poster,$pid]);
    # clear users
    $self->update("DELETE from works_on WHERE pid = ?;",[$pid]);
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
	$self->update("INSERT INTO works_on (username,pid,auth) values (?,?,'manager');",
		      [$manager,$pid]);
	$seen{$manager} = 1;
	$got_caretaker = 1 if $manager eq $caretaker;
    }
    # make sure that at least the caretaker is a manager.
    if(!$got_caretaker) {
	$self->update("INSERT INTO works_on (username,pid,auth) values (?,?,'manager');",
			 [$caretaker,$pid]);
	$seen{$caretaker} = 1;
    }
    foreach my $developer (@$dr) {
	next if $developer eq "";
	next if $developer eq "-1";
	next if $seen{$developer};
	$self->update("INSERT INTO works_on (username,pid,auth) values (?,?,'developer');",
			 [$developer,$pid]);
	$seen{$developer} = 1;
    }
    foreach my $guest (@$gr) {
	next if $guest eq "";
	next if $guest eq "-1";
	next if $seen{$guest};
	$self->update("INSERT INTO works_on (username,pid,auth) values (?,?,'guest');",
			 [$guest,$pid]);
	$seen{$guest} = 1;
    }

    $self->update("delete from project_clients where pid = ?;",[$pid]);
    foreach my $client (@$cr) {
	next if $client eq "";
	$self->update("insert into project_clients (pid,client_id) values (?,?);",
		      [$pid,$client]);
    }

}

# }}}
# {{{ add_user

sub add_user {
    my $self     = shift;
    my $username = untaint_username(shift);
    $self->debug("add_user($username,*)");
    my $password = shift 
	|| throw Error::NO_PASSWORD "no password specified";
    my $fullname = escape(shift)
	|| $username;
    my $email    = escape(shift)
	|| throw Error::NO_EMAIL "no email address specified";


    $self->update("INSERT INTO users (username,fullname,email,password)
                          VALUES (?,?,?,?);",[$username,$fullname,$email,$password]);
    return;
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
    $self->debug("update_user($username,*,*,*,$fullname,$email)");
    throw Error::NO_EMAIL "email address is necessary." 
	unless $email;
    
    if ($new_pass eq "") { $new_pass = $password; $new_pass2 = $password; }

    if ($new_pass eq $new_pass2) {
	$self->update("UPDATE users SET fullname = ?, email = ?, password = ? 
                          WHERE username = ?;",[$fullname,$email,$new_pass,$username]);
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

    $self->add_user($normalized,$password,$group_name,$email);
    my $sql = qq{update users set grp = 't' where username = ?;};
    $self->update($sql,[$normalized]);
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

    my $sql = qq{delete from in_group where grp = ?;};
    $self->update($sql,[$group]);
    $sql = qq{insert into in_group (grp,username) values (?,?);};

    foreach my $u (@$users) {
	$u = untaint_username($u);
	$self->update($sql,[$group,$u]);
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


# {{{ --- database utility functions

# {{{ s

sub s {
    my $self        = shift;
    return $self->{db}->s(@_);
}

# }}}
# {{{ ss

sub ss {
    my $self        = shift;
    return $self->{db}->ss(@_);
}

# }}}
# {{{ update

sub update {
    my $self = shift;
    return $self->{db}->update(@_);
}

# }}}


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
    if(defined $self) {
	if($self->can("debug")) {
	    $self->debug("}}} DESTROY()");
	}
    }
}

1;
