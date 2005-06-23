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

__PACKAGE__->set_sql('num_unclosed_items',
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
  my $count = $sth->fetchall_arrayref()->[0]->[0];
  $sth->finish;
  return $count;
}

sub estimated_time {
    my $self = shift;
    my $sth = $self->sql_estimated_time;
    $sth->execute($self->mid);
    return $sth->fetchall_arrayref()->[0]->[0];
}

sub completed_time {
    my $self = shift;
    my $sth = $self->sql_completed_time;
    $sth->execute($self->mid);
    my $res = $sth->fetchall_arrayref()->[0]->[0];
    $sth->finish;
    return $res;
}

sub num_items {
    my $self = shift;
    my $sth = $self->sql_num_items;
    $sth->execute($self->mid);
    my $count = $sth->fetchall_arrayref()->[0]->[0];
    $sth->finish;
    return $count;
}

__PACKAGE__->set_sql(count_all => "SELECT COUNT(*) FROM __TABLE__");
__PACKAGE__->has_many(items => 'PMT::Item', 'mid');

sub data {
    my $self = shift;
    return {mid => $self->mid, name => $self->name, target_date =>
        $self->target_date, pid => $self->pid->pid, status =>
        $self->status, description => $self->description,
        project => $self->pid->name, pub_view => $self->pid->pub_view
    };
}


sub unclosed_items {
    my $self = shift;
    my $sortby = shift || "priority";
    #Min's addtion to implement notification opt in/out
    my $username = shift;

    #Min's changes to implement notification opt in/out
    my @items = map {$_->data_withuser($username)} PMT::Item->unclosed_items_in_milestone($self->mid);
    #my @items = map {$_->data()} PMT::Item->unclosed_items_in_milestone($self->mid, $username);
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

sub update_milestone {
    my $self = shift;
    my $user = shift;
    my $unclosed = $self->num_unclosed_items;
    unless ($unclosed) {
        $self->close_milestone($user);
    } else {
        $self->open_milestone();
    }
}


sub close_milestone {
    my $self = shift;
    my $user = shift;
    if ($self->status ne "CLOSED") {
        $self->status('CLOSED');
        $self->update();
        foreach my $i ($self->items()) {
            $i->close($user); 
        }
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

1;
