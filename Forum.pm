#!/usr/bin/perl -wT

# File: Forum.pm
# Time-stamp: <Fri May 17 14:09:29 2002>
#
# Copyright (C) 2002 by anders pearson
#
# Author: anders pearson
#
# Description:
#  database wrapper for the weblog/discussion forum
#  functionality.
use strict;
use lib qw(.);
use PMT;
use PMT::Common;
use Mail::Sendmail;
use Text::Wrap;
use Data::Dumper;
use Text::Tiki;
use PMT::Node;
use PMT::Project;
package Forum;

sub new {
    my $pkg = shift;
    my $user = shift;
    my $pmt = shift;

    my $member_vars = {
	pmt => $pmt,
	user => $user,
	};
    return bless $member_vars, $pkg;
}

sub node {
    my $self = shift;
    my $nid = shift;
    my $node = PMT::Node->retrieve($nid);
    my $user = CDBI::User->retrieve($self->{user});
    return $node->data($user);
}

sub delete_node {
    my $self = shift;
    my $nid = shift;
    my $node = PMT::Node->retrieve($nid);
    # annoyingly, we have to have a non-deleted object around
    # so we can call dbi_commit() on it.
    my $u = $node->author;
    $node->delete;
#    $u->dbi_commit();
}


sub recent_posts {
    my $self = shift;
    $self->{pmt}->debug("Forum::recent_posts()");
    my $sql = qq{select n.nid,n.subject,n.body,n.replies,
		 n.project,p.name,n.author,u.fullname,
                 to_char(n.added,'FMMonth FMDDth, YYYY HH24:MI'),
		 to_char(n.modified, 'FMMonth FMDDth, YYYY HH24:MI')
		 from nodes n, projects p, users u
		     where n.type = 'post'
		     AND n.project = p.pid
		     AND n.author = u.username
		     AND (p.pid in (select w.pid from works_on w 
				    where username = ?) 
			  OR p.pub_view = 'true')
		     order by modified desc limit 10;};
    return $self->{pmt}->s($sql,[$self->user()],['nid','subject','body',
						 'replies','pid','project',
						 'author','author_fullname',
						 'added','modified']);
}

sub posts {
    my $self = shift;
    my $limit = shift;
    my $offset = shift;
    $self->{pmt}->debug("Forum::posts($limit,$offset)");
    my $sql = qq{select n.nid,n.subject,n.body,n.replies,
		 n.project,p.name,n.author,u.fullname,n.added,
		 n.modified
		 from nodes n, projects p, users u
		     where n.type = 'post'
		     AND n.project = p.pid
		     AND n.author = u.username
		     AND (p.pid in (select w.pid from works_on w 
				    where username = ?) 
			  OR p.pub_view = 'true')
		     order by modified desc limit $limit
		     offset $offset;};
    return $self->{pmt}->s($sql,[$self->user()],['nid','subject','body',
						 'replies','pid','project',
						 'author','author_fullname',
						 'added','modified']);
}

sub recent_logs {
    my $self = shift;
    return $self->logs(10,0);
}

sub logs {
    my $self = shift;
    my $limit = shift || "10";
    my $offset = shift || "0";
    return [map { $self->node($_->nid)} PMT::Node->search(type => 'log',
        {order_by => "modified desc limit $limit offset $offset"})];
}

sub num_logs {
    my $self = shift;
    $self->{pmt}->debug("Forum::num_logs()");
    my $sql = qq{select count(*) from nodes where type='log';};
    return $self->{pmt}->ss($sql,[],['cnt'])->{cnt};
}

sub num_posts {
    my $self = shift;
    $self->{pmt}->debug("Forum::num_posts()");
    my $sql = qq{select count(*)
		 from nodes n, projects p, users u
		     where n.type = 'post'
		     AND n.project = p.pid
		     AND n.author = u.username
		     AND (p.pid in (select w.pid from works_on w 
				    where username = ?) 
			  OR p.pub_view = 'true');};
    return $self->{pmt}->ss($sql,[$self->user()],['cnt'])->{cnt};

}


sub recent_comments {
    my $self = shift;
    return [map {
        $self->node($_->nid);
    } PMT::Node->search(type => 'comment', {order_by =>
            "modified desc limit 10"})];
}

