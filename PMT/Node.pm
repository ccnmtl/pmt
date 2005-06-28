use lib qw(..);
use Time::Piece;
package PMT::Node;
use PMT::Common;
use base 'CDBI::DBI';
__PACKAGE__->table('nodes');
__PACKAGE__->sequence('nodes_nid_seq');
__PACKAGE__->columns(Primary => qw/nid/);
__PACKAGE__->columns(All => qw/nid subject body author reply_to replies
                               type added modified project/);
__PACKAGE__->has_a(author => 'PMT::User');

__PACKAGE__->add_constructor('user_posts_in_range' => qq{
author = ? and added >= ? and added <= date(?) + interval '1 day'});
__PACKAGE__->add_constructor('pid_posts_in_range' => qq{
project = ? and added >= ? and added <= ?});
__PACKAGE__->add_constructor('user_log_entries' => qq{
type = 'log' and author = ?});

sub can_delete {
    my $self = shift;
    my $user = shift;
    return ($self->replies == 0) && ($self->author->username eq
        $user->username);
}

sub added_informal {
    my $self = shift;
    my $added = $self->added;
    $added =~ s/(\.\d+)$//;
    my $t = Time::Piece->strptime($added, "%Y-%m-%d %T") ;
    return $t->fullmonth . " " . $t->mday . ", " . $t->year;
}

sub modified_informal {
    my $self = shift;
    my $modified = $self->modified;
    $modified =~ s/(\.\d+)$//;
    my $t = Time::Piece->strptime($modified, "%Y-%m-%d %T") ;
    return $t->fullmonth . " " . $t->mday . ", " . $t->year;
}

sub get_replies {
    my $self = shift;
    return PMT::Node->search(reply_to => $self->nid, 
        {order_by => 'modified desc'});
}

sub data {
    my $self = shift;
    my $user = shift || undef;
    my $d = 
        {nid               => $self->nid, 
	 subject           => $self->subject, 
         body              => $self->body, 
	 author            => $self->author->username, 
         replies           => $self->replies, 
	 reply_to          => $self->reply_to, 
	 type              => $self->type,
         added             => $self->added, 
	 modified          => $self->modified, 
         pid               => $self->project, 
	 added_informal    => $self->added_informal,
         modified_informal => $self->modified_informal, 
         author_fullname   => $self->author->fullname
	};
    
    if($self->project) {
        my $project = PMT::Project->retrieve($self->project);
	$d->{project} = $project->name;
    }
    if($self->replies > 0) {
	$d->{comment_html} = $self->comment_html();
    }
    if (defined($user)) {
        $d->{can_delete} = $self->can_delete($user);
    }
    return $d;
}

# returns reference to an array strings which are the
# html for the nested comments
sub comment_html {
    my $self = shift;
    my $code = '';
    foreach my $node ($self->get_replies()) {
	my $template = get_template("comment.tmpl");
	$template->param($node->data());
	$code .=  $template->output();
    }
    return $code;
}

__PACKAGE__->set_sql(search_forum => 
		     qq{select n.nid,n.subject,n.body,n.replies,
			n.project as pid,n.author,u.fullname as author_fullname,n.added,
			n.modified
			    from nodes n, users u
			    where u.username = n.author
			    AND (upper(n.body) like upper(?) OR upper(n.subject) like
				 upper(?))
			    order by added desc;},
		     'Main');
sub search_forum {
    my $self = shift;
    my $search = shift;
    my $sth = $self->sql_search_forum;
    $sth->execute("%$search%","%$search%");
    return $sth->fetchall_arrayref({});
} 

__PACKAGE__->set_sql(recent_posts => qq{select n.nid,n.subject,n.body,n.replies,
		 n.project as pid,p.name as project,n.author,u.fullname as author_fullname,
                 to_char(n.added,'FMMonth FMDDth, YYYY HH24:MI') as added,
		 to_char(n.modified, 'FMMonth FMDDth, YYYY HH24:MI') as modified
		 from nodes n, projects p, users u
		     where n.type = 'post'
		     AND n.project = p.pid
		     AND n.author = u.username
		     AND (p.pid in (select w.pid from works_on w 
				    where username = ?) 
			  OR p.pub_view = 'true')
		     order by modified desc limit 10;}, 'Main');

sub recent_posts {
    my $self = shift;
    my $username = shift;
    my $sth = $self->sql_recent_posts;
    $sth->execute($username);
    return $sth->fetchall_arrayref({});
}


sub posts {
    my $self = shift;
    my $username = shift;
    my $limit = shift;
    my $offset = shift;

    $self->set_sql(posts => qq{select n.nid,n.subject,n.body,n.replies,
		 n.project as pid,p.name as project,n.author,u.fullname as author_fullname,n.added,
		 n.modified
		 from nodes n, projects p, users u
		     where n.type = 'post'
		     AND n.project = p.pid
		     AND n.author = u.username
		     AND (p.pid in (select w.pid from works_on w 
				    where username = ?) 
			  OR p.pub_view = 'true')
		     order by modified desc limit $limit
		     offset $offset;}, 'Main');

    my $sth = $self->sql_posts;
    $sth->execute($username);
    return $sth->fetchall_arrayref({});
}

__PACKAGE__->set_sql(num_logs => qq{select count(*) as cnt from nodes where type='log';}, 'Main');
sub num_logs {
    my $self = shift;
    my $sth = $self->sql_num_logs;
    $sth->execute();
    return $sth->fetchrow_hashref()->{cnt};
}

__PACKAGE__->set_sql(num_posts => qq{select count(*) as cnt
		 from nodes n, projects p, users u
		     where n.type = 'post'
		     AND n.project = p.pid
		     AND n.author = u.username
		     AND (p.pid in (select w.pid from works_on w 
				    where username = ?) 
			  OR p.pub_view = 'true');}, 'Main');
sub num_posts {
    my $self = shift;
    my $sth = $self->sql_num_posts;
    $sth->execute();
    return $sth->fetchrow_hashref()->{cnt};
}

__PACKAGE__->set_sql(num_project_posts => qq{select count(*) as cnt from nodes n, projects p, users u
		     where n.type = 'post'
		     AND n.project = ?
		     AND p.pid = n.project
		     AND n.author = u.username;}, 'Main');

sub num_project_posts {
    my $self = shift;
    my $pid = shift;
    my $sth = $self->sql_num_project_posts;
    $sth->execute($pid);
    return $sth->fetchrow_hashref()->{cnt};
}


1;

