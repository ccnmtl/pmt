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
use PMT::Attachment;
use PMT::Group;
use CGI;
use HTML::Template;
use Date::Calc qw/Week_of_Year Monday_of_Week Add_Delta_Days Days_in_Month Add_Delta_YM Delta_Days Day_of_Week/;
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
	'passed_open_milestones' => 'passed_open_milestones',
	'upcoming_milestones'    => 'upcoming_milestones',
        'add_trackers_form'      => 'add_trackers_form',
        'add_trackers'           => 'add_trackers',
        'group_activity_summary' => 'group_activity_summary',
        'group_plate'            => 'group_plate',
        'clients_summary'        => 'clients_summary',
        'watched_items'          => 'watched_items',
        'delete_client'          => 'delete_client',
        'delete_documents'       => 'delete_documents',
        'delete_attachments'     => 'delete_attachments',
        'delete_item'            => 'delete_item',
        'delete_milestone'       => 'delete_milestone',
        'delete_node'            => 'delete_node',
        'edit_node_form'         => 'edit_node_form',
        'edit_node'              => 'edit_node',
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
        'add_attachment'         => 'add_attachment',
        'add_group'              => 'add_group',
        'edit_my_items_form'     => 'edit_my_items_form',
        'edit_project_items_form' => 'edit_project_items_form',
        'project_info'           => 'project_info',
        'project_documents'      => 'project_documents',
        'project_clients'      => 'project_clients',
	'delete_clients_from_project' => 'delete_clients_from_project',
	'add_clients_to_project' => 'add_clients_to_project',
        'project_milestones'     => 'project_milestones',
	'project_milestones_json' => 'project_milestones_json',
	'project_timeline'       => 'project_timeline',
        'update_group'           => 'update_group',
        'add_milestone'          => 'add_milestone',
        'add_services_item'      => 'add_services_item',
        'notify'                 => 'notify',
        'notify_project'         => 'notify_project',
        'update_project'         => 'update_project',
        'update_project_form'    => 'update_project_form',
        'search_forum'           => 'search_forum',
        'set_tags'               => 'set_tags',
        'tag'                    => 'tag',
        'my_tags'                => 'my_tags',
        'all_tags'               => 'all_tags',
        'document'               => 'document',
        'attachment'             => 'attachment',
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
        'project_custom_report'  => 'project_custom_report',
        'project_months_report'  => 'project_months_report',
        'user_history'           => 'user_history',
        'weekly_summary'         => 'weekly_summary',
        'monthly_summary'        => 'monthly_summary',
        'forum_archive'          => 'forum_archive',
        'project_weekly_report'  => 'project_weekly_report',
        'user_weekly_report'     => 'user_weekly_report',
        'active_projects_report' => 'active_projects_report',
        'active_clients_report' => 'active_clients_report',
        'someday_maybe'          => 'someday_maybe',
        'deactivate_user'        => 'deactivate_user',
        'yearly_review'          => 'yearly_review',
        'change_item_project_form'              => 'change_item_project_form',
        'change_item_project_milestone_form'    => 'change_item_project_milestone_form',
        'change_item_project_review'            => 'change_item_project_review',
        'change_item_project'    => 'change_item_project',
        'send_custom_email'      => 'send_custom_email',
    );
    my $pmt = new PMT();
    my $q = $self->query();
    my $username = $q->cookie('pmtusername') || "";
    my $password = $q->cookie('pmtpassword') || "";

    if ($username eq "") { throw Error::NO_USERNAME; }

    $self->{user} = PMT::User->retrieve($username);
    $self->{user}->check_pass($username,$password);


    $self->{pmt} = $pmt;
    $self->{sortby} = $q->param('sortby') || $q->cookie('pmtsort') || "";

    $self->{username} = $username;
    $self->{message} = $q->param('message');
    $self->header_props(-charset => 'utf-8');
}

sub template {
    my $self = shift;
    my $template = PMT::Common::get_template(@_);
    $template->param(message => $self->{message});
    $template->param($self->{user}->menu());
    $template->param(wiki_base_url => PMT::Common::get_wiki_url());
    return $template;
}

sub home {
    my $self = shift;
    my $template = $self->template("home.tmpl");
    my $user = $self->{user};


    $template->param($user->home());

    # hours logged progress bar stuff
    my ($year,$mon,$mday) = $self->get_date();
    my ($mon_year,$mon_month,$mon_day) = Monday_of_Week(Week_of_Year($year,$mon,$mday));
    my ($sun_year,$sun_month,$sun_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,6);
    my $hours_logged = interval_to_hours($user->interval_time("$mon_year-$mon_month-$mon_day",
							      "$sun_year-$sun_month-$sun_day"));

    my $week_percentage = ($hours_logged / 35) * 100;
    my $dow = Day_of_Week($year,$mon,$mday);
    my $target_hours = min($dow,5) * 7;
    my $target_percentage = ($target_hours / 35) * 100;

    my $log_status = "ok";
    if ($week_percentage < $target_percentage - 20) {
	$log_status = "behind";
    } 

    $template->param(hours_logged => $hours_logged,
		     week_percentage => int($week_percentage),
		     hours_logged_progressbar => min(int($week_percentage * 5),600),
		     target_hours => $target_hours,
		     target_hours_progressbar => int($target_percentage * 5),
		     log_status => $log_status,
		     delinquent_milestones => $user->passed_open_milestones(),
	);
    $template->param(clients => $user->clients_data());
    $template->param(page_title => "homepage for " . $user->username);
    my $cgi = $self->query();
    $template->param(items_mode => 1);
    return $template->output();
}

sub someday_maybe {
    my $self = shift;
    my $template = $self->template("someday_maybe.tmpl");
    my $user = $self->{user};
    $template->param($user->someday_maybe());
    $template->param(page_title => "Someday/Maybe items for " . $user->username);
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
    $template->param(type_select => selectify(['Staff','Part-Timer','Guest'],
					      ['Staff','Part-Timer','Guest'],
					      [$user->type]));
    $template->param(settings_mode => 1);
    return $template->output();
}

sub update_user {
    my $self = shift;
    my $user = $self->{user};
    my $cgi = $self->query();

    my $new_pass  = $cgi->param('new_pass')  || "";
    my $new_pass2 = $cgi->param('new_pass2') || "";

    my $fullname  = $cgi->param('fullname')  || "";
    my $email     = $cgi->param('email')     || "";

    my $type  = $cgi->param('type') || "";
    my $title     = $cgi->param('title') || "";
    my $phone     = $cgi->param('phone') || "";
    my $bio       = $cgi->param('bio') || "";
    my $campus    = $cgi->param('campus') || "";
    my $building  = $cgi->param('building') || "";
    my $room      = $cgi->param('room') || "";
    my $photo_url = $cgi->param('photo_url') || "";
    my $photo_width = $cgi->param('photo_width') || "0";
    my $photo_height = $cgi->param('photo_height') || "0";


    if ($new_pass ne $new_pass2) {
        $self->header_props(-url => "/home.pl?mode=user_settings_form;message=Sorry,%20your%20passwords%20did%20not%20match.");
        $self->header_type('redirect');
        return "redirecting back to form";
    }

    $self->{pmt}->update_user($user->username,$new_pass,$new_pass2,$fullname,$email,
	$type,$title,$phone,$bio,$campus,$building,$room,$photo_url,$photo_width,$photo_height);

    my $lcookie = $cgi->cookie(-name =>  'pmtusername',
        -value => $user->username,
        -path => '/',
        -expires => '+10y');

    my $pcookie = $cgi->cookie(-name => 'pmtpassword',
        -value => $new_pass,
        -path => '/',
        -expires => '+10y');
    $self->header_props(-url => "/home.pl?mode=user_settings_form;message=updated");

    if ($new_pass ne '') {
	$self->header_add(-cookie => [$lcookie,$pcookie]);
    }
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
    my $projects = $user->workson_projects();
    my $wiki_base_url = PMT::Common::get_wiki_url();
    $data->{projects} = [map {
        $seen{$_} = 1;
        {
            pid      => $_,
            name     => $projects->{$_}{name},
            last_mod => $last_mods->{$_},
            proj_cc  => $user->notify_projects($_),
            wiki_category => $projects->{$_}{wiki_category},
            wiki_base_url => $wiki_base_url,
        };
    } sort {
        lc($projects->{$a}) cmp lc($projects->{$b});
    } keys %{$projects}];

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
	# default to one year from today if they haven't specified a target date
	# the form says it's required, but we'll be nice.
	# TODO: this will break if someone adds a project on Feb 29th and doesn't
	#       specify the target date. This is obscure enough that it's probably not
	#       worth fixing. 
	($year,$month,$day) = $self->get_date();
	$year++;
	$target_date = "$year-$month-$day";
    }

    my $project = PMT::Project->create({name => $name, pub_view => $pub_view,
                                        caretaker => $self->{user}, description => $description,
                                        status => 'planning', wiki_category => $wiki_category});
    my $manager = PMT::WorksOn->create({username => $self->{user}->username, pid => $project->pid});

    $project->add_milestone("Final Release",$target_date,"project completion");

    # call this for the side-effect that it will create a someday/maybe milestone
    # for us since it doesn't exist
    $project->someday_maybe_milestone();

    $self->header_type('redirect');
    $self->header_props(-url => "/home.pl?mode=project;pid=" . $project->pid);
    return "redirecting to new project page";
}