sub recent_items {
    my $self = shift;
    $self->{pmt}->debug("Forum::recent_items()");
    my $sql = qq{select i.iid,i.type,i.title,i.status,p.name,p.pid 
		     from items i, projects p, milestones m 
		     where i.mid = m.mid AND m.pid = p.pid
		     AND (p.pid in (select w.pid from works_on w 
				    where username = ?) 
			  OR p.pub_view = 'true')
		     order by last_mod desc limit 10;};
    return $self->{pmt}->s($sql,[$self->user()],['iid','type','title','status','project','pid']);
}

sub all_recent {
    my $self = shift;
    my @nodes = PMT::Node->retrieve_from_sql(qq{nid > 0 order by modified
        desc limit 10});
    return [map {{nid => $_->nid, subject => $_->subject, body => $_->body,
            author => $_->author->username, fullname => $_->author->fullname}} @nodes];
}

# project specific ones

sub recent_project_posts {
    my $self = shift;
    my $pid = shift;
    return $self->project_posts($pid,10,0);
}


sub project_posts {
    my $self = shift;
    my $pid = shift;
    my $limit = shift || 10;
    my $offset = shift || 0;

    return [map {$self->node($_->nid)} PMT::Node->search(type => 'post',
        project => $pid,
        {order_by => "modified desc limit $limit offset $offset"})];
}

# Min's addition to add forum posts in reports
sub project_posts_by_time {
    my $self  = shift;
    my $pid   = shift;
    my $start = shift;
    my $end   = shift;

    
    return [map {$self->node($_->nid)} PMT::Node->pid_posts_in_range($pid,
         $start, $end)];
}

sub num_project_posts {
    my $self = shift;
    my $pid = shift;
    $self->{pmt}->debug("Forum::num_project_posts($pid)");
    my $sql = qq{select count(*) from nodes n, projects p, users u
		     where n.type = 'post'
		     AND n.project = ?
		     AND p.pid = n.project
		     AND n.author = u.username;};
    return $self->{pmt}->ss($sql,[$pid],['cnt'])->{cnt};
}


sub recent_project_logs {
    my $self = shift;
    my $pid = shift;
    $self->{pmt}->debug("Forum::recent_project_logs($pid)");
    my $sql = qq{select n.nid,n.replies,
		 to_char(added,'FMMonth FMDDth, YYYY') AS added_informal,
		 n.author,u.fullname 
		     from nodes n, users u where n.type = 'log'
		     and n.author = u.username
		     and n.author in (select username from works_on where pid = ?)
		     order by modified desc limit 10;};
    return $self->{pmt}->s($sql,[$pid],['nid','replies','added_informal',
					'author','author_fullname']);
}

sub recent_project_items {
    my $self = shift;
    my $pid = shift;
    my $project = PMT::Project->retrieve($pid);
    return $project->recent_items();
}


# post something (post, diary entry, bookmark, image, comment)

# returns nid for new node

sub post {
    my $self        = shift;
    my %args = @_;

    $self->{pmt}->debug("Forum::post( ... )");

    if($args{reply_to}) {
	$args{type} = 'comment';
    } else {
	$args{reply_to} = 0;
    }
#    $args{subject} = "no subject" unless $args{subject};
    
    $self->{pmt}->error("null message body") unless $args{body};
    my $tiki = new Text::Tiki;
    my $body = PMT::Common::escape($tiki->format($args{body}));

    my $sql;
    if("log" eq $args{type}) {
	$args{pid} = 0;           # no project associated with it.
	# put it in the database
	$sql = qq{insert into nodes (type,author,subject,body,reply_to)
			 values (?,?,?,?,?);};
	$self->{pmt}->update($sql,[$args{type},$self->user(),
				   $args{subject},$body,
				   $args{reply_to}]);
    } elsif ("comment" eq $args{'type'}) {
	$sql = qq{insert into nodes (type,author,subject,body,reply_to)
		      values (?,?,?,?,?);};
	$self->{pmt}->update($sql,[$args{type},$self->user(),
				   $args{subject},$body,
				   $args{reply_to}]);
    } else {
	# put it in the database
	$sql = qq{insert into nodes (type,author,subject,body,reply_to,project)
			 values (?,?,?,?,?,?);};
	$self->{pmt}->update($sql,[$args{type},$self->user(),
				   $args{subject},$body,
				   $args{reply_to},$args{pid}]);
    }
    $sql = qq{select currval('nodes_nid_seq');};
    my $d = $self->{pmt}->ss($sql,[],['nid']);

    $self->reply_to_node($args{reply_to});


    if($args{type} eq "post") {
	$self->email_post($d->{nid},\%args);
    } elsif($args{type} eq "comment") {
	$self->email_reply($d->{nid},\%args);
    }

    return $d->{nid};
}


