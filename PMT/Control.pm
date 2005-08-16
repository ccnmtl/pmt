package PMT::Control;
use strict;
use base 'CGI::Application';
use lib qw(..);
use PMT;
use PMT::Common;
use PMT::User;
use PMT::Project;
use PMT::Milestone;
use PMT::Document;
use PMT::Group;
use CGI;
use HTML::Template;
use Date::Calc qw/Week_of_Year Monday_of_Week Add_Delta_Days Days_in_Month Add_Delta_YM/;
use Net::LDAP;
use Text::Tiki;
use Forum;
use HTML::CalendarMonth;

use utf8;
use Data::Dumper;

sub setup {
    my $self = shift;
    $self->start_mode('home');
    $self->mode_param('mode');
    $self->run_modes(
        'home'                   => 'home',
        'user_settings_form'     => 'user_settings_form',
        'update_user'            => 'update_user',
        'my_projects'            => 'my_projects',
        'add_project_form'       => 'add_project_form',
        'add_project'            => 'add_project',
        'all_projects'           => 'all_projects',
        'my_reports'             => 'my_reports',
        'my_groups'              => 'my_groups',
        'project_search_form'    => 'project_search_form',
        'add_item_form'          => 'add_item_form',
        'add_item'               => 'add_item',
        'global_reports'         => 'global_reports',
        'add_trackers_form'      => 'add_trackers_form',
        'add_trackers'           => 'add_trackers',
        'group_activity_summary' => 'group_activity_summary',
        'group_plate'            => 'group_plate',
        'clients_summary'        => 'clients_summary',
        'watched_items'          => 'watched_items',
        'delete_client'          => 'delete_client',
        'delete_documents'       => 'delete_documents',
        'delete_item'            => 'delete_item',
        'delete_milestone'       => 'delete_milestone',
        'delete_node'            => 'delete_node',
        'delete_project'         => 'delete_project',
        'add_client_form'        => 'add_client_form',
        'add_client'             => 'add_client',
        'post_form'              => 'post_form',
        'post'                   => 'post',
        'update_item'            => 'update_item',
        'update_item_form'       => 'update_item_form',
        'update_items'           => 'update_items',
        'total_breakdown'        => 'total_breakdown',
        'user_plate'             => 'user_plate',
        'edit_milestone_form'    => 'edit_milestone_form',
        'edit_milestone'         => 'edit_milestone',
        'add_document'           => 'add_document',
        'add_group'              => 'add_group',
        'edit_my_items_form'     => 'edit_my_items_form',
        'project_info'           => 'project_info',
        'project_documents'      => 'project_documents',
        'project_milestones'     => 'project_milestones',
        'update_group'           => 'update_group',
        'add_milestone'          => 'add_milestone',
        'add_services_item'      => 'add_services_item',
        'notify'                 => 'notify',
        'notify_project'         => 'notify_project',
        'update_project'         => 'update_project',
        'update_project_form'    => 'update_project_form',
        'search_forum'           => 'search_forum',
	'keyword'                => 'keyword',
	'document'               => 'document',
        'users'                  => 'users',
        'all_clients'            => 'all_clients',
        'all_groups'             => 'all_groups',
        'group'                  => 'group',
        'client'                 => 'client',
        'milestone'              => 'milestone',
        'user'                   => 'user',
	'project'                => 'project',
        'forum'                  => 'forum',
	'node'                   => 'node',
        'staff_report'           => 'staff_report',
        'project_history'        => 'project_history',
        'new_clients'            => 'new_clients',
        'project_search'         => 'project_search',
        'edit_client'            => 'edit_client',
        'edit_client_form'       => 'edit_client_form',
        'client_search'          => 'client_search',
        'client_search_form'     => 'client_search_form',
        'project_months_report'  => 'project_months_report',
        'user_history'           => 'user_history',
        'weekly_summary'         => 'weekly_summary',
        'monthly_summary'        => 'monthly_summary',
        'forum_archive'          => 'forum_archive',
        'project_weekly_report'  => 'project_weekly_report',
        'user_weekly_report'     => 'user_weekly_report',
        'active_projects_report' => 'active_projects_report',
        'active_clients_report' => 'active_clients_report',
    );
    my $pmt = new PMT();
    my $q = $self->query();
    my $username = $q->cookie('pmtusername') || "";
    my $password = $q->cookie('pmtpassword') || "";

    if ($username eq "") { throw Error::NO_USERNAME; }
    
    $self->{user} = PMT::User->retrieve($username);
    $self->{user}->validate($username,$password);
    

    $self->{pmt} = $pmt;
    $self->{sortby} = $q->param('sortby') || $q->cookie('pmtsort') || "";
    
    $self->{password} = $password;
    $self->{username} = $username;
    $self->{message} = $q->param('message');
    $self->header_props(-charset => 'utf-8');
}

sub template {
    my $self = shift;
    my $template = PMT::Common::get_template(@_);
    $template->param(message => $self->{message});
    $template->param($self->{user}->menu());
    return $template;
}

sub home {
    my $self = shift;
    my $template = $self->template("home.tmpl");
    my $user = $self->{user};
    $template->param($user->home());
    $template->param(clients => $user->clients_data());
    $template->param(page_title => "homepage for " . $user->username);
    my $cgi = $self->query();
    $template->param(items_mode => 1);
    return $template->output();
}

sub edit_my_items_form {
    my $self = shift;
    my $template = $self->template("edit_items.tmpl");
    my $user = $self->{user};
    $template->param($user->quick_edit_data());
    $template->param(page_title => "quick edit items");
    $template->param(items_mode => 1);
    return $template->output();    
}

sub user_settings_form {
    my $self = shift;
    my $user = $self->{user};
    my $template = $self->template("user_settings_form.tmpl");
    $template->param(username => $user->username);
    $template->param(fullname => $user->fullname);
    $template->param(page_title => "update user settings");
    $template->param(settings_mode => 1);
    return $template->output();
}

sub update_user {
    my $self = shift;
    my $user = $self->{user};
    my $cgi = $self->query();
    
    my $new_pass  = $cgi->param('new_pass')  || $self->{password};
    my $new_pass2 = $cgi->param('new_pass2') || $self->{password};
    my $fullname  = $cgi->param('fullname')  || "";
    my $email     = $cgi->param('email')     || "";


    $self->{pmt}->update_user($user->username,$self->{password},$new_pass,$new_pass2,$fullname,$email);

    my $lcookie = $cgi->cookie(-name =>  'pmtusername',
        -value => $user->username,
        -path => '/',
        -expires => '+10y');
    
    my $pcookie = $cgi->cookie(-name => 'pmtpassword',
        -value => $new_pass,
        -path => '/',
        -expires => '+10y');
    $self->header_props(-url =>
        "home.pl?mode=user_settings_form;message=updated");
    $self->header_add(-cookie => [$lcookie,$pcookie]);
    $self->header_type('redirect');
    
    return "redirecting back to form";

}

sub my_projects {
    my $self = shift;
    my $template = $self->template("myprojects.tmpl");

    my $data;
    my $user = $self->{user};
    my $last_mods = PMT::Project->all_projects_by_last_mod();
    my %seen = ();
    my $manager_projects = $user->projects_by_auth('manager');
    $data->{manager_projects} = [map {
        $seen{$_} = 1;
        {
            pid      => $_, 
            name     => $manager_projects->{$_},
            last_mod => $last_mods->{$_},
            proj_cc  => $user->notify_projects($_), 
        };
    } sort {
        lc($manager_projects->{$a}) cmp lc($manager_projects->{$b});
    } keys %{$manager_projects}];

    my $developer_projects = $user->projects_by_auth('developer');
    $data->{developer_projects} = [map {
        $seen{$_} = 1;
        {
	            pid      => $_, 
		    name     => $developer_projects->{$_},
                    last_mod => $last_mods->{$_},
                    proj_cc  => $user->notify_projects($_), 
        };
    } sort {
        lc($developer_projects->{$a}) cmp lc($developer_projects->{$b});
    } grep { !exists $seen{$_} } keys %{$developer_projects}];

    my $guest_projects = $user->projects_by_auth('guest');
    $data->{guest_projects} = [map {
        {
	            pid      => $_, 
		    name     => $guest_projects->{$_},
                    last_mod => $last_mods->{$_},
                    proj_cc  => $user->notify_projects($_), 
        };
    } sort {
        lc($guest_projects->{$a}) cmp lc($guest_projects->{$b});
    } grep { !exists $seen{$_} } keys %{$guest_projects}];

    
    $template->param($data);
    $template->param('projects_mode' => 1);
    $template->param(page_title => "my projects");
    
    return $template->output();
}

sub add_project_form {
    my $self = shift;
    my $user = $self->{user};
    my $template = $self->template("add_project.tmpl");
    $template->param(projects_mode => 1);
    $template->param(page_title => "Add Project");
    return $template->output();
}

sub add_project {
    my $self = shift;
    my $cgi = $self->query();
    my $name        = escape($cgi->param("name"))        || throw Error::NO_NAME "no name specified";
    my $year        = $cgi->param('year')        || "";
    my $month       = $cgi->param('month')       || "";
    my $day         = $cgi->param('day')         || "";
    my $description = escape($cgi->param('description')) || "";
    my $pub_view    = $cgi->param('pub_view')    || 'true';
    my $wiki_category = $cgi->param('wiki_category') || $name;

    $wiki_category =~ s{/}{}g;
    $pub_view = $pub_view eq "private" ? "false" : "true";

    my $target_date = $cgi->param('target_date');
    if($target_date =~ /(\d{4}-\d{2}-\d{2})/) {
        $target_date = $1;
    } else {
        throw Error::INVALID_DATE "malformed date";
    }

    my $project = PMT::Project->create({name => $name, pub_view => $pub_view,
					caretaker => $self->{user}, description => $description,
					status => 'planning', wiki_category => $wiki_category});
    my $manager = PMT::WorksOn->create({username => $self->{user}->username, pid => $project->pid, auth => 'manager'});

    $project->add_milestone("Final Release",$target_date,"project completion");

    $self->header_type('redirect');
    $self->header_props(-url => "home.pl?mode=project;pid=" . $project->pid);
    return "redirecting to new project page";
}

sub all_projects {
    my $self = shift;
    my $user = $self->{user};
    my $template = $self->template("projects.tmpl");
    $template->param(projects => $user->all_projects());
    $template->param(projects_mode => 1);
    $template->param(page_title => 'All Projects');
    return $template->output();
}

sub my_reports {
    my $self = shift;
    my $user = $self->{user};
    my $template = $self->template("my_reports.tmpl");
    $template->param(page_title => "reports for " . $user->username);
    $template->param(reports_mode => 1);
    return $template->output();
}

sub global_reports {
    my $self = shift;
    my $user = $self->{user};
    my $template = $self->template("global_reports.tmpl");
    $template->param(reports_mode => 1);
    $template->param(page_title => "global reports");
    my $pmt = $self->{pmt};
    $template->param(groups => PMT::User->groups());
    return $template->output();
}


sub my_groups {
    my $self = shift;
    my $user = $self->{user};
    my $template = $self->template("my_groups.tmpl");
    $template->param(users_mode => 1);
    $template->param(groups => $user->user_groups());
    $template->param(page_title => "Groups for $user->username");
    return $template->output();
}

sub project_search_form {
    my $self = shift;
    my $user = $self->{user};
    my $pmt = $self->{pmt};
    my $template = $self->template("project_search_form.tmpl");
    $template->param(types_select => PMT::Project::types_select(),
        areas_select => PMT::Project::areas_select(),
        approaches_select => PMT::Project::approaches_select(),
        scales_select => PMT::Project::scales_select(),
        distributions_select => PMT::Project::distribs_select(),
        managers_select => PMT::WorksOn->works_on_select("manager"),
        developers_select => PMT::WorksOn->works_on_select("developer"),
        guests_select => PMT::WorksOn->works_on_select("guest"),
        status_select => PMT::Project::status_select(),
    );
    $template->param(projects_mode => 1);
    $template->param(page_title => "Project Search");
    return $template->output();
}