sub all_projects {
    my $self = shift;
    my $user = $self->{user};
    my $template = $self->template("projects.tmpl");
    $template->param(all_projects => $user->all_projects());
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
    $template->param(groups => PMT::User->groups());
    return $template->output();
}

sub passed_open_milestones {
    my $self = shift;
    my $user = $self->{user};
    my $template = $self->template("passed_open_milestones.tmpl");
    $template->param(reports_mode => 1);
    $template->param(page_title => "passed open milestones");
    $template->param(milestones => PMT::Milestone->passed_open_milestones());
    return $template->output();
}

sub upcoming_milestones {
    my $self = shift;
    my $user = $self->{user};
    my $template = $self->template("upcoming_milestones.tmpl");
    $template->param(reports_mode => 1);
    $template->param(page_title => "upcoming milestones");
    $template->param(milestones => PMT::Milestone->upcoming_milestones());
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
    my $template = $self->template("project_search_form.tmpl");
    $template->param(types_select => PMT::Project::types_select(),
        areas_select => PMT::Project::areas_select(),
        approaches_select => PMT::Project::approaches_select(),
        scales_select => PMT::Project::scales_select(),
        distributions_select => PMT::Project::distribs_select(),
        personnel_select => PMT::WorksOn->personnel_select(),
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

    my $username = $user->username;

    my $type         = $cgi->param('type') || throw Error::NO_TYPE "type is necessary";
    my $pid          = $cgi->param('pid') || throw Error::NO_PID "no project specified";
    my $mid          = $cgi->param('mid') || "";
    if ($mid eq "") {
        my $project = PMT::Project->retrieve($pid);
        $mid = $project->upcoming_milestone();
    }
    my $title = escape($cgi->param('title')) || "no title";

    my @assigned_to  = $cgi->param('assigned_to');
    my $owner        = $cgi->param('owner') || $username;
    my $priority     = $cgi->param('priority') || "";
    my $year         = $cgi->param('year') || "";
    my $month        = $cgi->param('month') || "";
    my $day          = $cgi->param('day') || "";
    my $url          = escape($cgi->param('url')) || "";
    my $description  = $cgi->param('description') || "";
    my $tags         = $cgi->param('tags') || "";
    my @clients      = $cgi->param('clients');
    my $completed    = $cgi->param('completed') || "";
    my $client_uni   = $cgi->param('client_uni') || "";
    if ($client_uni ne "") {
        # find the client id and append it to @clients
        my @cs = PMT::Client->find_by_uni($client_uni);
        if ($cs[0]) {
            push @clients, $cs[0]->{client_id};
        }
    }

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
    my @tags = ();
    push @tags, split /\n/, $tags;
    @tags = grep {$_ ne ""} map {escape($_);} @tags;

    my @new_clients;
    foreach my $client (@clients) {
        push @new_clients, $client unless $client eq "";
    }
    my $iid = "";
    if($type eq "tracker") {
        my $resolve_time = $cgi->param('time') || "1 hour";
        if($resolve_time =~ /^(\d+)$/) {
            # default to hours if now unit is specified
            $resolve_time = "$1"."h";
        }
        $iid = add_tracker(pid => $pid,
			   mid => $mid,
			   title => $title,
			   'time' => $resolve_time,
			   target_date => $target_date,
			   owner => $username,
			   completed => $completed,
			   clients => \@new_clients);
    } elsif ($type eq "todo") {
        $iid = add_todo(pid => $pid,
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
                        tags         => \@tags,
                        clients      => \@new_clients,
                        estimated_time => $estimated_time);

            $iid = PMT::Item::add_item(\%item);
        }
        $type =~ s/\s/%20/g;
    }

    # if there was an attachment, we put that on there now:

    my $filename    = $cgi->param('attachment')  || "";
    if ($filename) {
        my $attachmenttitle       = $cgi->param('attachmenttitle')       || $filename;
        my $attachmenturl         = $cgi->param('attachmenturl')         || "";
        my $attachmentdescription = $cgi->param('attachmentdescription') || "";
        my $fh          = $cgi->upload('attachment');


        my $id = PMT::Attachment->add_attachment(item_id     => $iid,
                                                 title       => $attachmenttitle,
                                                 url         => $attachmenturl,
                                                 filename    => $filename,
                                                 fh          => $fh,
                                                 description => $attachmentdescription,
                                                 author      => $username);
    }
    # put the user back at the add item for for the same type/project
    # so they can conveniently add multiple items

    $self->header_type('redirect');
    $self->header_props(-url => "/home.pl?mode=add_item_form;type=$type;pid=$pid");
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

sub add_tracker {
    my %args = @_;

    my $milestone = PMT::Milestone->retrieve($args{mid});
    my $user = PMT::User->retrieve($args{owner});

    my ($year,$mon,$mday) = todays_date();    
    use Date::Calc qw/Week_of_Year Monday_of_Week Add_Delta_Days/;
    my ($mon_year,$mon_month,$mon_day) = Monday_of_Week(Week_of_Year($year,$mon,$mday));
    my ($sun_year,$sun_month,$sun_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,6);

    my $target_date = "${sun_year}-${sun_month}-${sun_day}";
    my $item = PMT::Item->create({
            type => 'action item', owner => $user, assigned_to => $user,
            title => escape($args{title}), mid => $milestone, status =>
            'VERIFIED', priority => 1, target_date => $target_date,
            estimated_time => $args{'time'}});
    my $iid = $item->iid;

    $item->add_clients(@{$args{clients}});
    $item->add_resolve_time($user,$args{time},$args{completed});
}

sub add_todo {
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

sub add_trackers {
    my $self = shift;
    my $user = $self->{user};
    my $cgi = $self->query();
    my @trackers = ();
    foreach my $i (1..10) {
        my $pid    = $cgi->param("pid$i") || "";
        my $title  = $cgi->param("title$i") || "";
        my $time   = $cgi->param("time$i") || "1 hour";
        my $client_uni = $cgi->param("client$i") || "";
        my @clients = PMT::Client->find_by_uni($client_uni);
        my $client = "";
        if ($clients[0]) {
            $client = $clients[0]->{client_id};
        }
        $title = substr $title, 0, 255;
        if ($time =~ /^(\d+)$/) {
            $time = "$1"."h";
        }

        if ($time ne "" && $title ne "") {
            push @trackers, {pid => $pid,
                             title => $title,
                             time => $time,
                             client => $client};
        }
    }
    foreach my $t (@trackers) {
        my $project = PMT::Project->retrieve($t->{pid});
        my $mid = $project->upcoming_milestone();
        my $milestone = PMT::Milestone->retrieve($mid);
        my $target_date = $milestone->target_date;
        my $clients = [];
        if ($t->{client} ne "") {
            $clients = [$t->{client}];
        }
        add_tracker(pid => $t->{pid},mid => $mid, title => $t->{title}, 
		    "time" => $t->{time},target_date => $target_date, owner => $user->username,
		    completed => "", clients => [$t->{client}]);

    }
    $self->header_type('redirect');
    $self->header_props(-url => "/home.pl?mode=add_trackers_form");
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
        $self->header_props(-url => "/home.pl?mode=all_clients;letter=$letter");
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
<form action="/home.pl" method="POST">
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
    $self->header_props(-url => "/home.pl?mode=project;pid=$pid");
    return "documents deleted";
}

sub delete_attachments {
    my $self = shift;
    my $q = $self->query();
    my %vars = $q->Vars();
    my @del = map {/^del_(\d+)$/; $1;} grep {/^del_\d+/} keys %vars;
    my $iid = $q->param('iid');
    my $user = undef;
    foreach my $id (@del) {
        my $attachment = PMT::Attachment->retrieve($id);
        $user = $attachment->author();
        $attachment->delete();
    }

    $self->header_type('redirect');
    $self->header_props(-url => "/item/$iid/");
    return "attachments deleted";
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
        $self->header_props(-url => "/home.pl?mode=milestone;mid=$mid");
        return "deleted item";
    }
}

sub update_group {
    my $self = shift;
    my $cgi = $self->query();
    my $group = untaint_username($cgi->param('group') || "");
    my @users = $cgi->param('users');

    my @u = PMT::Group->search({grp => $group});
    foreach my $u (@u) {$u->delete()}

    foreach my $u (@users) {
        my $g = PMT::Group->create({grp => $group, username => $u});
    }

    $self->header_type('redirect');
    $self->header_props(-url => "/home.pl?mode=group;group=$group");
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
    $self->header_props(-url => "/home.pl?mode=project;pid=$pid");
}


sub delete_item_verify {
    my $self = shift;
    my $iid = shift;
    return qq{
    <html><head><title>delete item</title>
    </head>
    <body>
    <h2>delete item</h2>
    <form action="/home.pl" method="POST">
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
        $self->header_type('redirect');
        $self->header_props(-url => "/home.pl");
    } else {
        my $milestone = PMT::Milestone->retrieve($mid);
        my $really = $cgi->param('verify') || "";

        if ($really eq "") {
            return $self->delete_milestone_verify($mid);
        } else {
            my $pid = $milestone->delete_milestone();
            $self->header_type('redirect');
            $self->header_props(-url => "/home.pl?mode=project;pid=$pid");
            return "milestone deleted\n";
        }
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
    <form action="/home.pl" method="POST">
    <input type="hidden" name="mode" value="delete_milestone" />
    <input type="hidden" name="verify" value="ok" />
    <input type="hidden" name="mid" value="$mid" />
    <input type="submit" value="delete" /><br />
    (NOTE: You must delete or move all items attached to the milestone before you can delete it.)
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
        $self->header_props(-url => "/home.pl?mode=forum");
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
    <form action="/home.pl" method="POST">
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

    my $really = $cgi->param('verify') || "";
    if ($really ne "ok") {
        return $self->delete_project_verify($pid);
    } else {
        $project->delete();
        $self->header_type('redirect');
        $self->header_props(-url => "/home.pl");
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
    <form action="/home.pl" method="POST">
    <input type="hidden" name="mode" value="delete_project" />
    <input type="hidden" name="verify" value="ok" />
    <input type="hidden" name="pid" value="$pid" />
    <input type="submit" value="delete" /><br />
    <b>WARNING!</b> deleting the project will delete all milestones and items in the project.
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
    my $status            = $cgi->param('satatus')           || "";

    my $user = $self->{user};
    my $username = $self->{username};

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
        my $ou = "not_retrieved";
        if ($uni ne "") {
            my $d = ldap_lookup($uni);
            if ($d->{found}) {
                if ($d->{mail}) {
                    $client_email  = $d->{mail}            || "";
                } 

                $lastname      = $d->{lastname}        || "";
                $firstname     = $d->{"givenName;x-role-2"}  || $d->{"givenName"} || $d->{"firstname"} || "";
                $title         = $d->{title}           || "";
                $ou            = $d->{"ou"}              || "(not found)";
                $phone         = $d->{telephonenumber} || "";
            } else {
                $lastname = $firstname = $title = $department = $school = $phone = "";
            }
        } else {
            # Just so there's something to check existing users against
            $uni = $client_email;
        }
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

        my $departments_select = PMT::Client->all_departments_select($ou);

        my $schools_select;

        if ( PMT::Client::is_a_recognized_school($ou) ) { # if the OU is a recognized school name...
          $schools_select = PMT::Client->all_schools_select($ou);
        } else {
          $schools_select = PMT::Client->all_schools_select("Arts & Sciences");
        }
        my $existing_clients   = PMT::Client->existing_clients($uni,$lastname);
        $template->param(client_email       => $client_email,
                         lastname           => $lastname,
                         firstname          => $firstname,
                         title              => $title,
                         department         => $department,
                         school             => $school,
                         schools_select     => $schools_select,
                         departments_select => $departments_select,
                         phone              => $phone,
                         users_select       => $users_select,
                         year               => $year,
                         month              => $mon,
                         day                => $mday,
                         existing_clients   => $existing_clients,
                         ou                 => $ou,
                         status             => $status
        );
    } else {
	# still need those selects
        my ($year,$mon,$mday) = todays_date();
        my $users_select       = PMT::User::users_select($username);
        my $departments_select = PMT::Client->all_departments_select("");
        my $schools_select = PMT::Client->all_schools_select("Arts & Sciences"); 
	$template->param(departments_select => $departments_select,
			 schools_select => $schools_select,
			 users_select => $users_select,
			 year => $year,
			 month => $mon,
			 day => $mday,
	    );
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
    my $status            = $cgi->param('status')            || "";

    $title = substr($title,0,100);
    $phone = substr($phone,0,32);
    my $client_id = "";
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
                status            => $status,
            });
	$client_id = $client->client_id;
    }
    $self->header_type('redirect');
    if ($client_id ne "") { $self->header_props(-url => "/home.pl?mode=client;client_id=${client_id}"); }
    else { $self->header_props(-url => "/home.pl?mode=add_client_form"); }
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
    my $tags     = escape($cgi->param('usertags'))        || "";
    $tags =~ s/\s+\n/\, /;

    if ($preview eq "preview") {
        my $tiki = new Text::Tiki;
        $body =~ s/\(([^\)\(]+\@[^\)\(]+)\)/( $1 )/g; # workaround horrible bug in Text::Tiki
        $body =~ s/(\w+)\+(\w+)\@/$1&plus;$2@/g; # workaround for second awful Text::Tiki bug
        my $formatted_body = $tiki->format($body);
        my $template = $self->template("preview.tmpl");
        $template->param(pid => $pid,
            subject => $subject,
            body => $body,
            tags => $tags,
            formatted_body => $formatted_body,
            type => $type,
            reply_to => $reply_to);
        $template->param(forum_mode => 1);
        return $template->output();
    } else {
        my $forum = new Forum($username);
        my $nid = $forum->post(type => $type,pid => $pid,
            subject => $subject,body => $body,
            reply_to => $reply_to, tags => $tags);
        $self->header_type('redirect');
        $self->header_props(-url => "/home.pl?mode=forum");
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
	    my $mid = $params{"milestone_$iid"};

            my $i = PMT::Item->retrieve($iid);
            my $r_status = "";
            ($status,$r_status) = split /_/, $status;

            if ($resolve_time =~ /^(\d+)$/) {
                $resolve_time .= "h";
            }
            my $changed = 0;
            my $comment = "";

            if ($status eq "someday") {
                $status = $i->status;
                $r_status = $i->r_status;
                my $m = $i->mid->pid->someday_maybe_milestone();
                $i->mid($m->mid);
                $changed = 1;
                $comment = "milestone changed";
            }

            my $email = 0;

            if (($assigned_to eq $i->owner->username) &&
                ($assigned_to eq $self->{username}) &&
                ($status eq "RESOLVED")) {
                $status = "VERIFIED";
                $r_status = "";
            }

            if ($assigned_to ne $i->assigned_to->username) {
                $changed = 1;
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
                } elsif ($status eq "OPEN" && $i->status ne "OPEN") {
                    $comment .= "<b>reopened</b><br />\n";
                } elsif ($status eq "RESOLVED" && $i->status ne "RESOLVED") {
                    $comment .= "<b>resolved ${r_status}</b><br />\n";
                    $i->r_status($r_status); # prevent it from re-matching later
                } elsif ($status eq "VERIFIED" && $i->status ne "VERIFIED") {
                    $comment .= "<b>verified</b><br />\n";
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

	    # always make sure owner/assignee are cc'd
	    $i->setup_default_notification();

            if ($resolve_time) {
                $i->add_resolve_time($u,$resolve_time);
            }
	    if ($mid) { # only check this if there's one in the params
		my $milestone = PMT::Milestone->retrieve($mid);
		if ($milestone->mid != $i->mid->mid) {
		    $changed = 1;
		    my $old_milestone = PMT::Milestone->retrieve($i->mid->mid);
		    $old_milestone->update_milestone($u);
		    $i->mid($mid);
		}
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
    my $redirect = $params{"redirect"} || "/home.pl";
    $self->header_props(-url => $redirect);
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

    if ($cgi->param('inherit')) {
	$milestone->update_item_target_dates($target_date);
    }

    $milestone->set(name => $name, target_date => $target_date,
        description => $description);
    $milestone->update();
    $milestone->update_milestone();

    $self->header_type("redirect");
    $self->header_props(-url => "/home.pl?mode=milestone;mid=$mid");
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
    $self->header_props(-url => "/home.pl?mode=project;pid=$pid");
}

sub add_attachment {
    my $self        = shift;
    my $cgi         = $self->query();
    my $username    = $self->{username};
    my $iid         = $cgi->param("iid")         || throw Error::NO_IID "no item specified";
    my $filename    = $cgi->param('attachment')  || "";
    my $title       = $cgi->param('title')       || $filename;
    my $url         = $cgi->param('url')         || "";
    my $description = $cgi->param('description') || "";
    my $fh          = $cgi->upload('attachment');

    eval {
        my $id = PMT::Attachment->add_attachment(item_id     => $iid,
                                                 title       => $title,
                                                 url         => $url,
                                                 filename    => $filename,
                                                 fh          => $fh,
                                                 description => $description,
                                                 author      => $username);
        $self->header_type("redirect");
        $self->header_props(-url => "/item/$iid/");
    };
    if ($@) {
        my $E = $@;
        return $E->{-text};
    }
}


sub add_group {
    my $self = shift;
    my $cgi = $self->query();
    my $group_name = $cgi->param('group') || "";
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

    my $group = $normalized;
    $self->header_type("redirect");
    $self->header_props(-url => "/home.pl?mode=group;group=$group");
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

    $data{caretaker_fullname}   = $caretaker->fullname;
    $data{personnel}             = [map {$_->data()} $project->personnel()];
    $data{clients}              = $project->clients_data();
    $data{tags}                 = $project->tags();
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

sub project_clients {
    my $self = shift;
    my $cgi = $self->query();
    my $pid = $cgi->param('pid');
    my $project = PMT::Project->retrieve($pid);
    my $template = $self->template("project_clients.tmpl");
    my %data = %{$project->data()};
    $data{total_remaining_time} = interval_to_hours($project->estimated_time);
    $data{total_completed_time} = interval_to_hours($project->completed_time);
    $data{total_estimated_time} = interval_to_hours($project->all_estimated_time);

    $template->param(\%data);
    $template->param(projects_mode => 1);
    $template->param(clients => $project->clients_data());
    $template->param(all_non_clients => $project->all_non_clients_select());
    $template->param(page_title => "project clients");
    return $template->output();
}

sub delete_clients_from_project {
    my $self = shift;
    my $q = $self->query();
    my %vars = $q->Vars();
    my @del = map {/^del_(\d+)$/; $1;} grep {/^del_\d+/} keys %vars;
    my $pid = $q->param('pid');
    foreach my $client_id (@del) {
	my $pc = PMT::ProjectClients->retrieve(pid => $pid, client_id => $client_id);
        $pc->delete();
    }
    $self->header_type('redirect');
    $self->header_props(-url => "/home.pl?mode=project_clients;pid=$pid");
    return "clients deleted";
}

sub add_clients_to_project {
    my $self = shift;
    my $q = $self->query();
    my $pid = $q->param('pid');
    my $project = PMT::Project->retrieve($pid);
    my @clients     = $q->param('clients');    
    foreach my $client_id (@clients) {
	my $pc = PMT::ProjectClients->create({pid => $pid, client_id => $client_id});
    }
    $self->header_type('redirect');
    $self->header_props(-url => "/home.pl?mode=project_clients;pid=$pid");
    return "clients added";
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

use JSON;

my @months = qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/;

sub simile_format_date {
    my $date = shift;
    my ($year,$month,$day) = split "-", $date;
    my $mname = $months[$month - 1];
    return "$mname $month $year 00:00:00 GMT";
}

sub project_milestones_json {
    my $self = shift;
    my $cgi = $self->query();
    my $pid = $cgi->param('pid');
    my $project = PMT::Project->retrieve($pid);
#    my $data = $project->data();
#    $data->{total_remaining_time} = interval_to_hours($project->estimated_time);
#    $data->{total_completed_time} = interval_to_hours($project->completed_time);
#    $data->{total_estimated_time} = interval_to_hours($project->all_estimated_time);

    

    my @milestones = map {
	{
	    start => simile_format_date($_->{target_date}),
	    isDuration => 0,
	    title => $_->{name},
	    description => $_->{description},
	    link => "/home.pl?mode=milestone;mid=$_->{mid}"
	};
    } @{$project->project_milestones("priority")};
    my $json = new JSON(pretty => 1);
    $self->header_props(-type => 'application/json');
    return $json->encode({'events' => \@milestones});
}

sub project_timeline {
    my $self = shift;
    my $cgi = $self->query();
    my $pid = $cgi->param('pid');
    my $project = PMT::Project->retrieve($pid);
    my $data = $project->data();
    $data->{milestones} = $project->project_milestones("priority");
    $data->{total_remaining_time} = interval_to_hours($project->estimated_time);
    $data->{total_completed_time} = interval_to_hours($project->completed_time);
    $data->{total_estimated_time} = interval_to_hours($project->all_estimated_time);

    my $template = $self->template("project_timeline.tmpl");
    $template->param(projects_mode => 1);
    $template->param(page_title => "project timeline");
    $template->param($data);
    return $template->output();
}


sub add_services_item {
    my $self = shift;
    my $cgi = $self->query();
    my $user = $self->{user};
    my $pid = $cgi->param('pid');
    my $type = $cgi->param('type') || "tracker";
    my $client_id = $cgi->param('client_id') || die "no client specified";

    my $template = $self->template("add_courseworks_item.tmpl");

    my $client = PMT::Client->retrieve($client_id);
    my $client_data = $client->data();
    my $project = PMT::Project->retrieve($pid);
    my %data = %{$project->data()};

    $data{'milestone_select'} = $project->project_milestones_select();
    $data{'tags'}     = $project->tags();
    my $caretaker = $project->caretaker->username;
    $data{'personnel'}   = [map {{
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
    # owner/assignee are not allowed to remove themselves
    # so here we will make SURE they didn't
    $item->setup_default_notification();

    $self->header_type('redirect');
    $self->header_props(-url => "/item/$iid/");
    return "changed notification for an item";
}

sub referer {
    return $ENV{HTTP_REFERER} || "/home.pl";
}
    

sub notify_project {
    my $self = shift;
    my $cgi = $self->query();
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
    $self->header_props(-url => referer());
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
    my @personnel    = $cgi->param('personnel');
    my $status      = $cgi->param('status');
    my $projnum     = $cgi->param('projnum')    || "";
    my $type        = $cgi->param('type')       || "";
    my $area        = $cgi->param('area')       || "";
    my $url         = $cgi->param('url')        || "";
    my $restricted  = $cgi->param('restricted') || "";
    my $approach    = $cgi->param('approach')   || "";
    my $info_url    = $cgi->param('info_url')   || "";
    my $entry_rel   = $cgi->param('entry_rel')  || "";
    my $eval_url    = $cgi->param('eval_url')   || "";
    my $scale       = $cgi->param('scale')      || "";
    my $distrib     = $cgi->param('distrib')    || "";
    my $poster      = $cgi->param('poster')     || "";

    my $project = PMT::Project->retrieve($pid);

    $project->edit_project(pid         => $pid,
			   name        => $name,
			   description => $description,
			   caretaker   => $caretaker,
			   personnel    => \@personnel,
			   pub_view    => $pub_view,
			   status      => $status,
			   projnum     => $projnum,
			   type        => $type,
			   area        => $area,
			   url         => $url,
			   restricted  => $restricted,
			   approach    => $approach,
			   info_url    => $info_url,
			   entry_rel   => $entry_rel,
			   eval_url    => $eval_url,
			   scale       => $scale,
			   distrib     => $distrib,
			   poster      => $poster,
	);

    $self->header_type('redirect');
    $self->header_props(-url => "/home.pl?mode=project;pid=$pid");
    return "updated project info";
}

sub update_project_form {
    my $self = shift;
    my $cgi = $self->query();
    my $pid = $cgi->param('pid');
    my $user = $self->{user};
    my $username = $user->username;

    my ($year,$mon,$day) = todays_date();

    my $sortby = $cgi->param('sortby') || $cgi->cookie("pmtsort") || "priority";
    my $project = PMT::Project->retrieve($pid);

    my %data = %{$project->data()};
    $data{personnel}             = [map {$_->data()} $project->personnel()];
    $data{caretaker_select}     = $project->caretaker_select();
    $data{all_non_personnel}    = $project->all_non_personnel_select();
    $data{statuses}             = $project->status_select();
    $data{approaches}           = $project->approaches_select();
    $data{scales}               = $project->scales_select();
    $data{distribs}             = $project->distribs_select();
    $data{areas}                = $project->areas_select();
    $data{restricteds}          = $project->restricteds_select();
    $data{types}                = $project->types_select();
#    $data{clients}              = $project->clients_data();
#    $data{all_non_clients}      = $project->all_non_clients_select();
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

use URI::Escape;
use JSON;

sub set_tags {
    # meant to be called via AJAX
    
    #test this fix by doing an http GET of:
    #/home.pl?mode=set_tags;nid=3999;tags=learning
    
    my $self = shift;
    my $json = new JSON(pretty => 1);
    my $cgi = $self->query();
    my $user = $self->{user};
    my $username = $user->username;
    my $iid = $cgi->param('iid') || "";
    my $nid = $cgi->param('nid') || "";
    my $tags = $cgi->param('tags') || "";
    my @tags = split /[\n\r\,+]/, $tags;
    @tags = map {s/^\s+//; s/\s+$//; $_;} @tags;
    if ($iid) {
        my $item = PMT::Item->retrieve($iid);
        $item->update_tags(\@tags,$username);
        return $json->encode($item->tags());
    }
    if ($nid) {
        my $node = PMT::Node->retrieve($nid);
        $node->update_tags(\@tags,$username);
        return $json->encode($node->tags());
    }
}

sub tag {
    my $self = shift;
    my $cgi = $self->query();
    my $user = $self->{user};
    my $username = $user->username;
    my $tag     = $cgi->param('tag') || "";
    my $pid     = $cgi->param('pid') || "";
    my $u = $cgi->param('username') || "";

    my $template = $self->template("tag.tmpl");
    $tag = uri_escape($tag);
    my $url = "tag/$tag/";
    if ($pid ne "") {
        $url .= "user/project_$pid/";
    }
    my $r = tasty_get($url);

    my @items = ();
    my @nodes = ();

    foreach my $el (@{$r->{items}}) {
        my $item = $el->{item};
        my @parts = split "_", $item;
        my $id = $parts[1];
        if ($parts[0] eq "item") {
            my $i = PMT::Item->retrieve($id);
	    if ($i) {
		push @items, $i->data();
	    }
        }
        if ($parts[0] eq "node") {
            my $n = PMT::Node->retrieve($id);
	    if ($n) {
		push @nodes, $n->data($user);
	    }
        }
    }
    
    my $items = [sort {$b->{last_mod} cmp $a->{last_mod}} @items];
    my $nodes = [sort {$b->{added} cmp $a->{added}} @nodes];

    $template->param(items => $items,
                     nodes => $nodes,
		     pid => $pid,
                     tag => uri_unescape($tag));

    return $template->output();

}

# why does perl not come with min() and max() functions? grr.

sub max {
    my @list = @_;
    return () if (scalar(@list) < 1);
    my $max = $list[0];
    foreach my $i (@list) {
        $max = $i if ($i > $max);
    }
    return $max;
}

sub min {
    my @list = @_;
    return () if (scalar(@list) < 1);
    my $min = $list[0];
    foreach my $i (@list) {
        $min = $i if ($i < $min);
    }
    return $min;
}

sub cloud {
    my $tags = shift;
    my $levels = 5;

    my $max = max(map {$_->{count}} @$tags);
    my $min = min(map {$_->{count}} @$tags);

    my $stepsize = ($max - $min) / $levels;
    my @thresholds = ();
    my $t = $min;
    if ($max == $min) {$stepsize = 1;}

    foreach my $i (0..$levels - 1) {
        my $percent = $i / $levels;
        my $size = ($max - $min + 1) ** $percent;

        push @thresholds, $size;
    }

    my $level_from_weight = sub {
        my $w = shift;
        my $i = 0;
        foreach my $thr (@thresholds) {
            $i++;
            return $i if ($w <= $thr);
        }
        return $i;
    };

    foreach my $tag (@$tags) {
        $tag->{level} = $level_from_weight->($tag->{count});
    }

    return $tags;
}

sub my_tags {
    # display a user's tags (ideally as a cloud)
    my $self = shift;
    my $user = $self->{user};
    my $username = $user->username;
    my $url = "user/user_$username/cloud";
    my $template = $self->template("my_tags.tmpl");
    my $r = tasty_get($url);
    my $tags = [];
    if ($r->{tags}) {
	$tags = [sort {$a->{tag} cmp $b->{tag}} 
		map {$_->{tag} = lc($_->{tag});$_;} 
		@{$r->{tags}}];
    }
    $tags = cloud($tags);
    $template->param(tags => $tags,
                     page_title => 'My Tags');
    return $template->output();
}

sub all_tags {
    my $self = shift;
    my $url = "cloud";
    my $template = $self->template("all_tags.tmpl");
    my $r = tasty_get($url);
    my $tags = [];
    if ($r->{tags}) {
	$tags = [sort {$a->{tag} cmp $b->{tag}} 
		map {$_->{tag} = lc($_->{tag});$_;} 
		@{$r->{tags}}];
    }

    $tags = cloud($tags);
    $template->param(tags => $tags,
                     page_title => 'All Tags');
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

sub attachment {
    my $self = shift;
    my $cgi = $self->query();
    my $id = $cgi->param('attachment_id') || "";
    my $attachment;
    eval {
        $attachment = PMT::Attachment->retrieve($id);
    };
    if ($@) {
        return "error: no attachment found";
    }

    if($attachment->type eq "url") {
        $self->header_type('redirect');
        $self->header_props(-url => $attachment->url);
        return "redirecting to url";
    } else {
        my $content_type = $attachment->content_type();
        if($attachment->content_disposition()) {
            my $filename = $attachment->filename;
            $self->header_props(-type => $content_type,
                                -content_disposition => "attachment;filename=$filename");
        } else {
            $self->header_props(-type => $content_type);
        }
        my $c = $attachment->contents();
        return $c;
    }
}



sub update_item_form {
    my $self = shift;
    my $cgi = $self->query();
    my $iid = $cgi->param('iid');
    my $user = $self->{user};


    my $item = PMT::Item->retrieve($iid);
    my $r = $item->full_data();
    my %data = %$r;
    my $project = PMT::Project->retrieve($data{'pid'});
    $data{$project->project_role($user->username)} = 1;
    $data{attachments}         = [map {$_->data()} $item->attachments()];
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
    $self->header_props(-url => "/item/$iid/?message=$message");
    return $message;
}

sub change_item_project_form {
    my $self = shift;
    my $template = $self->template("change_item_project_form.tmpl");
    my $cgi = $self->query();
    my $user = $self->{user};
    my $iid = $cgi->param('iid');
    my $item = PMT::Item->retrieve($iid);
    my $item_r = $item->full_data();
    my %data = %$item_r;
    my @projects_select = sort {lc($a->{'label'}) cmp lc($b->{'label'}) } $user->workson_projects_select($data{'pid'});
    $data{'projects_select'} = \@projects_select;
    $template->param(\%data);
    return $template->output();
}

sub change_item_project_milestone_form {
    my $self = shift;
    my $template = $self->template("change_item_project_milestone_form.tmpl");
    my $cgi = $self->query();
    my $user = $self->{user};
    my $iid = $cgi->param('iid');
    my $item = PMT::Item->retrieve($iid);
    my $item_r = $item->full_data();
    my %data = %$item_r;

    my $new_project = PMT::Project->retrieve($cgi->param('new_pid'));
    $data{'new_pid'} = $new_project->pid;
    $data{'new_project'} = $new_project->name;
    $data{'new_milestone_select'} = $new_project->project_milestones_select();
    
    $template->param(\%data);
    return $template->output();
}

sub change_item_project_review {
    my $self = shift;
    my $template = $self->template("change_item_project_review.tmpl");
    my $cgi = $self->query();
    my $user = $self->{user};
    my $iid = $cgi->param('iid');
    my $item = PMT::Item->retrieve($iid);
    my $item_r = $item->full_data();
    my %data = %$item_r;
    my $new_project = PMT::Project->retrieve($cgi->param('new_pid'));    
    $data{'new_pid'} = $new_project->pid;
    $data{'new_project'} = $new_project->name;

    # Get existing milestone from new project or ...
    if (! $cgi->param('new_milestone_name')) {
        my $new_milestone = PMT::Milestone->retrieve($cgi->param('new_mid'));
        $data{'new_mid'} = $new_milestone->mid;
        $data{'new_milestone_name'} = $new_milestone->name;
    } else {
        $data{'new_milestone_name'} = $cgi->param('new_milestone_name');
        $data{'new_milestone_date'} = $cgi->param('new_milestone_date');
        $data{'new_milestone_description'} = $cgi->param('new_milestone_description');
    }
    
    # Check owner and assigned users against new workson_projects
    if (! $item->owner->does_work_on($new_project->pid)) {
        $data{'add_owner'} = 1;
    }
    if (! $item->assigned_to->does_work_on($new_project->pid)) {
        $data{'add_assigned_to'} = 1;
    }
    $template->param(\%data);
    return $template->output();
}

sub change_item_project {
    my $self = shift;
    my $template = $self->template("change_item_project_review.tmpl");
    my $cgi = $self->query();
    my $user = $self->{user};
    my $iid = $cgi->param('iid');
    my $item = PMT::Item->retrieve($iid);
    my $item_r = $item->full_data();
    my %data = %$item_r;
    my $new_project = PMT::Project->retrieve($cgi->param('new_pid'));    

    my $new_mid;
    # Change item milestone
    if (! $cgi->param('new_milestone_name')) {
        $new_mid = $cgi->param('new_mid');
    # Create a new milestone
    } else {
        $new_mid = $new_project->add_milestone($cgi->param('new_milestone_name'), $cgi->param('new_milestone_date'), $cgi->param('new_milestone_description'));
    }

    # Make sure owner and assigned users work on new project
    if (! $item->owner->does_work_on($new_project->pid)) {
        PMT::WorksOn->create({username => $item->owner->username, pid => $new_project->pid,  auth => 'manager'});
    }
    if (! $item->assigned_to->does_work_on($new_project->pid)) {
        PMT::WorksOn->create({username => $item->assigned_to->username, pid => $new_project->pid, auth => 'developer'});
    }

    # Update the item with the new milestone
    $item->mid($new_mid);
    $item->update();

    my $message = 'Moved Item from ' . $item_r->{'project'} . ' to ' . $new_project->name;
    $item->add_comment($user, $message);

    use URI::Escape;
    $self->header_type('redirect');
    $self->header_props(-url => "/item/$iid/?message=" . URI::Escape::uri_escape($message));
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
         $_->{status} = $_->{status};
         $_;
    } @{PMT::Client->all_clients_data($letter)}]);
    $template->param('letters' => \@letters);
    $template->param(clients_mode => 1);
    $template->param(page_title => "All clients ($letter)");
    return $template->output();
}

sub all_groups {
    my $self = shift;
    my $template = $self->template('groups.tmpl');
    $template->param(groups => PMT::User->groups());
    $template->param(page_title => "Groups");
    $template->param(users_mode => 1);
    return $template->output();
}

sub group {
    my $self = shift;
    my $cgi = $self->query();
    my $group = $cgi->param('group') || "";
    my $template = $self->template('group.tmpl');
    $template->param(group_info($group));
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

    $data{'items'} = [map {$_->simple_data()} $milestone->items()];
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
        $data->{users} = $vu->users_in_group();
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
    $data{caretaker_username}   = $caretaker->username;
    $data{milestones}           = $project->project_milestones($sortby, $username);
    $data{personnel}             = [map {$_->data()} $project->personnel()];
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

    $template->param(documents => [map {$_->data()} $project->documents()]);
    $template->param(projects_mode => 1);
    $self->header_add(-cookie => [$cgi->cookie(-name => "pmtsort",
                                               -value => $sortby,
                                               -path => '/',
                                               -expires => "+10y")]);
    return $template->output();

}

sub edit_project_items_form {
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
    $data{caretaker_username}   = $caretaker->username;
    $data{milestones}           = $project->project_milestones_form($sortby, $username);
    $data{personnel}             = [map {$_->data()} $project->personnel()];
    $data{total_remaining_time} = interval_to_hours($project->estimated_time);
    $data{total_completed_time} = interval_to_hours($project->completed_time);
    $data{total_estimated_time} = interval_to_hours($project->all_estimated_time);

    my $table_width = 150;
    ($data{done},$data{todo},$data{free},$data{completed_behind},$data{behind}) = $project->estimate_graph($table_width)
;

    if($works_on) {$data{$works_on} = 1;}
    my $template = $self->template("edit_project_items.tmpl");
    $template->param(\%data);

    $template->param(proj_cc => $project->cc(PMT::User->retrieve($username)));
    $template->param(page_title => "project: $data{name}",
                     month      => $mon,
                     year       => $year);

    my $proj = PMT::Project->retrieve($pid);
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
    my $nid = $cgi->param('nid') || "";
    my $template = $self->template("node.tmpl");
    my $node = PMT::Node->retrieve($nid);
    $template->param($node->data($self->{user}));
    $template->param(page_title => "Forum Node: " . $template->param('subject'),
                     tags => $node->tags(),
                     user_tags => $node->user_tags($self->{user}->{username}));
    return $template->output();
}

sub edit_node_form {
    my $self     = shift;
    my $cgi      = $self->query();
    my $nid      = $cgi->param('nid') || "";
    my $template = $self->template("edit_node.tmpl");
    my $node     = PMT::Node->retrieve($nid);
    $template->param($node->data($self->{user}));
    $template->param(page_title => "Edit Forum Node: " . $template->param('subject'),
                     tags => $node->tags(),
                     user_tags => $node->user_tags($self->{user}->{username}));
    return $template->output();
}

sub edit_node {
    my $self     = shift;
    my $cgi      = $self->query();
    my $nid      = $cgi->param('nid') || "";
    my $subject  = escape($cgi->param('subject')) || "";
    my $body     = escape($cgi->param('body'))    || "";
    my $preview  = $cgi->param('preview')         || "";


    if ($preview eq "preview") {
	my $template = $self->template("edit_node.tmpl");
	my $node     = PMT::Node->retrieve($nid);
	$template->param($node->data($self->{user}));
	$template->param(page_title => "Edit Forum Node: " . $subject,
			 tags       => $node->tags(),
			 preview    => $preview,
			 subject    => $subject,
			 body       => $body);
	return $template->output();
    } else {
	my $node = PMT::Node->retrieve($nid);
	$node->subject($subject);
	$node->body($body);
	$node->update();
	$self->header_type('redirect');
	$self->header_props(-url => "/home.pl?mode=node;nid=$nid");
    }
}

sub staff_report {
    my $self = shift;
    my $cgi = $self->query();
    my ($year,$mon,$mday) = $self->get_date();

    my ($mon_year,$mon_month,$mon_day) = Monday_of_Week(Week_of_Year($year,$mon,$mday));
    my ($sun_year,$sun_month,$sun_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,6);
    my ($pm_year,$pm_month,$pm_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,-7);
    my ($nm_year,$nm_month,$nm_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,7);

    my $previous_week = $cgi->param('previous_week') || 0;
    if ($previous_week) {
	$self->header_type('redirect');
	$self->header_props(-url => "/home.pl?mode=staff_report;year=${pm_year};month=${pm_month};day=${pm_day}");
	return;
    }

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
    my $data = staff_report_data("$mon_year-$mon_month-$mon_day",
				 "$sun_year-$sun_month-$sun_day");
    $template->param($data);
    $template->param(page_title => "Staff Report");
    $template->param(reports_mode => 1);
    return $template->output();
}

sub staff_report_data {
    my $start = shift;
    my $end = shift;
    my @GROUPS = qw/programmers video webmasters educationaltechnologists management devgrp SCPSWebSiteTeam DistanceLearningOffice EducationalTechnologists/;
    my @group_reports = ();
    my $group_max_time = 0;
    foreach my $grp (@GROUPS) {
        my $group_user = PMT::User->retrieve("grp_$grp");
        if ($group_user) {
            my $group_total_time = interval_to_hours($group_user->total_group_time($start,$end));
            my %data = (group => $grp,
                        total_time => $group_total_time,
                        );
            if ($group_total_time > $group_max_time) {
    	       $group_max_time = $group_total_time;
            }
            my $g = PMT::User->retrieve("grp_$grp");
            my @users = ();
            my $max_time = 0;
            foreach my $u (map {$_->data()} $g->users_in_group()) {
                my $user = PMT::User->retrieve($u->{username});
                $u->{user_time} = interval_to_hours($user->interval_time($start,$end)) || 0;
                push @users, $u;
                if ($u->{user_time} > $max_time) {
                    $max_time = $u->{user_time};
                }
            }
            $data{user_times} = \@users;
            $data{max_time} = $max_time;
            push @group_reports, \%data;
        }
    }
    return { groups => \@group_reports, group_max_time => $group_max_time};
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
            $cell .= "<tr><td><a href='/item/$$i{iid}/'>$$i{title}</a></td>";
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
    my $search = $cgi->param('search') || "";

    my $type      = $cgi->param('type') || "";
    my $area      = $cgi->param('area') || "";
    my $approach  = $cgi->param('approach') || "";
    my $scale     = $cgi->param('scale') || "";
    my $distrib   = $cgi->param('distrib') || "";
    my $personnel   = $cgi->param('personnel') || "";
    my $status    = $cgi->param('status') || "";

    my $template = $self->template("project_search_results.tmpl");
    $template->param(results => PMT::Project->project_search(type => $type,
                                                             area => $area,
                                                             approach => $approach,
                                                             scale => $scale,
                                                             distrib => $distrib,
                                                             personnel => $personnel,
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
    my $email_secondary      = $cgi->param('email_secondary') || "";
    my $lastname      = $cgi->param('lastname') || "";
    my $firstname     = $cgi->param('firstname') || "";
    my $title                 = $cgi->param('title') || "";
    my $registration_date = $cgi->param('registration_date') || "";
    my $department    = $cgi->param('department') || '';
    my $school                = $cgi->param('school') || '';
    my $add_affiliation   = $cgi->param('add_affiliation') || "";
    my $phone                 = $cgi->param('phone') || "";
    my $phone_mobile                 = $cgi->param('phone_mobile') || "";
    my $phone_other                 = $cgi->param('phone_other') || "";
    my $contact       = $cgi->param('contact') || "";
    my $comments      = $cgi->param('comments') || "";
    my $status            = $cgi->param('status') || "active";
    my $website_url = $cgi->param('website_url') || "";
    if ($website_url eq "http://") {
        $website_url = '';
    }

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
                         phone_mobile   => $phone_mobile,
                         phone_other    => $phone_other,
                         email               => $client_email,
                         email_secondary    => $email_secondary,
                         contact     => $contact,
                         website_url => $website_url,
                         comments    => $comments,
                         registration_date => $registration_date,
                         projects    => \@projects,
                         );
    $client->update();
    my $letter = uc(substr($lastname,0,1));
    $self->header_type('redirect');
    $self->header_props(-url => "/home.pl?mode=all_clients;letter=$letter");
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
    $data->{inactive} = $data->{status} eq "inactive";
    $data->{potential} = $data->{status} eq "potential";
    $data->{'not interested'} = $data->{status} eq "not interested";
    $template->param(contact_fullname => $contact->fullname);

    delete $data->{email};
    $template->param(%{$data});
    $template->param(projects => $client->projects_data(),
                     projects_select => $client->projects_select(),
                     contacts_select => $client->contacts_select(),
                     schools_select => $client->schools_select(),
                     departments_select => $client->departments_select());
    $template->param(clients_mode => 1);
    return $template->output();
}

sub client_search_form {
    my $self = shift;
    my $cgi = $self->query();
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
        $_->{status} = $_->{status};
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

sub project_custom_report {
    my $self = shift;
    my $cgi = $self->query();
    my $pid = $cgi->param('pid');
    
    my $template = $self->template("project_custom_report.tmpl");

    $template->param(
                     page_title => "Custom Project Report",
                     pid => $pid
                    );
    return $template->output();
}

sub project_months_report {
    my $self = shift;
    my $cgi = $self->query();
    my $pid        = $cgi->param('pid') || "";
    my $num_months = $cgi->param('num_months') || "";

    my $template = $self->template("project_months_report.tmpl");

    # TODO: use actual template for this.
    # will only happen via someone putting in a URL by hand, anyway.
    if($pid eq "") {
       return "Error: Cannot generate project reports without a project ID.";
    }

    my $project = PMT::Project->retrieve($pid);

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
    } else {
        $time_period = "period";
        $time_title = "Custom";
    }

    # get the date parameters that were passed in
    # (not using get_date() because
    #  - a) we don't want to default to the current date
    #  - b) we also want to support options startdate and enddate)
    #my ($year,$month,$mday) = $self->get_date();

    my ($start_year, $start_month, $start_day);
    my ($end_year, $end_month, $end_day);
    my ($prev_options, $next_options) = "";

    # startdate / enddate (for custom reports)
    my $startdate = $cgi->param('startdate') || "";
    my $enddate = $cgi->param('enddate') || "";
    
    if($startdate =~ /(\d+)-(\d+)-(\d+)/ ) {
      $start_year = $1;
      $start_month = $2;
      $start_day = $3;
    }
    if($enddate =~ /(\d+)-(\d+)-(\d+)/ ) {
      $end_year = $1;
      $end_month = $2;
      $end_day = $3;
    }
    
    # didn't get custom start / end dates... use num_months instead
    if($start_year eq "" || $end_year eq "") {
       if($num_months eq "") {
          $num_months = 12;   # default to annual report
       }
       my ($tyear,$tmon,$tday) = todays_date();
       $end_year = $cgi->param('year') || $tyear;
       $end_month = $cgi->param('month') || $tmon;
       $end_day = $cgi->param('day') || $tday;
    }


    # get dates for "previous" and "next" links
    if($start_year ne "") {
       my $distance = Delta_Days($start_year, $start_month, $start_day,
                                 $end_year, $end_month, $end_day);
       my ($p_year, $p_month, $p_day) =  Add_Delta_Days($start_year, $start_month, $start_day,
                                                        -$distance);
       $prev_options = "startdate=$p_year-$p_month-$p_day;" .
                       "enddate=$start_year-$start_month-$start_day;";
       my ($n_year, $n_month, $n_day) = Add_Delta_Days($end_year, $end_month, $end_day,
                                                       $distance);
       $next_options = "startdate=$end_year-$end_month-$end_day;" .
                       "enddate=$n_year-$n_month-$n_day;";
   }
   else {
       my ($p_year, $p_month, $p_day) = Add_Delta_YM($end_year, $end_month, 1, 0, -$num_months);
       my ($n_year, $n_month, $n_day) = Add_Delta_YM($end_year, $end_month, 1, 0, $num_months);

       # calculate start and end dates for the report
       # -- (the date that was passed in is used as the END date,
       #     so an annual report for 9/2007 is from 9/2006 to 9/2007)
       ($start_year, $start_month, $start_day) = Add_Delta_Days($p_year, $p_month, $end_day, 1);

       $prev_options = "year=$p_year;month=$p_month;day=$end_day",
       $next_options = "year=$n_year;month=$n_month;day=$end_day",
    }

    my $start = "$start_year-$start_month-$start_day";
    my $end = "$end_year-$end_month-$end_day";

    $template->param(
                     page_title => "$time_title Project Report",
                     start => $start,
                     end => $end,
                     prev_options => $prev_options,
                     next_options => $next_options,
                     num_months => $cgi->param('num_months') || "",
                     time_period => $time_period,
                     time_title => $time_title,
                     );
    $template->param($project->interval_report($start, $end));
    $template->param($project->data());

    #Min's addition to include forum posts in reports
    my $forum = new Forum($self->{user}->username);
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
            $cell .= "<td><a href='/item/$$i{iid}/'>$$i{title}</a></td>";
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
                     view_username  => $view_user->username,
                     view_fullname => $view_user->fullname,
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

sub summary_over_time {
    # this used to be a "weekly summary" but was expanded
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


sub weekly_summary {
    my $self = shift;
    my $cgi = $self->query();

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

    @groups = map { group_info($_) } @groups;
    $template->param(groups => \@groups);

    $template->param(summary_over_time("$mon_year-$mon_month-$mon_day",
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

sub group_info {
    my $group = untaint_username(shift);
    my $gu = PMT::User->retrieve($group);
    my $data = $gu->user_info();
    $data->{group} = $group;
    $data->{group_name} = $data->{user_fullname};
    $data->{group_select_list} = group_users_select_list($group);
    $data->{users} = [map {$_->data()} $gu->users_in_group()];
    $data->{group_nice_name} = $data->{group_name};
    $data->{group_nice_name} =~ s/\s+\(group\)\s*$//g;
    return $data;
}

# creates a datastructure that can be used to
# create a select list of users for a group.
# lists every active user with
#   value => their username
#   label => their fullname
#   selected => whether or not they are part of the group
sub group_users_select_list {
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

sub monthly_summary {
    my $self = shift;
    my $cgi = $self->query();

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
    @groups = map {group_info($_) } @groups;
    $template->param(groups => \@groups);
    $template->param(summary_over_time("$mon_year-$mon_month-$mon_day",
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

sub yearly_review {
    my $self = shift;
    my $cgi = $self->query();

    my ($year,$mon,$mday) = $self->get_date();

    my ($start_year,$start_month,$start_day) = ($year - 1,$mon,$mday);
    my ($end_year,$end_month,$end_day) = Add_Delta_Days($start_year,$start_month,$start_day,
							366);

    my $template = $self->template("yearly_summary.tmpl");
    $template->param(
	start_year => $start_year,
	start_month => $start_month,
	start_day => $start_day,
	end_year => $end_year,
	end_month => $end_month,
	end_day => $end_day,
	);

    my $user = $self->{user};

    #check is user is a group
    my $data = group_info($user);
    $template->param($user->weekly_report("$start_year-$start_month-$start_day",
                                               "$end_year-$end_month-$end_day"));
    $template->param(page_title => "yearly report for ${user}->{username}");
    $template->param(user_username => $user->{username});
    $template->param(user_fullname => $user->{fullname});
    $template->param(reports_mode => 1);
    $template->param(posts => [map {$_->data()}
			       sort { $b->added cmp $a->added}
			       PMT::Node->user_posts_in_range($user->username,"$start_year-$start_month-$start_day",
							      "$end_year-$end_month-$end_day")]);
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
        $total = PMT::Node->num_posts($user);
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
    if($pid eq "") {
      return "Error: Must specify a Project ID.";
    }
      
    my $project = PMT::Project->retrieve($pid);

    my ($year,$mon,$mday) = $self->get_date();

    my ($mon_year,$mon_month,$mon_day) = Monday_of_Week(Week_of_Year($year,$mon,$mday));
    my ($sun_year,$sun_month,$sun_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,6);
    my ($pm_year,$pm_month,$pm_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,-7);
    my ($nm_year,$nm_month,$nm_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,7);

    my $start = "$mon_year-$mon_month-$mon_day";
    my $end   = "$sun_year-$sun_month-$sun_day";

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
    $template->param($project->interval_report($start, $end));
    $template->param($project->data());

    #Min's addition to include forum posts in reports
    my $forum = new Forum($self->{user}->username);
    $template->param(posts => $forum->project_posts_by_time($pid, $start, $end));

    return $template->output();
}

# tries to get the date from parameters,
# defaults to the current date
sub get_date {
    my $self = shift;
    my $cgi = $self->query();

    my ($tyear,$tmon,$tday) = todays_date();
    
    my $year = $cgi->param('year') || $tyear;
    my $mon = $cgi->param('month') || $tmon;
    my $day = $cgi->param('day') || $tday;
    
    return ($year,$mon,$day);
}

sub user_weekly_report {
    my $self = shift;
    my $cgi = $self->query();
    my $user = $cgi->param('username') || "";
    my $view_user = PMT::User->retrieve($user);
    my ($year,$mon,$mday) = $self->get_date();

    my ($mon_year,$mon_month,$mon_day) = Monday_of_Week(Week_of_Year($year,$mon,$mday));
    my ($sun_year,$sun_month,$sun_day) = Add_Delta_Days($mon_year,$mon_month,$mon_day,6);
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
    my $data = group_info($user);
    $template->param($view_user->weekly_report("$mon_year-$mon_month-$mon_day",
                                               "$sun_year-$sun_month-$sun_day"));
    $template->param(page_title => "weekly report for $user");
    $template->param(user_username => $user);
    $template->param(user_fullname => $view_user->fullname);
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

    if ($employee ne "all") {
      my $user = PMT::User->retrieve($employee);
      $template->param('employee' => $user->fullname);
    }

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

sub deactivate_user {
    my $self = shift;
    my $q = $self->query();
    my $username = $q->param('username') || "";
    my $template = $self->template("deactivate_user.tmpl");
    if ($username) {
        my $deactivate_user = PMT::User->retrieve($username);
        my $deactivate_fullname = $deactivate_user->fullname || "";
        my $user = $self->{user};
        my $complete = $q->param('complete') || "";
        if ($complete) {
            # do the deactivation and reassignments
            my %params = $q->Vars();
            foreach my $k (keys %params) {
                # - do caretaker reassignments
                if ($k =~ /^caretaker_(\d+)$/) {
                    my $project = PMT::Project->retrieve($1);
                    my $caretaker = PMT::User->retrieve($params{$k});
                    $project->set_caretaker($caretaker);
                    $project->update();
                }
                # - do reassignments
                if ($k =~ /assigned_to_(\d+)/) {
                    my $item = PMT::Item->retrieve($1);
                    my $assignee = PMT::User->retrieve($params{$k});
                    $item->assigned_to($assignee);
                    $item->add_event($item->status,"Deactivating user " . $deactivate_user->fullname,$user);
                    $item->update();
                }
                if ($k =~ /owner_(\d+)/) {
                    my $item = PMT::Item->retrieve($1);
                    my $owner = PMT::User->retrieve($params{$k});
                    $item->owner($owner);
                    $item->add_event($item->status,"Deactivating user " . $deactivate_user->fullname,$user);
                    $item->update();
                }
            }
            # - remove user from any groups
            $deactivate_user->remove_from_all_groups();

            # - deactivate user
            $deactivate_user->status("inactive");
            $deactivate_user->update();

        } else {
            # present them with a list of items and projects
            # to reassign
            my $caretaker_projects = [map {
                {
                    name             => $_->name,
                    pid              => $_->pid,
                    caretaker_select => $_->new_caretaker_select($user)
                    }
            } $deactivate_user->projects()];
            $template->param(caretaker_projects => $caretaker_projects);

            my $assigned_items = [map {
                my $i = $_;
                my $item = PMT::Item->retrieve($i->{iid});
                if ($item->assigned_to->username eq $deactivate_user->username) {
                    # reassign item
                    $i->{assigned_to_select} = $item->mid->pid->new_assigned_to_or_owner_select($deactivate_user,$user);
                } else {
                    $i->{assigned_to_fullname} = $item->assigned_to->fullname;
                }
                if ($item->owner->username eq $deactivate_user->username) {
                    # change owner
                    $i->{owner_select} = $item->mid->pid->new_assigned_to_or_owner_select($deactivate_user,$user);
                } else {
                    $i->{owner_fullname} = $item->owner->fullname;
                }
                $i;
            } @{$deactivate_user->items($user->username)}];
            $template->param(assigned_items => $assigned_items);

            if (!@$caretaker_projects && !@$assigned_items) {
                # - remove user from any groups
                $deactivate_user->remove_from_all_groups();

                # - deactivate user
                $deactivate_user->status("inactive");
                $deactivate_user->update();
                $complete = 1;
            }
        }
        $template->param(complete => $complete);
        $template->param(deactivate_username => $deactivate_user->username);
        $template->param(deactivate_fullname => $deactivate_user->fullname);
        return $template->output();
    } else {
        $template->param(users_select => PMT::User::users_select());
        return $template->output();
    }
}

#
# Send a custom user email to an arbitrary recipient from the item view,
# referencing the item specified
#
sub send_custom_email {
    my $self = shift;
    my $cgi = $self->query();
    my $iid = $cgi->param('iid');
    my $user = $self->{user};
    my $view_message;

    my $config = new PMT::Config;
    if ($config->{enable_custom_emails}) {
        my $item = PMT::Item->retrieve($iid);
        my $item_r = $item->full_data();
        my $to = $cgi->param('send_email_to');
        my $from = $user->{email};
        my $subject = "[pmt:$iid] $item_r->{title}";
        my $reply_to = '';
        my $reply_to_inline = '';
        if ($config->{importer_pop3_replyto}) {
            $reply_to = $config->{'importer_pop3_replyto'};
            $reply_to_inline = "Reply-To: $config->{'importer_pop3_replyto'}\n";
        }
        my $message = $cgi->param('send_email_body');

        my $item_history = '';
        if ($cgi->param('send_email_history')) {
            $item_history = "----\nItem History\n----\n";
            foreach my $hitem (@{$item_r->{full_history}}) {
                my $comment = $hitem->{'comment'};
                $comment =~ s/<(?:[^>'"]*|(['"]).*?\1)*>/ /gs;
                my $status = $hitem->{'status'} ? $hitem->{'status'} : '';
                $item_history .= "on $hitem->{'timestamp'} by $hitem->{'fullname'}:\n";
                $item_history .= "status: $status\n";
                $item_history .= "comment: $comment\n\n";
            }
        }

        $ENV{PATH} = "/usr/sbin";
        open(MAIL,"|/usr/sbin/sendmail -t");
        print MAIL <<END_MESSAGE;
From: $from
To: $to
Subject: $subject
$reply_to_inline
$message

to respond to this message, reply to $reply_to (usually, clicking the 'Reply' button on your email client will do this)

$item_history
END_MESSAGE
        CORE::close MAIL;
        print STDERR "sent custom email out";

        my $log = "<p><b>sent email to: $to.";
        if ($cgi->param('send_email_history')) {
            $log .= " item history was appended.";
        }
        $log .= "</b></p>";
        $log .= "<p>$message</p>";
        $item->add_comment($user,$log);

        $view_message = 'Email sent.';
    } else {
        $view_message = 'Custom emails are not enabled.';        
    }
    use URI::Escape;
    $self->header_type('redirect');
    $self->header_props(-url => "/item/$iid/?message=" . URI::Escape::uri_escape($view_message));
    return $view_message;
}

1;

