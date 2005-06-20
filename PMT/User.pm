# File: User.pm
# Time-stamp: <Mon Nov  4 16:33:30 2002>
# Author: anders pearson
use strict;
package PMT::User;
use lib qw(.);
use PMT::Common;
my %PRIORITIES = (4 => 'CRITICAL', 3 => 'HIGH', 2 => 'MEDIUM', 1 => 'LOW',
0 => 'ICING');

my @ATTRIBUTES = qw(username fullname email status grp password);

sub new {
    my $pkg = shift;
    my $username = shift;
    my $self = bless {username => $username,
		      db => new PMT::DB()
		      }, $pkg;
    $self->debug("new($username)");
    $self->_load_data();

    return $self;
}

sub _load_data {
    my $self = shift;
    $self->debug("_load_data()");
    my $sql = qq{select username,fullname,email,status,grp, password
		     from users where username = ?;};
    my $res = $self->ss($sql,[$self->get("username")],[@ATTRIBUTES]);
    foreach my $att (@ATTRIBUTES) {
	$self->{$att} = $res->{$att};
    }
}

sub get {
    my $self = shift;
    my $attribute = shift;
    return undef unless grep {$attribute eq $_} @ATTRIBUTES;
    return $self->{$attribute};
}

sub data {
    my $self = shift;
    my %data;
    foreach my $attr (@ATTRIBUTES) {
	$data{$attr} = $self->get($attr);
    }
    return \%data;
}



# {{{ home

# returns a nice hashref of data to plugin to
# the template for the user's homepage.
sub home {
    my $self = shift;
    my $username = $self->get("username");
    my $sort = shift || "";
    $self->debug("home($username,$sort)");
    my %data = %{$self->data()};
    $data{items}                = [
				   map {
				       if ($_->{overdue} < -7) {
					   $_->{schedule_status} = 'ok';
				       } elsif ($_->{overdue} < -1) {
					   $_->{schedule_status} = 'upcoming';
				       } elsif ($_->{overdue} < 1) {
					   $_->{schedule_status} = 'due';
				       } elsif ($_->{overdue} < 7) {
					   $_->{schedule_status} = 'overdue';
				       } else {
					   $_->{schedule_status} = 'late';
				       }
                                       $_->{priority_label} = $PRIORITIES{$_->{priority}};
				       $_;
				   }
				   @{$self->items($username,$sort)}];
    my $cdbi = CDBI::User->retrieve($username);
    $data{total_estimated_time} = $cdbi->total_estimated_time();
    $data{groups}               = $cdbi->user_groups();
    my $est_priority = $cdbi->estimated_times_by_priority();
    my $est_sched = $cdbi->estimated_times_by_schedule_status();
    my $scheds = scale_array(150.0,[$est_sched->{ok}, $est_sched->{upcoming}, 
				    $est_sched->{due}, $est_sched->{overdue}, 
				    $est_sched->{late}]);

    $data{ok} = $scheds->[0];
    $data{upcoming} = $scheds->[1];
    $data{due} = $scheds->[2];
    $data{overdue} = $scheds->[3];
    $data{late} = $scheds->[4];

    my $priorities = scale_array(150.0, [$est_priority->{priority_4}, $est_priority->{priority_3},
					 $est_priority->{priority_2}, $est_priority->{priority_1},
					 $est_priority->{priority_0}]);

    $data{critical} = $priorities->[0];
    $data{high} = $priorities->[1];
    $data{medium} = $priorities->[2];
    $data{low} = $priorities->[3];
    $data{icing} = $priorities->[4];

    return \%data;
}

# }}}