sub add_item_form {
    my $self = shift;
    my $user = $self->{user};
    my $cgi = $self->query();
    my $pid = $cgi->param('pid');
    my $type = $cgi->param('type');
    
    my $template = $self->template("add_item.tmpl");
    my $project = PMT::Project->retrieve($pid);
    $template->param($project->add_item_form($type, $self->{username}));
    use Date::Calc qw/Week_of_Year Monday_of_Week Add_Delta_Days/;
    my ($year,$mon,$mday) = todays_date();
    my ($mon_year,$mon_month,$mon_day) = Monday_of_Week(Week_of_Year($year,$mon,$mday));
    # backdated stuff goes in on sundays
    my ($p_year,$p_month,$p_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,-1);
    my ($pp_year,$pp_month,$pp_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,-8);
    my %data;
    $data{total_remaining_time} = interval_to_hours($project->estimated_time);
    $data{total_completed_time} = interval_to_hours($project->completed_time);
    $data{total_estimated_time} = interval_to_hours($project->all_estimated_time);

    $template->param(\%data);
    $template->param(p_week => "$p_year-$p_month-$p_day",
                     pp_week => "$pp_year-$pp_month-$pp_day");
    $template->param(items_mode => 1);
    $template->param(page_title => "Add $type");
    return $template->output();
}

sub add_item {
    my $self = shift;
    my $user = $self->{user};
    my $cgi = $self->query();
    my $pmt = $self->{pmt};

    my $username = $user->username;

    my $type         = $cgi->param('type') || throw Error::NO_TYPE "type is necessary";
    my $pid          = $cgi->param('pid') || throw Error::NO_PID "no project specified";
    my $mid          = $cgi->param('mid') || "";
    if ($mid eq "") {
	my $project = PMT::Project->retrieve($pid);
	$mid = $project->upcoming_milestone();
    }
    my $title = escape($cgi->param('title')) || "no title";
    
    #Min's changes to implement multiple assignees to an action item
    #my $assigned_to  = $cgi->param('assigned_to') || "";
    my @assigned_to  = $cgi->param('assigned_to');
    my $owner        = $cgi->param('owner') || $username;
    my $priority     = $cgi->param('priority') || "";
    my $year         = $cgi->param('year') || "";
    my $month        = $cgi->param('month') || "";
    my $day          = $cgi->param('day') || "";
    my $url          = escape($cgi->param('url')) || "";
    my $description  = $cgi->param('description') || "";
    my $new_keywords = $cgi->param('new_keywords') || "";
    my @keywords     = $cgi->param('keywords');
    my @dependencies = $cgi->param('depends');
    my @clients      = $cgi->param('clients');
    my $completed    = $cgi->param('completed') || "";


    my $target_date = $cgi->param('target_date') || "";
    my $estimated_time = $cgi->param('estimated_time') || "";

    if($target_date =~ /(\d{4}-\d{2}-\d{2})/) {
	$target_date = $1;
    } else {
	my $milestone = PMT::Milestone->retrieve($mid);
	$target_date = $milestone->target_date;
    }
    if ($estimated_time =~ /^(\d+)$/) {
        $estimated_time .= "h";
    }
    if ($estimated_time eq "") {
        $estimated_time = "0h";
    }
    push @keywords, split /\n/, $new_keywords;
    @keywords = map {escape($_);} @keywords;

    my @new_keywords;
    foreach my $k (@keywords) {
	push @new_keywords, $k unless $k eq "";
    }

    my @new_dependencies;
    foreach my $d (@dependencies) {
	push @new_dependencies, $d unless $d eq "";
    }
    my @new_clients;
    foreach my $client (@clients) {
	push @new_clients, $client unless $client eq "";
    }

    if($type eq "tracker") {
	my $resolve_time = $cgi->param('time') || "1 hour";
	if($resolve_time =~ /^(\d+)$/) {
	    # default to hours if now unit is specified
	    $resolve_time = "$1"."h";
	}
	$pmt->add_tracker(pid => $pid,
			  mid => $mid,
			  title => $title,
			  'time' => $resolve_time,
			  target_date => $target_date,
			  owner => $username,
			  completed => $completed,
			  clients => \@new_clients);
    } elsif ($type eq "todo") {
	$pmt->add_todo(pid => $pid,
		       mid => $mid,
		       title => $title,
		       target_date => $target_date,
		       owner => $username);
    } else {
	foreach my $assignee (@assigned_to) {

	    my %item = (type         => $type,
	                pid          => $pid,
		        mid          => $mid,
		        title        => $title,
		        assigned_to  => $assignee,
		        owner        => $owner,
		        priority     => $priority,
		        target_date  => $target_date,
		        url          => $url,
		        description  => $description,
		        keywords     => \@new_keywords,
		        dependencies => \@new_dependencies,
		        clients      => \@new_clients,
		        estimated_time => $estimated_time);
	    $pmt->add_item(\%item);
	}
	$type =~ s/\s/%20/g;
    }
    # put the user back at the add item for for the same type/project
    # so they can conveniently add multiple items
    $self->header_type('redirect');
    $self->header_props(-url => "home.pl?mode=add_item_form;type=$type;pid=$pid");
    return "redirecting back to add item form";

}

sub add_trackers_form {
    my $self = shift;
    my $user = $self->{user};
    my $template = $self->template("add_trackers.tmpl");
    $template->param(items_mode => 1);
    $template->param(page_title => "Add Trackers");
    return $template->output();
}

sub add_trackers {
    my $self = shift;
    my $user = $self->{user};
    my $cgi = $self->query();
    my $pmt = $self->{pmt};
    my @trackers = ();
    foreach my $i (1..10) {
        my $pid = $cgi->param("pid$i") || "";
        my $title = $cgi->param("title$i") || "";
        my $time = $cgi->param("time$i") || "1 hour";

        if ($time =~ /^(\d+)$/) {
            $time = "$1"."h";
        }

        if ($time ne "" && $title ne "") {
            push @trackers, {pid => $pid, title => $title, "time" =>
                $time};
        }
    }
    foreach my $t (@trackers) {
        my $project = PMT::Project->retrieve($t->{pid});
        my $mid = $project->upcoming_milestone();
        my $milestone = PMT::Milestone->retrieve($mid);
        my $target_date = $milestone->target_date;
        $pmt->add_tracker(pid => $t->{pid},
            mid => $mid, title => $t->{title}, "time" => $t->{time},
            target_date => $target_date, owner => $user->username,
            completed => "", clients => []);
        
    }
    $self->header_type('redirect');
    $self->header_props(-url => "home.pl?mode=add_trackers_form");
    return "redirecting back to add trackers form";
}

sub get_end_date {
    my $self = shift;
    my $cgi = shift;
    my $end_date = $cgi->param('end_date') || "";
    my ($year,$month,$day);
    if ($end_date =~ /^(\d\d\d\d)-(\d+)-(\d+)$/) {
        # passed in as one
        ($year,$month,$day) = ($1, $2, $3);
    } else {
        # passed in individually
        $year  = $cgi->param('end_year')  || "";
        $month = $cgi->param('end_month') || "";
        $day   = $cgi->param('end_day')   || "";
    
        unless ($year && $month && $day) {
            # otherwise, default to today
            ($year,$month,$day) = todays_date();
        }
    }
    $month = sprintf "%02d", $month;
    $day = sprintf "%02d", $day;
    return ($year,$month,$day);
}

sub get_start_date {
    my $self = shift;
    my $cgi = shift;
    my $start_date = $cgi->param('start_date') || "";
    my ($year,$month,$day);
    if ($start_date =~ /^(\d\d\d\d)-(\d+)-(\d+)$/) {
        # passed in as one
        ($year,$month,$day) = ($1, $2, $3);
    } else {
        # passed in individually
        $year  = $cgi->param('start_year')  || "";
        $month = $cgi->param('start_month') || "";
        $day   = $cgi->param('start_day')   || "";
    
        unless ($year && $month && $day) {
            # default to most recent monday
            ($year,$month,$day) = Monday_of_Week(Week_of_Year(todays_date()));
        }
    }
    $month = sprintf "%02d", $month;
    $day = sprintf "%02d", $day;
    return ($year,$month,$day);
}

sub group_activity_summary {
    my $self = shift;
    my $cgi = $self->query();
    my $user = $self->{user};
    my $group_name = $cgi->param('group_name');

    # start date
    my ($start_year, $start_month, $start_day) =
    $self->get_start_date($cgi);
    my $start_date = "$start_year-$start_month-$start_day";
    my ($end_year, $end_month, $end_day) = $self->get_end_date($cgi);
    my $end_date = "$end_year-$end_month-$end_day";

    my $group = PMT::User->retrieve($group_name);
    my %all_users = %{$group->all_users_in_group()};
    my @users = map {
        PMT::User->retrieve($_);
    } keys %all_users;
    my $total_time = 0.0;
    my @users_info = map {
        my $data = $_->data(); 
        my $report = $_->weekly_report($start_date,$end_date);
        $data->{active_projects}  = $report->{active_projects};
        $data->{total_time}       = $report->{total_time};
        $data->{individual_times} = $report->{individual_times};
        $total_time += $report->{total_time};
        $data->{posts} = [map {$_->data()}
        sort { $b->added cmp $a->added}
        PMT::Node->user_posts_in_range($_->username, $start_date, $end_date)];
        $data;
    } @users;
    my $template = $self->template("group_activity_summary.tmpl");
    $template->param(users => \@users_info);
    $template->param(start_year => $start_year, start_month =>
        $start_month, start_day => $start_day, end_year => $end_year,
        end_month => $end_month, end_day => $end_day);
    $template->param(group_name => $group_name);
    $template->param(total_time => $total_time);
    $template->param(group_fullname => $group->fullname);
    $template->param(page_title => "Group Activity Summary");
    return $template->output();
}

sub group_plate {
    my $self = shift;
    my $cgi = $self->query();
    my $user = $self->{user};
    my $group_name = $cgi->param('group_name');
    
    my $group = PMT::User->retrieve($group_name);
    my %all_users = %{$group->all_users_in_group()};
    my @users = map {
        PMT::User->retrieve($_);
    } keys %all_users;
    my $total_time = 0;
    my $total_priorities = {"priority_0" => 0, 
        "priority_1" => 0, "priority_2" => 0, 
        "priority_3" => 0, "priority_4" => 0};
    my $total_schedules = {  
        ok => 0, upcoming => 0, due => 0, overdue => 0, late => 0,
    };
    my $project_totals = {};
    
    my @users_info = map {
        my $data = $_->data();
        my $priorities = $_->estimated_times_by_priority();
        foreach my $pr (qw/0 1 2 3 4/) {
            $data->{"priority_$pr"} = $priorities->{"priority_$pr"} || 0;
            $total_priorities->{"priority_$pr"} += $data->{"priority_$pr"};
        }
        my $schedules = $_->estimated_times_by_schedule_status();
        foreach my $sched (qw/ok upcoming due overdue late/) {
            $data->{$sched} = $schedules->{$sched} || 0;
            $total_schedules->{$sched} += $data->{$sched};
        }

        $data->{total_time} = $_->total_estimated_time() || 0;
        $total_time += $data->{total_time};
        
        my @items = map {$_->data()} PMT::Item->assigned_to_user($_->username);
        $data->{items} = \@items;
        my $projects = $_->estimated_times_by_project();
        $data->{projects} = $projects;
        foreach my $p (@{$projects}) {
            if (exists $project_totals->{$p->{pid}}) {
                $project_totals->{$p->{pid}}->{time} += $p->{time};
            } else {
                $project_totals->{$p->{pid}} = {
                    pid => $p->{pid},
                    time => $p->{time},
                    project => $p->{project},
                }
            }
        }
        $data;
    } @users;
    my @projects = map {$project_totals->{$_}} keys %{$project_totals};
    my $template = $self->template("group_plate.tmpl");
    $template->param(group_name => $group->fullname);
    $template->param(total_time => $total_time,
        users => \@users_info);
    $template->param($total_priorities);
    $template->param($total_schedules);
    $template->param(group_projects => \@projects);
    $template->param(page_title => "on the plate for $group_name");
    $template->param(reports_mode => 1);
    return $template->output();
}

