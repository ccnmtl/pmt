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

    my $member_vars = {
        user => $user,
        u => PMT::User->retrieve($user),
        };
    return bless $member_vars, $pkg;
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


sub recent_logs {
    my $self = shift;
    return $self->logs(10,0);
}

sub logs {
    my $self = shift;
    my $limit = shift || "10";
    my $offset = shift || "0";
    return [map { $_->data($self->{u})} PMT::Node->search(type => 'log',
        {order_by => "modified desc limit $limit offset $offset"})];
}




sub recent_comments {
    my $self = shift;
    return [map {
        $_->data($self->{u})
    } PMT::Node->search(type => 'comment', {order_by =>
            "modified desc limit 10"})];
}


sub all_recent {
    my $self = shift;
    my @nodes = PMT::Node->retrieve_from_sql(qq{nid > 0 order by modified
        desc limit 10});
    return [map {{nid => $_->nid, subject => $_->subject, body => $_->body,
            author => $_->author->username, fullname => $_->author->fullname,
            added => $_->added}} @nodes];
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

    return [map {$_->data($self->{u})} PMT::Node->search(type => 'post',
        project => $pid,
        {order_by => "modified desc limit $limit offset $offset"})];
}

# Min's addition to add forum posts in reports
sub project_posts_by_time {
    my $self  = shift;
    my $pid   = shift;
    my $start = shift;
    my $end   = shift;


    return [map {$_->data($self->{u})} PMT::Node->pid_posts_in_range($pid,
         $start, $end)];
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

    if($args{reply_to}) {
        $args{type} = 'comment';
    } else {
        $args{reply_to} = 0;
    }

    my $tiki = new Text::Tiki;
    $args{body} =~ s/(\w+)\+(\w+)\@/$1&plus;$2@/g; # workaround for second awful Text::Tiki bug
    $args{body} =~ s/\(([^\)\(]+\@[^\)\(]+)\)/( $1 )/g; # workaround horrible bug in Text::Tiki
    my $body = PMT::Common::escape($tiki->format($args{body}));
    $args{author} ||= $self->{user};
    my $author = PMT::User->retrieve($args{author});

    if(("log" eq $args{type}) || ("comment" eq $args{type})) {
        $args{pid} = 0;
    }

    my $p = PMT::Node->create({type=>$args{type},author => $author->username,
                               subject => $args{subject}, body =>$body,
                               reply_to => $args{reply_to}, project => $args{pid}});

    # add tags to the newly-created post
    my @tags = ();
    push @tags, split /[\n\r\,+]/, $args{tags};
    @tags = grep {$_ ne ""} map {&PMT::Common::escape($_);} @tags;
    $p->update_tags(\@tags, $author->username);
    
    $self->reply_to_node($args{reply_to});
    

    if($args{type} eq "post") {
        $self->email_post($p->nid,\%args);
    } elsif($args{type} eq "comment") {
        $self->email_reply($p->nid,\%args);
    }

    return $p->nid;
}


sub email_post {

    my $self = shift;
    my $nid = shift;
    my $args = shift;
    $Text::Wrap::columns = 72;
    my $body = Text::Wrap::wrap("","",$args->{body});

    $body .= "\n\n-- \nthis message sent automatically by the PMT forum.
to reply, please visit <http://$ENV{'SERVER_NAME'}/home.pl?mode=node;nid=$nid>\n";

    my $username = $self->user();
    my $user = PMT::User->retrieve($username);

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
        next if $u->username eq $current_user->{user_username};

        my %mail = (To => $u->email,
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
    $Text::Wrap::columns = 72;
    my $body = Text::Wrap::wrap("","",$args->{body});

    my $reply_to_node = PMT::Node->retrieve($args->{reply_to});

    # don't bother sending a copy to the author
    # if they're just replying to their own node.
    return if $self->user() eq $reply_to_node->author->username;

    my $author = $reply_to_node->author;
    my $user_info = $author->user_info();

    my $user = PMT::User->retrieve($self->user());

    my $current_user = $user->user_info();

    my $subject = "[PMT Forum] $args->{subject}";
    if ($args->{pid}) {
        my $project = PMT::Project->retrieve($args->{pid});
        my $project_name = $project->name;
        my $subject = "[PMT Forum: $project_name] $args->{subject}";
        $body = "project: $project_name\nauthor: $current_user->{user_fullname}\n\n--\n" . $body;
    }

    $body .= "\n\n-- \nthis message sent automatically by the PMT forum.
to reply, please visit <http://$ENV{'SERVER_NAME'}/home.pl?mode=node;nid=$nid>\n";


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

    return unless $nid;
    return unless $nid =~ /^\d+$/;

    my $node = PMT::Node->retrieve($nid);
    $node->replies($node->replies + 1);
    $node->update();
    $self->reply_to_node($node->reply_to);
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