sub quick_edit_data {
    my $self = shift;
    my $username = $self->get("username");
    my $sort = shift || "";
    $self->debug("home($username,$sort)");
    my %data = %{$self->data()};
    $data{items}                = [
				   map {
				       if ($_->{overdue} < -7) {
					   $_->{schedule_status} = 'ok';
				       } elsif ($_->{overdue} < -1) {
					   $_->{schedule_status} = 'upcoming';
				       } elsif ($_->{overdue} < 1) {
					   $_->{schedule_status} = 'due';
				       } elsif ($_->{overdue} < 7) {
					   $_->{schedule_status} = 'overdue';
				       } else {
					   $_->{schedule_status} = 'late';
				       }
                                       my $i = PMT::Item->retrieve($_->{iid});
                                       $_->{status_select} = $i->status_select();
                                       $_->{priority_select} = $i->priority_select();
                                       my $p = $i->mid->pid;
                                       $_->{assigned_to_select} = $p->assigned_to_select($i->assigned_to);
				       $_;
				   }
				   @{$self->items($username,$sort)}];
    return \%data;
}

# }}}


# {{{ items

# gets the list of items that are either assigned to the user and open
# or owned by the user and resolved.
sub items {
    my $self = shift;
    my $username = $self->get("username");
    my $viewer = shift;
    my $sort = shift || "priority";
    $self->debug("user_items($viewer,$sort)");
    my %sorts = (priority => "i.priority DESC, i.type DESC, i.target_date ASC",
		 type => "i.type DESC, i.priority DESC, i.target_date ASC",
		 title => "i.title ASC, i.priority DESC, i.target_date ASC",
		 status => "i.status ASC, i.priority DESC, i.target_date ASC",
		 project => "p.name ASC, i.priority DESC, i.type DESC, i.target_date ASC",
		 target_date => "i.target_date ASC, i.priority DESC, i.type DESC",
		 last_mod => "i.last_mod DESC, i.priority DESC, i.type DESC, i.target_date ASC",
		 assigned_to => "i.assigned_to ASC, i.priority DESC, i.type DESC, i.target_date ASC",
		 owner       => "i.owner ASC, i.priority DESC, i.type DESC, i.target_date ASC");
    $sort = "priority" unless exists $sorts{$sort};
    my $sql = qq {
SELECT i.iid,i.type,i.title,i.priority,i.status,i.r_status,p.name,
       m.pid,i.target_date,to_char(i.last_mod,'YYYY-MM-DD HH24:MI'),
       current_date - i.target_date,i.description
FROM   items i, milestones m, projects p
WHERE  i.mid = m.mid 
  AND  m.pid = p.pid 
  AND ((i.assigned_to = ? 
       AND i.status IN ('OPEN','UNASSIGNED','INPROGRESS')) 
       OR 
       (i.owner = ? AND i.status = 'RESOLVED') )
  AND ((p.pub_view = 'true') 
       OR  (p.pid in (SELECT w.pid 
                      FROM   works_on w
		      WHERE  w.username = ?))
       OR (i.assigned_to = ?) 
       OR (i.owner = ?))
  ORDER BY $sorts{$sort};};
    return make_classes([map 
        {
            $_->{priority_label} = $PRIORITIES{$_->{priority}}; 
            $_;
        } @{$self->s($sql, [$username,$username,$viewer,$viewer,$viewer],
                ['iid','type','title','priority',
                'status','r_status','project','pid',
                'target_date','last_mod','overdue','description'])}]);
}

# }}}




# {{{ menu

sub menu {
    my $self = shift;
    my $username = $self->get("username");
    my %data = %{$self->data()};
    delete $data{status};
    my $cdbi = CDBI::User->retrieve($username);
    my $projects = $cdbi->projects_hash();
    $data{projects} = [map {
        {pid => $_, name => $projects->{$_}};
    } sort {
        lc($projects->{$a}) cmp lc($projects->{$b});
    } keys %{$projects}];
    return \%data;

}

# }}}





# {{{ delete

# to be used for testing only. not safe in the
# wild.
sub delete {
    my $self = shift;
    $self->warn("delete()");
    $self->update("delete from users where username = ?;",[$self->get("username")]);
}

# }}}


# {{{ db wrappers

sub s {my $self = shift;$self->{db}->s(@_);}
sub ss {my $self = shift;$self->{db}->ss(@_);}
sub update {my $self = shift;$self->{db}->update(@_);}

# }}}
# {{{ log wrappers
sub debug {my $self = shift;}
sub info {my $self = shift;}
sub warn {my $self = shift;}
sub error {my $self = shift;}
# }}}


1;