sub clients_summary {
    my $self = shift;
    my $user = $self->{user};
    my $template = $self->template("clients_summary.tmpl");
    my ($year,$month,$day) = todays_date();
    my @month_names  = ("January", "February", "March", "April", "May", 
        "June", "July", "August", "September", "October", "November", "December");
    my ($prev_month, $prev_year) = ($month - 1, $year);
    if ($prev_month < 1) {
        $prev_month = 12;
        $prev_year -= 1;
    }
    $prev_month = sprintf "%02d", $prev_month;
    #my $data = $client->new_clients_for_month($year,$month);
    
    my $current_month_total = 0;
    my %current_month_totals = ();
    my $last_month_total = 0;
    my %last_month_totals = ();
    my $year_total = 0;
    my %year_totals = ();
    my %totals = ();
    my $total = 0;
    
    foreach my $r (@{PMT::Client->total_clients_by_school()}) {
        $total += $r->{count};
        $totals{$r->{school}} = $r->{count};
    }

    foreach my $r (@{PMT::Client->total_clients_by_school_for_month($year,$month)}) {
        $current_month_total += $r->{count};
        $current_month_totals{$r->{school}} = $r->{count};
    }
    
    foreach my $r (@{PMT::Client->total_clients_by_school_for_year($year)}) {
        $year_total += $r->{count};
        $year_totals{$r->{school}} = $r->{count};
    }
    
    my @schools = ();
    foreach my $r (@{PMT::Client->total_clients_by_school_for_month($prev_year,$prev_month)}) {
        $last_month_total += $r->{count};
        push @schools, {school => $r->{school}, 
            current_month_clients => $current_month_totals{$r->{school}},
            last_month_clients => $r->{count},
            year_clients => $year_totals{$r->{school}},
            total => $totals{$r->{school}}
        };
    }

    
    $template->param(year => $year);
    $template->param(current_month_name => $month_names[$month - 1]);
    $template->param(last_month_name => $month_names[$prev_month - 1]);
    $template->param(schools => \@schools);
    $template->param(total_clients => $total);
    $template->param(current_month_clients_total => $current_month_total);
    $template->param(last_month_clients_total => $last_month_total);
    $template->param(year_clients_total => $year_total);
    $template->param(reports_mode => 1);
    $template->param(page_title => "Clients Summary");
    return $template->output();
}

sub watched_items {
    my $self = shift;
    my $user = PMT::User->retrieve($self->{user}->username);
    my $cgi = $self->query();

    my $template = $self->template("watched_items.tmpl");
    $template->param('items_mode' => 1);
    $template->param('page_title' => "watched items");
    $template->param(items => $user->watched_items());
    return $template->output();
}

sub delete_client {
    my $self = shift;
    my $user = $self->{user};
    my $q = $self->query();
    my $client_id = $q->param('client_id');
    my $verify = $q->param('verify') || "";
    if ($verify eq "ok") {
        my $client = PMT::Client->retrieve($client_id);
        my $letter = substr($client->lastname,0,1);
        $client->delete();
        $self->header_type('redirect');
        $self->header_props(-url => "home.pl?mode=all_clients;letter=$letter");
        return "redirecting back to clients page";
    } else {
        return $self->verify_delete_client($client_id);
    }
}

sub verify_delete_client {
    my $self = shift;
    my $client_id = shift;
    return qq{
    <html><head><title>verify</title>
</head>
<body>
<h1>are you sure?</h1>
<p>once a client is deleted, their information is lost permanently. it cannot be recovered. 
please be <em>very</em> sure that you should be deleting the entry.</p>
<form action="home.pl" method="POST">
<input type="hidden" name="mode" value="delete_client"/>
<input type="hidden" name="client_id" value="$client_id"/>
<input type="hidden" name="verify" value="ok"/>
<input type="submit" value="continue deleting client entry"/>
</form>
</body>
</html>
    };
}

sub delete_documents {
    my $self = shift;
    my $q = $self->query();
    my %vars = $q->Vars();
    my @del = map {/^del_(\d+)$/; $1;} grep {/^del_\d+/} keys %vars;
    my $pid = $q->param('pid');
    my $user = undef;
    foreach my $did (@del) {
        my $document = PMT::Document->retrieve($did);
        $user = $document->author();
        $document->delete();
    }
#    if (defined($user)) {
#        $user->dbi_commit();
#    }
    $self->header_type('redirect');
    $self->header_props(-url => "home.pl?mode=project;pid=$pid");
    return "documents deleted";
}

sub delete_item {
    my $self = shift;
    my $cgi = $self->query();
    my $iid = $cgi->param('iid') || "";
    my $item = PMT::Item->retrieve($iid);

    my $really = $cgi->param('verify') || "";
    if ($really eq "") {
        return $self->delete_item_verify($iid);
    } else {
        my $mid = $item->mid->mid;
        $item->delete();
        $self->header_type('redirect');
        $self->header_props(-url => "home.pl?mode=milestone;mid=$mid");
        return "deleted item";
    }
}

sub update_group {
    my $self = shift;
    my $cgi = $self->query();
    my $pmt = $self->{pmt};
    my $group = $cgi->param('group') || "";
    my @users = $cgi->param('users');

    $pmt->update_group($group,\@users);

    $self->header_type('redirect');
    $self->header_props(-url => "home.pl?mode=group;group=$group");
    return "updated group";
}

sub add_milestone {
    my $self = shift;
    my $cgi = $self->query();
    my $pid         = $cgi->param("pid") || throw Error::NO_PID "no project specified";
    my $name        = escape($cgi->param("name")) || throw Error::NO_NAME "no name specified";
    my $year        = $cgi->param('year') || "";
    my $month       = $cgi->param('month') || "";
    my $day         = $cgi->param('day') || "";
    my $description = $cgi->param('description') || "";

    my $target_date = $cgi->param('target_date') || "";
    if($target_date =~ /(\d{4}-\d{2}-\d{2})/) {
	$target_date = $1;
    } else {
	throw Error::INVALID_DATE "malformed date. a date must be specified in YYYY-MM-DD format.";
    }

    my $project = PMT::Project->retrieve($pid);
    $project->add_milestone($name,$target_date,$description);
    $self->header_type('redirect');
    $self->header_props(-url => "home.pl?mode=project;pid=$pid");
}


sub delete_item_verify {
    my $self = shift;
    my $iid = shift;
    return qq{
    <html><head><title>delete item</title>
    </head>
    <body>
    <h2>delete item</h2>
    <form action="home.pl" method="POST">
    <input type="hidden" name="mode" value="delete_item" />
    <input type="hidden" name="verify" value="ok" />
    <input type="hidden" name="iid" value="$iid" />
    <input type="submit" value="delete" /><br />
    <p>(note: once you delete an item, it is GONE. poof! 
    we can't bring it back. so you better be really sure 
    that this is what you want to do.)</p>

    </form>
    </body>
    </html>
    }; #'
    
}

sub delete_milestone {
    my $self = shift;
    my $cgi = $self->query();
    my $mid = $cgi->param('mid') || "";
    $mid =~ s/\D//g;
    unless($mid) {
	print $cgi->redirect("home.pl");
	exit(0);
    }
    my $milestone = PMT::Milestone->retrieve($mid);
    my $really = $cgi->param('verify') || "";
    
    if ($really eq "") {
        return $self->delete_milestone_verify($mid);
    } else {
        my $pid = $milestone->delete_milestone();
        $self->header_type('redirect');
        $self->header_props(-url => "home.pl?mode=project;pid=$pid");
        return "milestone deleted\n";
    }
}

sub delete_milestone_verify {
    my $self = shift;
    my $mid = shift;
    return qq{
    <html><head><title>delete milestone</title>
    </head>
    <body>
    <h2>delete milestone</h2>
    <form action="home.pl" method="POST">
    <input type="hidden" name="mode" value="delete_milestone" />
    <input type="hidden" name="verify" value="ok" />
    <input type="hidden" name="mid" value="$mid" />
    <input type="submit" value="delete" /><br />
    (NOTE: only the manager(s) for the project may delete the milestone. you must delete or move all items attached to the milestone before you can delete it.)
    </form>
    </body>
    </html>
    };
}

sub delete_node {
    my $self = shift;
    my $cgi = $self->query();
    my $nid = $cgi->param('nid') || "";
    my $really = $cgi->param('verify') || "";
    
    if ($really ne "ok") {
        return $self->delete_node_verify($nid);
    } else {
        my $forum = new Forum($self->{username});
        $forum->delete_node($nid);
        $self->header_type('redirect');
        $self->header_props(-url => "home.pl?mode=forum");
        return "deleted node";
    }
}

sub delete_node_verify {
    my $self = shift;
    my $nid = shift;
    return qq{
    <html><head><title>delete node</title>
    </head>
    <body>
    <h2>delete item</h2>
    <form action="home.pl" method="POST">
    <input type="hidden" name="mode" value="delete_node" />
    <input type="hidden" name="verify" value="ok" />
    <input type="hidden" name="nid" value="$nid" />
    <p>warning! deleting can not be reversed.</p>
    <input type="submit" value="delete post" /><br />
    </form>
    </body>
    </html>
    };
}

sub delete_project {
    my $self = shift;
    my $cgi = $self->query();
    my $pid = $cgi->param('pid') || "";
    my $project = PMT::Project->retrieve($pid);
    if($project->project_role($self->{username}) ne "manager") {
	throw Error::PERMISSION_DENIED "only a manager may delete a project";
    }

    my $really = $cgi->param('verify') || "";
    if ($really ne "ok") {
        return $self->delete_project_verify($pid);
    } else {
        $project->delete();
        $self->header_type('redirect');
        $self->header_props(-url => "home.pl");
        return "deleted project";
    }
}


sub delete_project_verify {
    my $self = shift;
    my $pid = shift;
    return qq{
    <html><head><title>delete project</title>
    </head>
    <body>
    <h2>delete project</h2>
    <form action="home.pl" method="POST">
    <input type="hidden" name="mode" value="delete_project" />
    <input type="hidden" name="verify" value="ok" />
    <input type="hidden" name="pid" value="$pid" />
    <input type="submit" value="delete" /><br />
    (NOTE: only the manager(s) for the project may delete the project. <b>WARNING!</b> deleting the project will delete all milestones and items in the project.)
    </form>
    </body>
    </html>
    };
}

sub add_client_form {
    my $self = shift;
    my $cgi = $self->query();
    my $client_email      = $cgi->param('client_email')      || "";
    my $lastname          = $cgi->param('lastname')          || "";
    my $firstname         = $cgi->param('firstname')         || "";
    my $title             = $cgi->param('title')             || "";
    my $registration_date = $cgi->param('registration_date') || "";
    my $department        = $cgi->param('department')        || '';
    my $school            = $cgi->param('school')            || '';
    my $add_affiliation   = $cgi->param('add_affiliation')   || "";
    my $phone             = $cgi->param('phone')             || "";
    my $contact           = $cgi->param('contact')           || "";
    my $comments          = $cgi->param('comments')          || "";

    my $user = $self->{user};
    my $username = $self->{username};
    my $pmt = $self->{pmt};

    my $template = $self->template('add_client.tmpl');

    if ($client_email ne "") {
        my $uni = "";
        if ($client_email =~ /^(\w+)$/) {
            $uni = $1;
        } elsif ($client_email =~ /^(\w+)\@columbia\.edu/) {
            $uni = $1;
        } else {
            $uni = "";
        }
        if ($uni ne "") {
            
            my $ldap = Net::LDAP->new('ldap.columbia.edu') 
                or die "$@";
            $ldap->bind();
            my $mesg = $ldap->search(filter => "(uni=$uni)");
            my @entries = $mesg->all_entries();
            my $entry = $entries[0];

            if($entry) {
                $client_email = $entry->get_value("mail") || "";
                $lastname = $entry->get_value("sn") || "";
                $firstname = $entry->get_value("givenname") || "";
                $title = $entry->get_value("title") || "";
                $department = $entry->get_value("ou") || "nodepartment";
                $phone = $entry->get_value("telephonenumber") || "";
            } else {
                $lastname = $firstname 
                = $title = $department = $phone = "";
            }

            #($school,$department) = split /\s{2,}/, $department;
            $school =~ s/\s+$//;
            $department =~ s/\s+$//;
            
            $phone =~ s/[\n\r]/ /g;
            $phone =~ s/\s+$//;
            $client_email =~ s/\s//g;
            $lastname =~ s/\s+$//;
            $lastname =~ s/^(\w)(\w+)/"$1" . lc($2)/e;
            
            $firstname =~ s/\s+$//;
            $firstname =~ s/^(\w)(\w+)/"$1" . lc($2)/e;
            # eliminate the duplication in the title
            $title =~ s/\s{2,}.*$//;
            
	    my ($year,$mon,$mday) = todays_date();
            my $users_select       = PMT::User::users_select($username);
	    my $schools_select     = PMT::Client->all_schools_select($school);
	    my $departments_select = PMT::Client->all_departments_select($department);
	    my $existing_clients   = PMT::Client->existing_clients($uni,$lastname);
            $template->param(client_email 	=> $client_email,
			     lastname 		=> $lastname,
			     firstname 		=> $firstname,
			     title 		=> $title,
			     department 	=> $department,
			     school 		=> $school,
			     schools_select 	=> $schools_select,
			     departments_select => $departments_select,
			     phone 		=> $phone,
			     users_select 	=> $users_select,
			     year 		=> $year,
			     month 		=> $mon,
			     day 		=> $mday,
			     existing_clients 	=> $existing_clients,
            );
        }
    }
    $template->param(clients_mode => 1);
    $template->param(page_title => 'add client');
    return $template->output();
}

