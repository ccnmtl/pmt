use lib qw(..);
package PMT::Milestone;
use base 'CDBI::DBI';

__PACKAGE__->table("milestones");
__PACKAGE__->sequence("milestones_s");
__PACKAGE__->columns(All => qw/mid pid name target_date status description/);
__PACKAGE__->columns(TEMP => qw/estimated_time completed_time
num_unclosed_items num_items/);
__PACKAGE__->has_a(pid => 'PMT::Project');
__PACKAGE__->set_sql(estimated_time => qq{
     SELECT sum(i.estimated_time) as estimated_time from items i
     where i.mid = ?
         and i.status in ('OPEN','UNASSIGNED','INPROGRESS');
});
__PACKAGE__->set_sql(completed_time => qq{
     select sum(a.actual_time) as completed_time
     from actual_times a, items i
     where a.iid  = i.iid and i.mid = ?;
});
__PACKAGE__->set_sql(milestones_on => qq{
select __ESSENTIAL__
from __TABLE__
where target_date = ? and pid = ?
});

__PACKAGE__->set_sql(num_unclosed_items,
  qq{SELECT count(*) as num_unclosed FROM items i WHERE i.mid = ? and i.status
  in ('OPEN','RESOLVED','UNASSIGNED','INPROGRESS');},
  'Main');

__PACKAGE__->set_sql('num_items', qq{select count(*) as num_items from
items i where i.mid = ?;}, 'Main');
my %PRIORITIES = (4 => 'CRITICAL', 3 => 'HIGH', 2 => 'MEDIUM', 1 => 'LOW',
0 => 'ICING');


sub num_unclosed_items {
  my $self = shift;
  my $sth = $self->sql_num_unclosed_items;
  $sth->execute($self->mid);
  my $r = $sth->fetchrow_hashref()->{num_unclosed};
  $sth->finish();
  return $r;
}

sub estimated_time {
    my $self = shift;
    my $sth = $self->sql_estimated_time;
    $sth->execute($self->mid);
    my $r = $sth->fetchrow_hashref()->{estimated_time};
    $sth->finish();
    return $r;
}

sub completed_time {
    my $self = shift;
    my $sth = $self->sql_completed_time;
    $sth->execute($self->mid);
    my $r = $sth->fetchrow_hashref()->{completed_time};
    $sth->finish();
    return $r;
}

sub num_items {
    my $self = shift;
    my $sth = $self->sql_num_items;
    $sth->execute($self->mid);
    my $r = $sth->fetchrow_hashref()->{num_items};
    $sth->finish();
    return $r;
}

__PACKAGE__->set_sql(count_all => "SELECT COUNT(*) as cnt FROM __TABLE__");
__PACKAGE__->has_many(items => 'PMT::Item', 'mid');

sub data {
    my $self = shift;
    $self->update_milestone();
    return {mid => $self->mid, name => $self->name, target_date =>
        $self->target_date, pid => $self->pid->pid, status =>
        $self->status, description => $self->description,
        project => $self->pid->name, pub_view => $self->pid->pub_view
    };
}


sub unclosed_items {
    my $self = shift;
    my $sortby = shift || "priority";
    my $username = shift;

    my @items = map {$_->simple_data($username)} $self->all_unclosed_items();
    if ($sortby eq "item") {
        @items = sort {$a->{iid} <=> $b->{iid}} @items;
    } elsif ($sortby eq "status" || $sortby eq "target_date" || $sortby eq
        "last_mod") {
        @items = sort {$a->{$sortby} cmp $b->{$sortby}} @items;
    } elsif ($sortby eq "owner" || $sortby eq "assigned_to") {
        @items = sort {$a->{"${sortby}_fullname"} cmp
            $b->{"${sortby}_fullname"}} @items;
    } else {
        @items = sort {$b->{priority} <=> $a->{priority}} @items;
    }

    return \@items;
}

sub all_unclosed_items {
    my $self = shift;
    return PMT::Item->unclosed_items_in_milestone($self->mid);
}

sub update_item_target_dates {
    my $self = shift;
    my $new_target_date = shift;

    foreach my $item ($self->all_unclosed_items()) {
	if ($item->target_date == $self->target_date) {
	    $item->set(target_date => $new_target_date);
	    $item->update();
	}
    }

}

sub update_milestone {
    my $self = shift;
    if ($self->should_be_closed()) {
        $self->close_milestone($user);
    } else {
        $self->open_milestone();
    }
}

sub should_be_closed {
  my $self = shift;
  my $passed = $self->target_date_passed();
  if ($passed) {
      my $unclosed = $self->num_unclosed_items();
      if ($unclosed == 0) {
	  # target date has passed but there are open items
	  return 1;
      } else {
	  # target date passed but no open items
	  return 0;
      }
  }
  # target date hasn't passed yet
  return 0;
}

__PACKAGE__->set_sql(target_date_passed,
  qq{SELECT target_date < current_date as passed from milestones
where mid = ?;},
  'Main');

sub target_date_passed {
    my $self = shift;
    my $sth = $self->sql_target_date_passed;
    $sth->execute($self->mid);
    my $r = $sth->fetchrow_hashref()->{passed};
    $sth->finish();
    return $r;
}

sub close_milestone {
    my $self = shift;
    if ($self->status ne "CLOSED") {
        $self->status('CLOSED');
        $self->update();
    }

}

sub open_milestone {
    my $self = shift;
    $self->status('OPEN');
    $self->update();
}

sub delete_milestone {
    my $self = shift;
    throw Error::MILESTONE_NOT_EMPTY "milestone still has items attached to it."
        unless $self->num_items == 0;
    my $pid = $self->pid->pid;
    $self->delete();
    return $pid;
}

__PACKAGE__->set_sql(passed_open_milestones => qq{
select mid,name,target_date,pid
from milestones
where status = 'OPEN'
and target_date < current_date
order by target_date asc
;},'Main');

sub passed_open_milestones {
    my $self = shift;
    my $sth = $self->sql_passed_open_milestones;
    $sth->execute();
    my @results = ();
    foreach my $r (@{$sth->fetchall_arrayref({})}) {
	$r->{project} = PMT::Project->retrieve($r->{pid})->name;
	push @results, $r;
    }
    return \@results;
}

__PACKAGE__->set_sql(upcoming_milestones => qq{
select mid,name,target_date,pid
from milestones
where status = 'OPEN'
and target_date > current_date
and target_date < current_date + interval '1 month'
order by target_date asc
;},'Main');

sub upcoming_milestones {
    my $self = shift;
    my $sth = $self->sql_upcoming_milestones;
    $sth->execute();
    my @results = ();
    foreach my $r (@{$sth->fetchall_arrayref({})}) {
	$r->{project} = PMT::Project->retrieve($r->{pid})->name;
	push @results, $r;
    }
    return \@results;
}

__PACKAGE__->set_sql(recent_events => qq{
SELECT e.status,i.iid,i.title,c.comment,c.username,e.event_date_time,i.assigned_to,i.owner
FROM   events e, items i, comments c
WHERE  e.item = i.iid AND c.event = e.eid AND i.mid = ?
ORDER BY e.event_date_time DESC limit 10;
}, 'Main');

sub recent_events {
    my $self = shift;
    my $sth = $self->sql_recent_events;
    $sth->execute($self->mid);
    return $sth->fetchall_arrayref({});
}


1;