sub email_post {

    my $self = shift;
    my $nid = shift;
    my $args = shift;
    $self->{pmt}->debug("email_post($nid,[...])");
    $Text::Wrap::columns = 72;
    my $body = Text::Wrap::wrap("","",$args->{body});

    $body .= "\n\n-- \nthis message sent automatically by the PMT forum. 
to reply, please visit <http://pmt.ccnmtl.columbia.edu/home.pl?mode=node;nid=$nid>\n";

    my $username = $self->user();
    my $user = CDBI::User->retrieve($username);

    my $current_user = $user->user_info();

    my $project = PMT::Project->retrieve($args->{pid});
    my @users = $project->all_personnel_in_project();

    #Min's additions
    my $subject = "[PMT Forum] $args->{subject}";
    if ($args->{pid} ne "") {
        my $project_name = $project->name;
        my $subject = "[PMT Forum: $project_name] $args->{subject}";
        $body = "project: $project_name\nauthor: $current_user->{user_fullname}\n" . $body; 
    }

    foreach my $u (@users) {

	# the author doesn't need a copy
	next if $u->{username} eq $current_user->{user_username};

	my %mail = (To => $u->{email},
		    From => "$current_user->{user_fullname} <$current_user->{user_email}>",
		    #Subject => "[PMT Forum: ]$args->{subject}",
		    Subject => $subject,
		    Message => $body);
	Mail::Sendmail::sendmail(%mail) or die $Mail::Sendmail::error;
    }
}

sub email_reply {
    my $self = shift;
    my $nid = shift;
    my $args = shift;
    $self->{pmt}->debug("email_reply($nid,[...])");
    $Text::Wrap::columns = 72;
    my $body = Text::Wrap::wrap("","",$args->{body});

    my $reply_to_node = $self->node($args->{reply_to});

    # don't bother sending a copy to the author
    # if they're just replying to their own node.
    return if $self->user() eq $reply_to_node->{author};

    my $author = CDBI::User->retrieve($reply_to_node->{author});
    my $user_info = $author->user_info();

    my $user = CDBI::User->retrieve($self->user());

    my $current_user = $user->user_info();

    #Min's additions to make email subject more informative
    my $subject = "[PMT Forum] $args->{subject}";
    if ($args->{pid} ne "") {
        my $sql = qq {SELECT name 
            FROM projects 
            WHERE pid = ?;};
        my $pname = $self->{pmt}->ss($sql,[$args->{pid}],['name']);
        my $project_name = $pname->{name};
        my $subject = "[PMT Forum: $project_name] $args->{subject}";
        $body = "project: $project_name\nauthor: $current_user->{user_fullname}\n\n--\n" . $body;  
    }
    
    $body .= "\n\n-- \nthis message sent automatically by the PMT forum. 
to reply, please visit <http://pmt.ccnmtl.columbia.edu/home.pl?mode=node;nid=$nid>\n";


    my %mail = (To => $user_info->{user_email},
		From => "$current_user->{user_fullname} <$current_user->{user_email}>",
		Subject => $subject,
		Message => $body);

    Mail::Sendmail::sendmail(%mail) or die $Mail::Sendmail::error;

}

sub user {
    my $self = shift;
    return $self->{user};
}


sub reply_to_node {
    my $self = shift;
    my $nid  = shift || "";
    $self->{pmt}->debug("reply_to_node($nid)");

    return unless $nid;
    return unless $nid =~ /^\d+$/;

    my $sql = qq{update nodes set replies = replies + 1,
		 modified = current_timestamp where nid = ?;};
    $self->{pmt}->update($sql,[$nid]);
    $sql = qq{select reply_to from nodes where nid = ?;};
    my $d = $self->{pmt}->ss($sql,[$nid],['reply_to']);
    $self->reply_to_node($d->{reply_to});
}

sub parse_body {
    my $self   = shift;
    my $body   = shift || "";
    $body = $self->paragraphize($body);

    return $body;
}

sub html_escape {
    my $self = shift;
    my $text = shift;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
    $text =~ s/& /&amp;/g;
    return $text;
}

sub paragraphize {
    my $self = shift;
    my $text = shift;
    my @pars = split /[\n\r]+/, $text;
    $text = "";
    foreach my $line (@pars) {
	next if $line =~ /^\s+$/;
	$text .= "<p>$line</p>\n";
    }
    return $text;
}


1;