sub add_client {
    my $self = shift;
    my $cgi = $self->query();
    my $client_email      = $cgi->param('client_email')      || "";
    my $lastname          = $cgi->param('lastname')          || "";
    my $firstname         = $cgi->param('firstname')         || "";
    my $title             = $cgi->param('title')             || "";
    my $registration_date = $cgi->param('registration_date') || "";
    my $department        = $cgi->param('department')        || '';
    my $school            = $cgi->param('school')            || '';
    my $add_affiliation   = $cgi->param('add_affiliation')   || "";
    my $phone             = $cgi->param('phone')             || "";
    my $contact_username  = $cgi->param('contact')           || "";
    my $comments          = $cgi->param('comments')          || "";
    $title = substr($title,0,100);
    $phone = substr($phone,0,32);
    if ($client_email ne "" && $lastname ne "") {
        my $contact = PMT::User->retrieve($contact_username);
        my $client = PMT::Client->create({
                lastname          => $lastname,
                firstname         => $firstname,
                title             => $title, 
                department        => $department, 
                school            => $school,
                add_affiliation   => $add_affiliation,
                phone             => $phone,
                email             => $client_email, 
                contact           => $contact,
                comments          => $comments,
                registration_date => $registration_date,
            });
    } 
    $self->header_type('redirect');
    $self->header_props(-url => "home.pl?mode=add_client_form");
}

sub post_form {
    my $self = shift;
    my $user = $self->{user};
    my $template = $self->template("post.tmpl");

    $template->param(page_title => 'post to forum');
    $template->param(forum_mode => 1);
    my $projects = $user->projects_hash();
    my $projs = [map {   
        {pid => $_, name => $projects->{$_}};    
    } sort {     
        lc($projects->{$a}) cmp lc($projects->{$b});     
    } keys %{$projects}];
    $template->param(projects => $projs);
    return $template->output();
}

sub post {
    my $self = shift;
    my $username = $self->{username};
    my $user = $self->{user};
    my $cgi = $self->query();
    my $pid = $cgi->param('pid') || "";
    my $subject  = escape($cgi->param('subject')) || "";
    my $body     = escape($cgi->param('body'))    || "";
    my $type     = $cgi->param('type')            || "";
    my $reply_to = $cgi->param('reply_to')        || "";
    my $preview  = $cgi->param('preview')         || "";

    if ($preview eq "preview") {
        my $tiki = new Text::Tiki;
        my $formatted_body = $tiki->format($body);
        my $template = $self->template("preview.tmpl");
        $template->param(pid => $pid,
            subject => $subject,
            body => $body,
            formatted_body => $formatted_body,
            type => $type,
            reply_to => $reply_to);
        $template->param(forum_mode => 1);
        return $template->output();
    } else {
        my $forum = new Forum($username);
        my $nid = $forum->post(type => $type,pid => $pid,
            subject => $subject,body => $body,
            reply_to => $reply_to);
        $self->header_type('redirect');
        $self->header_props(-url => "home.pl?mode=forum");
    }
}

sub update_items {
    my $self = shift;
    my $user = $self->{user};
    my $cgi = $self->query();
    my %params = $cgi->Vars();
    my $u = PMT::User->retrieve($self->{username});    
    foreach my $k (keys %params) {
        if ($k =~ /^title_(\d+)$/) {
            my $iid = $1;
            my $title = $params{$k} || "no title";
            my $priority = $params{"priority_$iid"};
            my $status = $params{"status_$iid"};
            my $assigned_to = $params{"assigned_to_$iid"};
            my $ass_to = PMT::User->retrieve($assigned_to);                
            my $target_date = $params{"target_date_$iid"};
            my $resolve_time = $params{"resolve_time_$iid"};
            my $i = PMT::Item->retrieve($iid);
            my $r_status = "";
            ($status,$r_status) = split /_/, $status;
            
            if ($resolve_time =~ /^(\d+)$/) {
                $resolve_time .= "h";
            }

            my $changed = 0;
            my $add_notification = 0;
            my $email = 0;
            my $comment = "";

            if (($assigned_to eq $i->owner->username) &&
                ($assigned_to eq $self->{username}) && 
                ($status eq "RESOLVED")) {
                $status = "VERIFIED";
                $r_status = "";
            }

            if ($assigned_to ne $i->assigned_to->username) {
                $changed = 1;
                $add_notification = 1;
                if ($i->status eq "UNASSIGNED") {
                    $status = "OPEN";
                    $comment .= "<b>assigned to $assigned_to</b><br />\n";
                    $i->status("OPEN");
                } else {
                    $comment .= "<b>reassigned to $assigned_to</b><br />\n";
                }
                
                $i->assigned_to($ass_to);
            }

            if ($i->status ne $status) {
                $changed = 1;
                if($status eq "OPEN" && $i->status eq "UNASSIGNED") {
                    $comment .= "<b>assigned to $assigned_to</b><br />\n";
                    $add_notification = 1;
                } elsif ($status eq "OPEN" && $i->status ne "OPEN") {
                    $comment .= "<b>reopened</b><br />\n";
                } elsif ($status eq "RESOLVED" && $i->status ne "RESOLVED") {
                    $comment .= "<b>resolved ${r_status}</b><br />\n";
                    $i->r_status($r_status); # prevent it from re-matching later
                } elsif ($status eq "VERIFIED" && $i->status ne "VERIFIED") {
                    $comment .= "<b>verified</b><br />\n";
                } elsif ($status eq "CLOSED" && $i->status ne "CLOSED") {
                    $comment .= "<b>closed</b><br />\n";
                } elsif ($status eq "INPROGRESS" && $i->status ne "INPROGRESS") {
                    $comment .= "<b>marked in progress</b><br />\n";
                } else {
                    throw Error::INVALID_STATUS "invalid status";
                }
                $i->status($status);
            }

            if ($title ne $i->title) {
                $i->title($title);
                $changed = 1;
                $comment .= "<b>title changed</b><br />\n";
            }

            if ($target_date ne $i->target_date) {
                $i->target_date($target_date);
                $changed = 1;
                $comment .= "<b>target_date changed</b><br />\n";
            }

            if ($priority ne $i->priority) {
                $i->priority($priority);
                $changed = 1;
                $comment .= "<b>priority changed</b><br />\n";
            }

            if ($add_notification) {
                $i->add_cc($ass_to);
            }
            if ($resolve_time) {
                $i->add_resolve_time($u,$resolve_time);
            }
            if ($changed != 0) {
                $i->add_event($status,$comment,$u);
                my $milestone = $i->mid;

                $milestone->update_milestone($u);
		$i->update_email($i->type . " #$iid $title updated", 
                    $comment, $self->{user}->username);
                $i->touch();
                $i->update;
            }
        }
    }
    $self->header_type('redirect');
    $self->header_props(-url => "home.pl");
}

sub total_breakdown {
    my $self = shift;
    my $q = $self->query();
    my $username = $q->param('username') || $self->{username};
    my $user = PMT::User->retrieve($username);

    my $template = $self->template("total_breakdown.tmpl");
    $template->param($user->data());
    $template->param($user->total_breakdown());
    $template->param(total_time => $user->total_completed_time());
    $template->param('reports_mode' => 1);
    $template->param(page_title => "total project breakdown report for $username");
    return $template->output();
}

sub user_plate {
    my $self = shift;
    my $q = $self->query();
    my $username = $q->param('username') || $self->{username};
    my $user = PMT::User->retrieve($username);
    my $u = PMT::User->retrieve($username);
    my $template = $self->template("user_plate.tmpl");
    $template->param($user->data());
    $template->param($u->estimated_times_by_priority());
    $template->param($u->estimated_times_by_schedule_status());
    $template->param(total_time => $u->total_estimated_time());
    my @items = map {$_->data()} PMT::Item->assigned_to_user($username);
    $template->param(items => \@items);
    $template->param(user_projects => $u->estimated_times_by_project());
    $template->param(reports_mode => 1);
    $template->param(page_title => "on the plate for $username");
    return $template->output();
}

sub edit_milestone_form {
    my $self = shift;
    my $cgi = $self->query();
    my $mid = $cgi->param('mid');
    my $username = $self->{username};
    my $user = $self->{user};

    my $milestone = PMT::Milestone->retrieve($mid);
    my %data = %{$milestone->data()};
    my $project = $milestone->pid;
    my $works_on = $project->project_role($username);
    if($works_on){
        $data{$works_on} = 1;
    }
    my $template = $self->template("edit_milestone.tmpl");
    $template->param(\%data);
    $template->param(page_title => "Edit Milestone: $data{name}");
    $template->param(projects_mode => 1);
    return $template->output();
}

sub edit_milestone {
    my $self = shift;
    my $cgi = $self->query();
    my $user = $self->{user};
    my $mid = $cgi->param('mid') || "";
    my $name        = escape($cgi->param('name')) || "[no name]";

    my $milestone = PMT::Milestone->retrieve($mid);

    my $target_date = $cgi->param('target_date') || "";
    my $description = escape($cgi->param('description')) || "";

    $milestone->set(name => $name, target_date => $target_date, 
        description => $description);
    $milestone->update();
    $self->header_type("redirect");
    $self->header_props(-url => "home.pl?mode=milestone;mid=$mid");
}

sub add_document {
    my $self = shift;
    my $cgi = $self->query();
    my $username = $self->{username};
    my $pid = $cgi->param("pid") || throw Error::NO_PID "no project specified";
    my $title = $cgi->param('title') || "[no title]";

    my $url = $cgi->param('url') || "";
    my $filename = $cgi->param('document') || "";
    my $fh = $cgi->upload('document');
    my $description = $cgi->param('description') || "";
    my $version = $cgi->param('version') || "";

    my $did = PMT::Document->add_document(pid => $pid,
					  title => $title,
					  url => $url,
					  filename => $filename,
					  fh => $fh,
					  description => $description,
					  version => $version,
					  author => $username);
    $self->header_type("redirect");
    $self->header_props(-url => "home.pl?mode=project;pid=$pid");
}

sub add_group {
    my $self = shift;
    my $cgi = $self->query();
    my $group = $cgi->param('group') || "";
    $group = $self->{pmt}->add_group($group);
    $self->header_type("redirect");
    $self->header_props(-url => "home.pl?mode=group;group=$group");
}

sub project_info {
    my $self = shift;
    my $cgi = $self->query();
    my $pid = $cgi->param('pid');
    my $project = PMT::Project->retrieve($pid);
    my %data = %{$project->data()};
    my $caretaker = $project->caretaker;
    my $works_on = $project->project_role($self->{username});
    if ($works_on) {
        $data{$works_on} = 1;
    }

    $data{caretaker_fullname} = $caretaker->fullname;
    $data{managers}             = [map {$_->data()} $project->managers()];
    $data{developers}           = [map {$_->data()} $project->developers()];
    $data{guests}               = [map {$_->data()} $project->guests()];
    $data{clients}              = $project->clients_data();
    $data{keywords}             = $project->keywords();
    $data{total_remaining_time} = interval_to_hours($project->estimated_time);
    $data{total_completed_time} = interval_to_hours($project->completed_time);
    $data{total_estimated_time} = interval_to_hours($project->all_estimated_time);


    my $template = $self->template("project_info.tmpl");
    $template->param(\%data);
    $template->param(page_title => "project: $data{name}");
    $template->param(projects_mode => 1);
    
    return $template->output();
}

sub project_documents {
    my $self = shift;
    my $cgi = $self->query();
    my $pid = $cgi->param('pid');
    my $project = PMT::Project->retrieve($pid);
    my $template = $self->template("project_documents.tmpl");
    my %data = %{$project->data()};
    $data{total_remaining_time} = interval_to_hours($project->estimated_time);
    $data{total_completed_time} = interval_to_hours($project->completed_time);
    $data{total_estimated_time} = interval_to_hours($project->all_estimated_time);

    $template->param(\%data);
    $template->param(projects_mode => 1);
    $template->param(documents => [map {$_->data()} $project->documents()]);
    $template->param(page_title => "project documents");
    return $template->output();
}

sub project_milestones {
    my $self = shift;
    my $cgi = $self->query();
    my $pid = $cgi->param('pid');
    my $project = PMT::Project->retrieve($pid);
    my $data = $project->data();
    $data->{milestones} = $project->project_milestones("priority");
    $data->{total_remaining_time} = interval_to_hours($project->estimated_time);
    $data->{total_completed_time} = interval_to_hours($project->completed_time);
    $data->{total_estimated_time} = interval_to_hours($project->all_estimated_time);

    my $template = $self->template("project_milestones.tmpl");
    $template->param(projects_mode => 1);
    $template->param(page_title => "project milestones");
    $template->param($data);
    return $template->output();
}

sub add_services_item {
    my $self = shift;
    my $cgi = $self->query();
    my $pmt = $self->{pmt};
    my $user = $self->{user};
    my $pid = $cgi->param('pid');
    my $type = $cgi->param('type') || "tracker";
    my $client_id = $cgi->param('client_id') || die "no client specified";
    
    my $template = $self->template("add_courseworks_item.tmpl");

    my $client = PMT::Client->retrieve($client_id);
    my $client_data = $client->data();
    my $project = PMT::Project->retrieve($pid);
    my %data = %{$project->data()};
    
    $data{developers}        	= [map {$_->data()} $project->developers()];
    $data{keywords}             = $project->keywords();


    $data{'milestone_select'} = $project->project_milestones_select();
    $data{'keywords'}     = $project->keywords();
    $data{'dependencies'} = $project->all_items_in_project();
    my $caretaker = $project->caretaker->username;
    $data{'developers'}   = [map {{
            username => $_->username, fullname => $_->fullname,
            caretaker => ($caretaker eq $_->username),
        };
    }
    $project->all_personnel_in_project()];
    $data{'type'}         = $type;
    $data{'on_project'}   = $project->project_role($user->username);
    $data{'client_id'}    = $client_id;
    $data{'client_lastname'} = $client_data->{'lastname'};
    $data{'client_firstname'} = $client_data->{'firstname'};
    my $owner = $user;
    $data{'owner_select'} = $project->owner_select($owner);
    $data{$type}          = 1;
    $template->param(\%data);


    use Date::Calc qw/Week_of_Year Monday_of_Week Add_Delta_Days/;
    my ($year,$mon,$mday) = todays_date();
    my ($mon_year,$mon_month,$mon_day) = Monday_of_Week(Week_of_Year($year,$mon,$mday));
    # backdated stuff goes in on sundays
    my ($p_year,$p_month,$p_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,-1);
    my ($pp_year,$pp_month,$pp_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,-8);

    $template->param(p_week => "$p_year-$p_month-$p_day",
                     pp_week => "$pp_year-$pp_month-$pp_day");

    return $template->output();
}

sub notify {
    my $self = shift;
    my $cgi = $self->query();
    my $user = $self->{user};
    my $iid = $cgi->param('iid');
    my $item = PMT::Item->retrieve($iid);

    my $notify = $cgi->param('email_notification');

    if($notify eq "yes") {
        $item->add_cc($user);
    } else {
        $item->drop_cc($user);
    }
    $self->header_type('redirect');
    $self->header_props(-url => "item.pl?iid=$iid");
    return "changed notification for an item";
}

sub notify_project {
    my $self = shift;
    my $cgi = $self->query();
    my $pmt = $self->{pmt};
    my $user = $self->{user};
    my $pid = $cgi->param('pid');
    my $project = PMT::Project->retrieve($pid);

    my $notify_proj = $cgi->param('proj_notification');

    if($notify_proj eq "yes") {
        $project->add_cc($user);
    } else {
        $project->drop_cc($user);
    }
    $self->header_type('redirect');
    $self->header_props(-url => "home.pl?mode=project;pid=$pid");
    return "updated project notification";
}

sub update_project {
    my $self = shift;
    my $cgi = $self->query();
    my $user = $self->{user};
    my $username = $user->username;
    my $pmt = $self->{pmt};
    my $pid = $cgi->param('pid');
    my $name        = escape($cgi->param('name')) || "";


    my $description = escape($cgi->param('description')) || "";
    my $caretaker   = escape($cgi->param('caretaker')) || "";
    my $pub_view    = ($cgi->param('pub_view') eq "public") ? 't' : 'f';
    my @managers    = $cgi->param('managers');
    my @developers  = $cgi->param('developers');
    my @guests      = $cgi->param('guests');
    my @clients     = $cgi->param('clients');
    my $status      = $cgi->param('status');
    my $projnum     = $cgi->param('projnum')    || "";
    my $type        = $cgi->param('type')       || "";
    my $area        = $cgi->param('area')       || "";
    my $url 	    = $cgi->param('url')        || "";
    my $restricted  = $cgi->param('restricted') || "";
    my $approach    = $cgi->param('approach')   || "";
    my $info_url    = $cgi->param('info_url')   || "";
    my $entry_rel   = $cgi->param('entry_rel')  || "";
    my $eval_url    = $cgi->param('eval_url')   || "";
    my $scale 	    = $cgi->param('scale')      || "";
    my $distrib     = $cgi->param('distrib')    || "";
    my $poster      = $cgi->param('poster')     || "";

    $pmt->edit_project(pid 	   => $pid,
		       name 	   => $name,
		       description => $description,
		       caretaker   => $caretaker,
		       managers    => \@managers,
		       developers  => \@developers,
		       guests 	   => \@guests,
		       clients     => \@clients,
		       pub_view    => $pub_view,
		       status 	   => $status,
		       projnum 	   => $projnum,
		       type 	   => $type,
		       area 	   => $area,
		       url 	   => $url,
		       restricted  => $restricted,
		       approach    => $approach,
		       info_url    => $info_url,
		       entry_rel   => $entry_rel,
		       eval_url    => $eval_url,
		       scale 	   => $scale,
		       distrib 	   => $distrib,
		       poster      => $poster,
		       );

    $self->header_type('redirect');
    $self->header_props(-url => "home.pl?mode=project;pid=$pid");
    return "updated project info";
}

sub update_project_form {
    my $self = shift;
    my $cgi = $self->query();
    my $pid = $cgi->param('pid');
    my $pmt = $self->{pmt};
    my $user = $self->{user};
    my $username = $user->username;

    my ($year,$mon,$day) = todays_date();

    my $sortby = $cgi->param('sortby') || $cgi->cookie("pmtsort") || "priority";
    my $project = PMT::Project->retrieve($pid);

    my %data = %{$project->data()};
    $data{managers}             = [map {$_->data()} $project->managers()];
    $data{developers}           = [map {$_->data()} $project->developers()];
    $data{guests}               = [map {$_->data()} $project->guests()];
    $data{caretaker_select}     = $project->caretaker_select();
    $data{all_non_personnel}    = $project->all_non_personnel_select();
    $data{keywords}             = $project->keywords();
    $data{statuses}             = $project->status_select();
    $data{approaches}           = $project->approaches_select();
    $data{scales}               = $project->scales_select();
    $data{distribs}             = $project->distribs_select();
    $data{areas}                = $project->areas_select();
    $data{restricteds}          = $project->restricteds_select();
    $data{types}                = $project->types_select();
    $data{clients}              = $project->clients_data();
    $data{clients_select}       = $project->clients_select();
    $data{all_non_clients}      = $project->all_non_clients_select();
    $data{total_remaining_time} = interval_to_hours($project->estimated_time);
    $data{total_completed_time} = interval_to_hours($project->completed_time);
    $data{total_estimated_time} = interval_to_hours($project->all_estimated_time);

    my $works_on = $project->project_role($username);
    if($works_on) {$data{$works_on} = 1;}
    my $template = $self->template("edit_project.tmpl");
    $template->param(\%data);
    $template->param(page_title => "edit project: $data{name}",
		     month      => $mon,
		     year       => $year);
    my $proj = PMT::Project->retrieve($pid);
    $template->param(documents => [map {$_->data()} $proj->documents()]);
    $template->param(projects_mode => 1);

    return $template->output();

}

sub search_forum {
    my $self = shift;
    my $pmt = $self->{pmt};
    my $user = $self->{user};
    my $username = $user->username;
    my $cgi = $self->query();
    my $forum = new Forum($username);
    my $search = $cgi->param('searchWord') || "";

    my $template = $self->template("searchForum.tmpl");
    $template->param(result => PMT::Node->search_forum($search));
    $template->param(page_title => 'Search Forum');
    $template->param(forum_mode => 1);
    print $cgi->header(-charset => 'utf-8'), $template->output();

}

sub keyword {
    my $self = shift;
    my $cgi = $self->query();
    my $pmt = $self->{pmt};
    my $user = $self->{user};
    my $username = $user->username;
    my $keyword = $cgi->param('keyword') || "";
    my $pid     = $cgi->param('pid')     || "";

    my $template = $self->template("keyword.tmpl");

    $template->param(PMT::Keyword::keyword_data($keyword,$pid));

    return $template->output();

}

sub document {
    my $self = shift;
    my $cgi = $self->query();
    my $did = $cgi->param('did') || "";
    my $document = PMT::Document->retrieve($did);

    if($document->type eq "url") {
	$self->header_type('redirect');
	$self->header_props(-url => $document->url);
	return "redirecting to url";
    } else {
        my $content_type = $document->content_type();
        if($document->content_disposition()) {
            my $filename = $document->filename;
	    $self->header_props(-type => $content_type,
                               -content_disposition => "attachment;filename=$filename");
        } else {
            $self->header_props(-type => $content_type);
        }
        return $document->contents();
    }
}

sub update_item_form {
    my $self = shift;
    my $cgi = $self->query();
    my $iid = $cgi->param('iid');
    my $pmt = $self->{pmt};
    my $user = $self->{user};


    my $item = PMT::Item->retrieve($iid);
    my $r = $item->full_data();
    my %data = %$r;
    my $project = PMT::Project->retrieve($data{'pid'});
    $data{$project->project_role($user->username)} = 1;
    my $template = $self->template("edit_item.tmpl");
    $template->param(\%data);
    $template->param(page_title => "Edit Item: $data{title}");
    $template->param(cc => $item->cc($user));
    return $template->output();
}

sub update_item {
    my $self = shift;
    my $cgi = $self->query();
    my $iid = $cgi->param('iid') || "";

    my $user = $self->{user};
    my $pmt = $self->{pmt};
    my $username = $user->username;

    my $status = $cgi->param('status') || "";

    my $r_status = "";
    ($status,$r_status) = split /_/, $cgi->param('status');

    my $type         = $cgi->param('type') || "";
    my $mid          = $cgi->param('mid') || "";
    my $title        = escape($cgi->param('title')) || "no title";
    my $assigned_to  = $cgi->param('assigned_to') || "";
    my $owner        = $cgi->param('owner') || "";
    my $priority     = $cgi->param('priority') || "";
    my $url          = escape($cgi->param('url')) || "";
    my $description  = $cgi->param('description') || "";
    my $new_keywords = $cgi->param('new_keywords') || "";
    my @keywords     = $cgi->param('keywords');
    my @dependencies = $cgi->param('depends');
    my @clients      = $cgi->param('clients');
    my $target_date  = $cgi->param('target_date') || PMT::Milestone->retrieve($mid)->target_date;
    my $comment      = escape($cgi->param('comment')) || "";
    my $resolve_time = $cgi->param('resolve_time') || "";
    my $client_uni   = $cgi->param('client_uni') || "";

    if($resolve_time =~ /^(\d+)$/) {
        # default to hours if no unit was specified.
        $resolve_time .= "h";
    }
    my $estimated_time = $cgi->param('estimated_time') || "01:00";
    if($estimated_time =~ /^(\d+)$/) {
        $estimated_time .= "h";
    }



    push @keywords, split /\n/, $new_keywords;
    @keywords = map {escape($_);} @keywords;

    my @new_keywords;
    foreach my $k (@keywords) {
        push @new_keywords, $k unless $k eq "";
    }

    my @new_deps;
    foreach my $d (@dependencies) {
        push @new_deps, $d unless $d eq "";
    }

    my @new_clients;
    foreach my $c (@clients) {
        push @new_clients, $c unless $c eq "";
    }

    my %item = (type         => $type,
                iid          => $iid,
                mid          => $mid,
                title        => $title,
                assigned_to  => $assigned_to,
                owner        => $owner,
                priority     => $priority,
                target_date  => $target_date,
                url          => $url,
                description  => $description,
                keywords     => \@new_keywords,
                dependencies => \@new_deps,
                clients      => \@new_clients,  
                client_uni   => $client_uni,
                status       => $status,
                r_status     => $r_status,
                resolve_time => $resolve_time,
                estimated_time => $estimated_time,
                comment      => $comment);

    use URI::Escape;

    my $message = URI::Escape::uri_escape($pmt->update_item(\%item,$username));
    $self->header_type('redirect');
    $self->header_props(-url => "item.pl?iid=$iid;message=$message");
    return $message;
}

sub users {
    my $self = shift;
    my $template = $self->template("users.tmpl");
    
    $template->param(users => PMT::User->users_hours());
    $template->param(page_title => "users");
    $template->param(users_mode => 1);
    return $template->output();

}

sub all_clients {
    my $self = shift;
    my $cgi = $self->query();
    my $letter = $cgi->param('letter') || "A";

    my @letters = map {{"letter" => $_,
                        "current" => $_ eq $letter}} 'A'..'Z';

    my $template = $self->template("clients.tmpl");
    $template->param(clients => [map {
        $_->{inactive} = $_->{status} eq "inactive";
        $_;
    } @{PMT::Client->all_clients_data($letter)}]);
    $template->param('letters' => \@letters);
    $template->param(clients_mode => 1);
    $template->param(page_title => "All clients ($letter)");
    return $template->output();
}

sub all_groups {
    my $self = shift;
    my $pmt = $self->{pmt};
    my $template = $self->template('groups.tmpl');
    $template->param(groups => PMT::User->groups());
    $template->param(page_title => "Groups");
    $template->param(users_mode => 1);
    return $template->output();
}

sub group {
    my $self = shift;
    my $cgi = $self->query();
    my $pmt = $self->{pmt};
    my $group = $cgi->param('group') || "";
    my $template = $self->template('group.tmpl');
    $template->param($pmt->group($group));
    $template->param(page_title => "Group: $group");
    $template->param(users_mode => 1);
    return $template->output();
}

sub client {
    my $self = shift;
    my $cgi = $self->query();
    my $client_id = $cgi->param('client_id') || "";
    my $client = PMT::Client->retrieve($client_id);

    # how about a polite error for a non-existent client ID?
    if (! $client) {
      return("<html><body><h1>Client ID #$client_id was not found in the database.</h1><br>Please press 'back' in your browser controls to continue using the PMT in this window and/or tab.</body></html>");
    }

    my $contact = $client->contact;

    my $template = $self->template("client.tmpl");
    my $data     = $client->data();
    $data->{client_email} = $data->{email};
    $data->{active} = $data->{status} eq "active";
    $template->param(contact_fullname => $contact->fullname);
    delete $data->{email};
    $template->param(%{$data});
    $template->param(client_projects => $client->projects_data(),
                     projects_select => $client->projects_select(),
                     contacts_select => $client->contacts_select(),
                     recent_items => $client->recent_items());
    $template->param(clients_mode => 1);
    
    $template->param(client_prev => $client->prev_client());
    $template->param(client_next => $client->next_client());
    
    return $template->output();
}

sub milestone {
    my $self = shift;
    my $cgi = $self->query();
    my $mid    = $cgi->param('mid')    || "";

    my $milestone = PMT::Milestone->retrieve($mid);
    my %data = %{$milestone->data()};

    $data{'items'} = [map {$_->data()} $milestone->items()];
    $data{'total_estimated_time'} = $milestone->estimated_time();
    my $project = $milestone->pid;
    my $works_on = $project->project_role($self->{user}->username);
    if($works_on){
        $data{$works_on} = 1;
    }
    my $template = $self->template("milestone.tmpl");
    $data{total_remaining_time} = interval_to_hours($project->estimated_time);
    $data{total_completed_time} = interval_to_hours($project->completed_time);
    $data{total_estimated_time} = interval_to_hours($project->all_estimated_time);

    ($data{done},$data{todo},$data{free},$data{completed_behind},$data{behind}) = $project->estimate_graph(150);
    $template->param(\%data);
    $template->param(page_title => "Milestone: $data{name}");
    $template->param(projects_mode => 1);
    return $template->output();
}

sub user {
    my $self = shift;
    my $cgi = $self->query();
    my $pmt = $self->{pmt};
    my $login = $self->{user}->username;
    my ($year,$mon,$day) = todays_date();

    my $username = $cgi->param('username') || "";
    my $sortby   = $cgi->param('sortby')   || "priority";

    my $viewing_user = PMT::User->retrieve($username);

    my $template = $self->template("user.tmpl");
    my $data = $viewing_user->data();
    $data->{user_username} = $data->{username};
    $data->{user_fullname} = $data->{fullname};
    $data->{user_email} = $data->{email};
    delete $data->{username};
    delete $data->{fullname};
    delete $data->{email};
    delete $data->{status};
    throw Error::NonexistantUser "user does not exist" 
        unless $data->{user_username};
    my $vu = PMT::User->retrieve($username);
    if ($data->{group}) {
        $data->{users} = $pmt->users_in_group($username);
    } else {
        $data->{groups} = $vu->user_groups();
    }

    $data->{total_estimated_time} = $vu->total_estimated_time();
    $template->param(%$data);
    $template->param(items => $vu->items($login,$sortby));
    $template->param(page_title => "user info for $username");
    $template->param(month => $mon, year => $year);
    $template->param(users_mode => 1);
    return $template->output();
}

sub project {
    my $self = shift;
    my $cgi = $self->query();
    my $username = $self->{user}->username;
    my ($year,$mon,$day) = todays_date();
    my $pid    = $cgi->param('pid') || "";
    my $sortby = $cgi->param('sortby') || $cgi->cookie("pmtsort") || "priority";
    my $project = PMT::Project->retrieve($pid);
    my $works_on = $project->project_role($username);
    my %data = %{$project->data()};
    my $caretaker = $project->caretaker;

    $data{caretaker_fullname}   = $caretaker->fullname;
    $data{milestones}           = $project->project_milestones($sortby, $username);
    $data{managers}             = [map {$_->data()} $project->managers()];
    $data{developers}           = [map {$_->data()} $project->developers()];
    $data{guests}               = [map {$_->data()} $project->guests()];
    $data{keywords}             = $project->keywords();
    $data{total_remaining_time} = interval_to_hours($project->estimated_time);
    $data{total_completed_time} = interval_to_hours($project->completed_time);
    $data{total_estimated_time} = interval_to_hours($project->all_estimated_time);

    my $table_width = 150;
    ($data{done},$data{todo},$data{free},$data{completed_behind},$data{behind}) = $project->estimate_graph($table_width)
;

    if($works_on) {$data{$works_on} = 1;}
    my $template = $self->template("project.tmpl");
    $template->param(\%data);

    $template->param(proj_cc => $project->cc(PMT::User->retrieve($username)));
    $template->param(page_title => "project: $data{name}",
                     month      => $mon,
                     year       => $year);
    
    my $proj = PMT::Project->retrieve($pid);
    $template->param(documents => [map {$_->data()} $proj->documents()]);
    $template->param(projects_mode => 1);
    $self->header_add(-cookie => [$cgi->cookie(-name => "pmtsort",
					       -value => $sortby,
					       -path => '/',
					       -expires => "+10y")]);
    return $template->output();

}

sub forum {
    my $self = shift;
    my $cgi = $self->query();
    my $username = $self->{user}->username;
    my $pmt = $self->{pmt};
    my $pid = $cgi->param('pid') || "";
    my $forum = new Forum($username);
    my $template = $self->template("forum.tmpl");
    if($pid) {
	my $project = PMT::Project->retrieve($pid);
        $template->param(posts => $forum->recent_project_posts($pid));
        $template->param(logs => $project->recent_project_logs());
        $template->param(items => $forum->recent_project_items($pid));
        $template->param(pid => $pid);
    } else {
        $template->param(posts => PMT::Node->recent_posts($username));
        $template->param(logs => $forum->recent_logs());
        $template->param(items => PMT::Item->recent_items());
    }
    $template->param(page_title => 'forum');
    $template->param(forum_mode => 1);
    return $template->output();
}



sub node {
    my $self = shift;
    my $cgi = $self->query();
    my $pmt = $self->{pmt};
    my $nid = $cgi->param('nid') || "";
    my $template = $self->template("node.tmpl");
    $template->param(PMT::Node->retrieve($nid)->data($self->{user}));
    $template->param(page_title => "Forum Node: " . $template->param('subject'));
    return $template->output();
}

sub staff_report {
    my $self = shift;
    my $cgi = $self->query();
    my $pmt = $self->{pmt};
    my ($year,$mon,$mday) = $self->get_date();

    my ($mon_year,$mon_month,$mon_day) = Monday_of_Week(Week_of_Year($year,$mon,$mday));
    my ($sun_year,$sun_month,$sun_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,7);
    my ($pm_year,$pm_month,$pm_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,-7);
    my ($nm_year,$nm_month,$nm_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,7);

    my $template = $self->template("staff_report.tmpl");

    $template->param(
                     mon_year => $mon_year,
                     mon_month => $mon_month,
                     mon_day => $mon_day,
                     sun_year => $sun_year,
                     sun_month => $sun_month,
                     sun_day => $sun_day,
                     pm_year => $pm_year,
                     pm_month => $pm_month,
                     pm_day => $pm_day,
                     nm_year => $nm_year,
                     nm_month => $nm_month,
                     nm_day => $nm_day,
                     );
    my $data = $pmt->staff_report("$mon_year-$mon_month-$mon_day",
                                        "$sun_year-$sun_month-$sun_day");
    $template->param($data);
    $template->param(page_title => "Staff Report");
    $template->param(reports_mode => 1);
    return $template->output();
}

sub project_history {
    my $self = shift;
    my $cgi = $self->query();
    my $pid   = $cgi->param('pid')   || "";
    my $month = $cgi->param('month') || "";
    my $year  = $cgi->param('year')  || "";
    unless ($year && $month) {
	my $day;
	($year,$month,$day) = todays_date();
    }
    my $project = PMT::Project->retrieve($pid);
    my $c = HTML::CalendarMonth->new( month => $month, year => $year );
    $c->table->attr('align','left');
    $c->table->attr('valign','top');
    $c->attr('width','100%');

    my $calendar = $c->as_HTML;

    foreach my $day ($c->days()) {
        my $r = $project->events_on("$year-$month-$day");
        my $cell = "";

        foreach my $i (@$r) {
            $cell .= "<tr><td><a href='item.pl?iid=$$i{iid}'>$$i{title}</a></td>";
            $cell .= "<td class='$$i{status}'>$$i{status}</td>";
            $cell .= "<td>$$i{comment}<hr />by $$i{username} \@ $$i{date_time}</td>";
            $cell .= "</tr>";
        }
        if($cell ne "") {
            $cell = "<table>$cell</table>";
            $calendar =~ s{>$day</td>}{>$day<br />$cell</td>};
        }
    }

    my $next = $month + 1;
    my $prev = $month - 1;
    my ($next_year,$prev_year) = ($year,$year);
    
    if(13 == $next) {
        $next = 1;
        $next_year = $year + 1;
    }
    if(0 == $prev) {
        $prev = 12;
        $prev_year = $year - 1;
    }

    my $template = $self->template("project_history.tmpl");

    $template->param(calendar   => $calendar,
                     pid        => $pid,
                     next_month => $next,
                     next_year  => $next_year,
                     prev_month => $prev,
                     prev_year  => $prev_year);

    return $template->output();

}

sub new_clients {
    my $self = shift;
    my $cgi = $self->query();
    my @months = qw/January February March April May June July August September October November December/;
    my ($year,$mon,$mday) = $self->get_date();

    my ($mon_year,$mon_month,$mon_day) = ($year,$mon,1);
    my ($sun_year,$sun_month,$sun_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,Days_in_Month($mon_year,$mon_month
) - 1);
    my ($pm_year,$pm_month,$pm_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,-1);
    my ($nm_year,$nm_month,$nm_day) = Add_Delta_Days($sun_year,$sun_month,$sun_day,1);


    my $template = $self->template("new_clients.tmpl");
    $template->param(
                     mon_year => $mon_year,
                     mon_month => $mon_month,
                     mon_day => $mon_day,
                     sun_year => $sun_year,
                     sun_month => $sun_month,
                     sun_day => $sun_day,
                     pm_year => $pm_year,
                     pm_month => $pm_month,
                     pm_day => $pm_day,
                     nm_year => $nm_year,
                     nm_month => $nm_month,
                     nm_day => $nm_day,
                     month => $months[$mon - 1],
                     year => $mon_year,
                     pm_mon => $months[$pm_month - 1],
                     nm_mon => $months[$nm_month - 1],
                     );

    $template->param(clients_mode => 1);
    $template->param(page_title => 'new clients report');
    $template->param(clients => PMT::Client->new_clients_data("$mon_year-$mon_month-$mon_day",
                                                          "$sun_year-$sun_month-$sun_day"));
    return $template->output();

}

sub project_search {
    my $self = shift;
    my $cgi = $self->query();
    my $pmt = $self->{pmt};
    my $search = $cgi->param('search') || "";

    my $type      = $cgi->param('type') || "";
    my $area      = $cgi->param('area') || "";
    my $approach  = $cgi->param('approach') || "";
    my $scale     = $cgi->param('scale') || "";
    my $distrib   = $cgi->param('distrib') || "";
    my $manager   = $cgi->param('manager') || "";
    my $developer = $cgi->param('developer') || "";
    my $guest     = $cgi->param('guest') || "";
    my $status    = $cgi->param('status') || "";

    my $template = $self->template("project_search_results.tmpl");
    $template->param(results => PMT::Project->project_search(type => $type,
							     area => $area,
							     approach => $approach,
							     scale => $scale,
							     distrib => $distrib,
							     manager => $manager,
							     developer => $developer,
							     guest => $guest,
							     status => $status,
							     )
		     );
    $template->param($self->{user}->menu());
    $template->param(projects_mode => 1);
    return $template->output();
}    

sub edit_client {
    my $self = shift;
    my $cgi = $self->query();
    my $user = $self->{user};
    my $client_id         = $cgi->param('client_id') || "";
    my $client = PMT::Client->retrieve($client_id);
    my $client_email      = $cgi->param('client_email') || "";
    my $lastname      = $cgi->param('lastname') || "";
    my $firstname     = $cgi->param('firstname') || "";
    my $title                 = $cgi->param('title') || "";
    my $registration_date = $cgi->param('registration_date') || "";
    my $department    = $cgi->param('department') || '';
    my $school                = $cgi->param('school') || '';
    my $add_affiliation   = $cgi->param('add_affiliation') || "";
    my $phone                 = $cgi->param('phone') || "";
    my $contact       = $cgi->param('contact') || "";
    my $comments      = $cgi->param('comments') || "";
    my $status            = $cgi->param('status') || "active";

    my @projects = $cgi->param('projects');


    $client->update_data(
			 lastname    => $lastname,
			 firstname   => $firstname,
			 title               => $title, 
			 status          => $status,
			 department          => $department, 
			 school      => $school,
			 add_affiliation => $add_affiliation,
			 phone               => $phone,
			 email               => $client_email, 
			 contact     => $contact,
			 comments    => $comments,
			 registration_date => $registration_date,
			 projects    => \@projects,
			 );
    $client->update();
    my $letter = uc(substr($lastname,0,1));
    $self->header_type('redirect');
    $self->header_props(-url => "home.pl?mode=all_clients;letter=$letter");
    return "client edited";
}

sub edit_client_form {
    my $self = shift;
    my $cgi = $self->query();
    my $client = PMT::Client->retrieve($cgi->param('client_id'));
    my $contact = $client->contact;

    my $template = $self->template("edit_client.tmpl");
    my $data = $client->data();
    $data->{client_email} = $data->{email};
    $data->{active} = $data->{status} eq "active";
    $template->param(contact_fullname => $contact->fullname);

    delete $data->{email};
    $template->param(%{$data});
    $template->param(projects => $client->projects_data(),
                     projects_select => $client->projects_select(),
                     contacts_select => $client->contacts_select(),
                     schools_select => $client->schools_select(),
                     departments_select => $client->all_departments_select());
    $template->param(clients_mode => 1);
    return $template->output();
}

sub client_search_form {
    my $self = shift;
    my $cgi = $self->query();
    my $pmt = $self->{pmt};
    my $template = $self->template("client_search_form.tmpl");
    $template->param(schools => PMT::Client->all_schools());
    $template->param(departments => PMT::Client->all_departments());
    $template->param(contacts => PMT::Client->all_contacts());
    $template->param(start_date => PMT::Client->min_registration());
    my ($year,$mon,$mday) = todays_date();
    $template->param(end_date => "$year-$mon-$mday");
    $template->param(page_title => "client search");
    $template->param(clients_mode => 1);
    return $template->output();
}

sub client_search {
    my $self = shift;
    my $cgi = $self->query();
    my $pmt = $self->{pmt};

    my $status = $cgi->param('status') || "%";
    my $department = $cgi->param('department') || "%";
    my $school = $cgi->param('school') || "%";
    my $start_date = $cgi->param('start_date') || "1900-01-01";
    my $end_date = $cgi->param('end_date') || "2500-01-01";
    my $project = $cgi->param('project') || "%";
    my $limit = $cgi->param('limit') || 100;
    my $offset = $cgi->param('offset') || 0;
    my $contact = $cgi->param('contact') || "%";

    my $q = $cgi->param('q') || "%";
    $limit =~ s/\D//;

    my $template = $self->template("client_search_results.tmpl");
    $template->param(results => [map {
	$_->{inactive} = $_->{status} eq "inactive";
	$_;
    } @{PMT::Client->client_search(
				   query => $q,
				   status => $status,
				   department => $department,
				   school => $school,
				   start_date => $start_date,
				   end_date => $end_date,
				   project => $project,
				   limit => $limit,
				   offset => $offset,
				   contact => $contact,
				   )}]);
    my $results_count = PMT::Client->client_search_count(
							 query => $q,
							 status => $status,
							 department => $department,
							 school => $school,
							 start_date => $start_date,
							 end_date => $end_date,
							 project => $project,
							 contact => $contact,
							 );
    $template->param(results_count => $results_count);
    if ($results_count > ($offset + $limit)) {
	$template->param('next' => 1);
	$template->param('next_offset' => $offset + $limit);
    }
    if ($offset > 0) {
	$template->param('prev' => 1);
	$template->param('prev_offset' => $offset - $limit);
    }
    $template->param(limit => $limit,
		     q => $q,
		     status => $status,
		     department => $department,
		     school => $school,
		     start_date => $start_date,
		     end_date => $end_date,
		     project => $project,
		     contact => $contact);
    $template->param(page_title => "client search");
    $template->param(clients_mode => 1);
    return $template->output();
}

sub project_months_report {
    my $self = shift;
    my $cgi = $self->query();
    my $pid        = $cgi->param('pid') || "";
    my $num_months = $cgi->param('num_months') || "";

    my $project = PMT::Project->retrieve($pid);

    my ($year,$month,$mday) = $self->get_date();

    my ($time_period, $time_title); 
    if ($num_months == 1) {
        $time_period = "month";
        $time_title  = "Monthly";
    } elsif ($num_months == 3) {
        $time_period = "quarter";
        $time_title  = "Quarterly";
    } elsif ($num_months == 6) {
        $time_period = "semester";
        $time_title  = "Semestral";
    } elsif ($num_months == 12) {
        $time_period = "year";
        $time_title  = "Annual";
    }

    my ($p_year, $p_month, $p_day) = Add_Delta_YM($year, $month, 1, 0, -$num_months);
    my ($n_year, $n_month, $n_day) = Add_Delta_YM($year, $month, 1, 0, $num_months);

    my $start_day = 1;
    #calculate end day
    my ($end_year, $end_month, $end_day) = Add_Delta_Days($n_year, $n_month, $n_day, -1);
  
    my $start = $year . "-" . "$month" . "-" . $start_day;
    my $end   = $end_year . "-" . "$end_month" . "-" . $end_day;
    #Min's addition to include forum posts in reports
    my $forum = new Forum($self->{user}->username);

    my $template = $self->template("project_months_report.tmpl");
    $template->param(
                     year => $year,
                     month => $month,
                     p_year => $p_year,
                     p_month => $p_month,
                     n_year => $n_year,
                     n_month => $n_month,
                     num_months => $num_months,
                     time_period => $time_period,
                     time_title => $time_title,
                     );
    $template->param($project->interval_report("$year-$month-$start_day", "$end_year-$end_month-$end_day"));
    $template->param($project->data());
    $template->param(posts => $forum->project_posts_by_time($pid, $start, $end));

    return $template->output();
}

sub user_history {
    my $self = shift;
    my $cgi = $self->query();
    my $user   = $cgi->param('user')  || "";
    my $view_user = PMT::User->retrieve($user);
    my $month  = $cgi->param('month') || "";
    my $year   = $cgi->param('year')  || "";
    unless ($month && $year) {
	my $day;
	($year,$month,$day) = todays_date();
    }
    my @months = qw/January February March April May June
	July August September October November December/;
    my @days;

    my $c = HTML::CalendarMonth->new( month => $month, year => $year );
    $c->table->attr('align','left');
    $c->table->attr('valign','top');

    my $month_name = $months[$month - 1];
    my $calendar = $c->as_HTML;


    $calendar =~ s/>(\d{1,2})</ class="calday">$1</g;

    foreach my $day ($c->days()) {
        my $r = $view_user->events_on("$year-$month-$day",$self->{user}->username);
        my $cell = "";

        foreach my $i (@$r) {
            $cell .= "<td><a href='item.pl?iid=$$i{iid}'>$$i{title}</a></td>";
            $cell .= "<td class='$$i{status}'>$$i{status}</td>";
            $cell .= "<td>$$i{comment}<hr />by $$i{username} \@ $$i{date_time}</td>";
            $cell .= "</tr>";
        }
        if($cell ne "") {
            push @days,{'cell'       => $cell,
                        'month_name' => $month_name,
                        'day'        => $day,
                        'rows'       => scalar @$r,
                        };
            $calendar =~ s{>$day</td>}{><b><a href="#$day">$day</a></b></td>};
        }
    }

    foreach my $d (@days) {
        my $new_cal = $calendar;
        $new_cal =~ s/calday"><b><a href="\#$d->{day}">$d->{day}<\/a><\/b>/thisday"><b>$d->{day}<\/b>/;
        $d->{cal} = $new_cal;
    }

    my $next = $month + 1;
    my $prev = $month - 1;
    my ($next_year,$prev_year) = ($year,$year);
    
    if(13 == $next) {
        $next = 1;
        $next_year = $year + 1;
    }
    if(0 == $prev) {
        $prev = 12;
        $prev_year = $year - 1;
    }

    my $template = $self->template("user_history.tmpl");

    $template->param(calendar   => $calendar,
                     user       => $user,
                     next_month => $next,
                     next_month_name => $months[($next - 1) % 12],
                     next_year  => $next_year,
                     prev_month => $prev,
                     prev_month_name => $months[($prev - 1) % 12],
                     days => \@days,
                     prev_year  => $prev_year);

    $template->param(page_title => "user history for $user");
    return $template->output();
}

sub weekly_summary {
    my $self = shift;
    my $cgi = $self->query();
    my $pmt = $self->{pmt};

    my ($year,$mon,$mday) = $self->get_date();

    my ($mon_year,$mon_month,$mon_day) = Monday_of_Week(Week_of_Year($year,$mon,$mday));
    my ($sun_year,$sun_month,$sun_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,7);
    my ($pm_year,$pm_month,$pm_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,-7);
    my ($nm_year,$nm_month,$nm_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,7);

    my $template = $self->template("weekly_summary.tmpl");
    $template->param(
                     mon_year => $mon_year,
                     mon_month => $mon_month,
                     mon_day => $mon_day,
                     sun_year => $sun_year,
                     sun_month => $sun_month,
                     sun_day => $sun_day,
                     pm_year => $pm_year,
                     pm_month => $pm_month,
                     pm_day => $pm_day,
                     nm_year => $nm_year,
                     nm_month => $nm_month,
                     nm_day => $nm_day,
                     );
    my @groups = $cgi->param("groups");
    unless (@groups) {
        # default to a couple
        @groups = qw/grp_programmers grp_webmasters
        grp_educationaltechnologists grp_video grp_management/;
    } 
    
    @groups = map { $pmt->group($_) } @groups;
    $template->param(groups => \@groups);
    
    $template->param($pmt->weekly_summary("$mon_year-$mon_month-$mon_day",
                                          "$sun_year-$sun_month-$sun_day",
                                      \@groups));
    $template->param(page_title => "Weekly Summary");
    my @values = ();
    my @labels = ();
    foreach my $g (@{PMT::User->groups()}) {
        my $name = $g->{group_name};
        $name =~ s/\s+\(group\)$//;
        push @values, $g->{group};
        push @labels, $name;
    }
    $template->param(groups_select => selectify(\@values, \@labels,
            [map {$_->{group}} @groups]));
    return $template->output();
}

sub monthly_summary {
    my $self = shift;
    my $cgi = $self->query();
    my $pmt = $self->{pmt};

    my ($year,$mon,$mday) = $self->get_date();

    my ($mon_year,$mon_month,$mon_day) = ($year,$mon,1);
    my ($sun_year,$sun_month,$sun_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,
							Days_in_Month($mon_year,$mon_month) - 1);
    my ($pm_year,$pm_month,$pm_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,-1);
    my ($nm_year,$nm_month,$nm_day) = Add_Delta_Days($sun_year,$sun_month,$sun_day,1);

    my $template = $self->template("monthly_summary.tmpl");
    $template->param(
                     mon_year => $mon_year,
                     mon_month => $mon_month,
                     mon_day => $mon_day,
                     sun_year => $sun_year,
                     sun_month => $sun_month,
                     sun_day => $sun_day,
                     pm_year => $pm_year,
                     pm_month => $pm_month,
                     pm_day => $pm_day,
                     nm_year => $nm_year,
                     nm_month => $nm_month,
                     nm_day => $nm_day,
                     );
    my @groups = $cgi->param("groups");
    unless (@groups) {
        @groups = qw/grp_programmers grp_webmasters grp_educationaltechnologists grp_video grp_management/;
    }
    @groups = map {$pmt->group($_) } @groups;
    $template->param(groups => \@groups);
    $template->param($pmt->weekly_summary("$mon_year-$mon_month-$mon_day",
                                          "$sun_year-$sun_month-$sun_day",
                                      \@groups));
    $template->param(page_title => "monthly summary");
    my @values = ();
    my @labels = ();
    foreach my $g (@{PMT::User->groups()}) {
        my $name = $g->{group_name};
        $name =~ s/\s+\(group\)$//;
        push @values, $g->{group};
        push @labels, $name;
    }
    $template->param(groups_select => selectify(\@values, \@labels,
            [map {$_->{group}} @groups]));

    return $template->output();
}

sub forum_archive {
    my $self = shift;
    my $cgi = $self->query();
    my $pid = $cgi->param('pid') || "";
    my $user = $cgi->param('username') || "";
    my $type = $cgi->param('type') || "posts";

    my $limit = $cgi->param('limit') || 20;
    my $offset = $cgi->param('offset') || 0;

    $limit = ($limit > 0) ? $limit : 20;
    $offset = ($offset >= 0) ? $offset : 0;

    my $forum = new Forum($self->{user}->username);
    my $template = $self->template("forum_archive.tmpl");
    my $total;
    if($pid) {
        $template->param(posts => $forum->project_posts($pid,$limit,$offset));
        $total = PMT::Node->num_project_posts($pid);
    } elsif ($user) {
        my $u = PMT::User->retrieve($user);
        my @logs = reverse(PMT::Node->user_log_entries($user));
        $total = scalar @logs;
        my $real_limit = $limit;
        if (($offset+$limit) > $total) {
            $real_limit = $total - $offset;
        }
        $template->param(logs => [map {$_->data()}
            @logs[$offset..$offset+$real_limit-1]]);
        $type = 'logs';
    } elsif ($type eq 'logs') {
        $template->param(logs => $forum->logs($limit,$offset));
        $total = PMT::Node->num_logs();
    } else {
        $template->param(posts => PMT::Node->posts($self->{user}->username,$limit,$offset));
        $total = PMT::Node->num_posts();
    }

    my $next_offset = $offset + $limit;
    my $next_limit  = $limit;
    my $prev_offset = $offset - $limit;
    my $last        = 0;
    my $first       = 0;

    if($next_offset > $total) {
        $last = 1;
    }
    if($offset == 0) {
        $first = 1;
    }
    if(($next_offset + $next_limit) > $total) {
        $next_limit = $total - $next_offset;
    }

    $template->param(offset      => $offset,
                     limit       => $limit,
                     last        => $last,
                     first       => $first,
                     total       => $total,
                     type        => $type,
                     pid         => $pid,
                     user        => $user,
                     next_limit  => $next_limit,
                     next_offset => $next_offset,
                     prev_offset => $prev_offset);
          
    $template->param(page_title => 'forum archive');
    return $template->output();
}

sub project_weekly_report {
    my $self = shift;
    my $cgi = $self->query();
    
    my $pid = $cgi->param('pid') || "";
    my $project = PMT::Project->retrieve($pid);
                                
    my ($year,$mon,$mday) = $self->get_date();

    my ($mon_year,$mon_month,$mon_day) = Monday_of_Week(Week_of_Year($year,$mon,$mday));
    my ($sun_year,$sun_month,$sun_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,6);
    my ($pm_year,$pm_month,$pm_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,-7);
    my ($nm_year,$nm_month,$nm_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,7);
                                
    #Min's addition to include forum posts in reports
    my $start = $mon_year . "-" . $mon_month . "-" . $mon_day; 
    my $end   = $sun_year . "-" . $sun_month . "-" . $sun_day; 
    my $forum = new Forum($self->{user}->username);
                                
    my $template = $self->template("project_weekly_report.tmpl");
    $template->param(           
                     mon_year => $mon_year,
                     mon_month => $mon_month,
                     mon_day => $mon_day,
                     sun_year => $sun_year,
                     sun_month => $sun_month,
                     sun_day => $sun_day,
                     pm_year => $pm_year,
                     pm_month => $pm_month,
                     pm_day => $pm_day,
                     nm_year => $nm_year,
                     nm_month => $nm_month,
                     nm_day => $nm_day,
                     );
    $template->param($project->interval_report("$mon_year-$mon_month-$mon_day",
                                             "$sun_year-$sun_month-$sun_day"));
    $template->param($project->data());

    $template->param(posts => $forum->project_posts_by_time($pid, $start, $end)); 
    return $template->output();
}

# tries to get the date from parameters,
# defaults to the current date
sub get_date {
    my $self = shift;
    my $cgi = $self->query();

    my $syear = $cgi->param('year') || "";
    my $smonth = $cgi->param('month') || "";
    my $sday = $cgi->param('day') || "";
    my ($mday,$mon,$year);
    my ($tyear,$tmon,$tday) = todays_date();
    $year = $syear ? $syear : $tyear;
    $mon  = $smonth  ? $smonth  : $tmon;
    $mday = $sday  ? $sday  : $tday;
    return ($year,$mon,$mday);
}

sub user_weekly_report {
    my $self = shift;
    my $cgi = $self->query();
    my $pmt = $self->{pmt};
    my $user = $cgi->param('username') || "";
    my $view_user = PMT::User->retrieve($user);
    my ($year,$mon,$mday) = $self->get_date();

    my ($mon_year,$mon_month,$mon_day) = Monday_of_Week(Week_of_Year($year,$mon,$mday));
    my ($sun_year,$sun_month,$sun_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,7);
    my ($pm_year,$pm_month,$pm_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,-7);
    my ($nm_year,$nm_month,$nm_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,7);

    my $template = $self->template("user_weekly_report.tmpl");
    $template->param(
                     mon_year => $mon_year,
                     mon_month => $mon_month,
                     mon_day => $mon_day,
                     sun_year => $sun_year,
                     sun_month => $sun_month,
                     sun_day => $sun_day,
                     pm_year => $pm_year,
                     pm_month => $pm_month,
                     pm_day => $pm_day,
                     nm_year => $nm_year,
                     nm_month => $nm_month,
                     nm_day => $nm_day,
                     );

    #check is user is a group
    my $data = $pmt->group($user);
    $template->param($view_user->weekly_report("$mon_year-$mon_month-$mon_day",
                                               "$sun_year-$sun_month-$sun_day"));
    $template->param(page_title => "weekly report for $user");
    $template->param(user_username => $user);
    $template->param(reports_mode => 1);
    return $template->output();
}

sub active_clients_report {
    my $self = shift;
    my $cgi  = $self->query();
    
    my $clients_to_show = $cgi->param('clients') || 25; 
    my $employee = $cgi->param('employee') || "all"; 

    my $active_clients = PMT::Client->active_clients($clients_to_show,$employee);

    my $template = $self->template("active_clients.tmpl");
    $template->param('clients' => \@$active_clients);
    $template->param('number_of_clients_requested' => $clients_to_show);
    $template->param('employee' => $employee) if ($employee ne "all");
    
    $template->param('page_title' => "Active Clients Report");
    
    $template->param(users => PMT::User::users_select($employee),
		     all_selected => "all" eq $employee);
    
    return $template->output();
}

sub active_projects_report {
    my $self = shift;
    my $cgi  = $self->query();
    my $days = $cgi->param('days') || 31; # 31 is the default number of days

    my ($year2,$month2,$day_of_month2) = todays_date();

    my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime(time - 86400*$days); # 86400 = number of seconds in a day
    $year += 1900; # the year number is 0 at 1900 CE
    $month++;      # the month number is 0-based
    my $year1         = $year;
    my $month1        = $month;
    my $day_of_month1 = $mday;

    my $active_projects =
      PMT::Project->projects_active_between("$year1-$month1-$day_of_month1","$year2-$month2-$day_of_month2");

    my $output = "";
    if ($cgi->param('csv')) {
    
        use Text::CSV_XS;
    
        my $csv = Text::CSV_XS->new();

	$self->header_props(-type => "text/csv",
			    -content_disposition => "attachment;filename=active_projects_report.csv");
	if ($cgi->param('csv_header')) {
	    $output = qq{"Project ID","Project Name","Project Number","Last Worked On Date","Project Status","Project Caretaker","Hours Worked"} . "\n";
	}	       
	foreach my $project (@$active_projects) {
	    my @columns = ( $project->{pid}, $project->{project_name},
		      $project->{project_number}, $project->{project_last_worked_on},
		      $project->{project_status}, $project->{caretaker_fullname},
		      interval_to_hours($project->{time_worked_on}) );
		      
            $csv->combine(@columns);    # combine columns into a string
	    $output .= $csv->string() . "\n";
	}
    } else {
	my $total_hours = 0.0; # $total_hours = total hours worked _ever_ for all viewed projects, not just hours worked in the current "days"
	my @projects = map {
	    $_->{time_worked_on} = interval_to_hours($_->{time_worked_on}); # _all_ hours ever worked on this project, not just in "days"
	    $total_hours += $_->{time_worked_on};
	    $_;
	} @{$active_projects};
	my $template = $self->template("active_projects.tmpl");
	$template->param('projects' => \@projects);
	$template->param('days' => $days);
	$template->param('total_hours' => $total_hours);
    
	$template->param(page_title => "Active Projects Report");
	$output = $template->output();
    }    
    return $output;
    
}

1;

