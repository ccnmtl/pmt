#!/usr/bin/perl -w

#
# Imports items from various sources (e.g. email, which is the only source
# currently supported). Set this up as a scheduled task (e.g. cron).
#
# See /doc/item_importer.txt for dependency & config info, as well as details 
# on extending functionality.
#
# TODO: refactor and dynamically load/instantiate importers from settings in config
#

use strict;
use lib qw(.);
use PMT;
use PMT::Common;
use PMT::Config;
use PMT::Client;
use Data::Dumper;
use PMT::POP3ItemImporter;

open (STDERR, ">importer.log");

# setup
my $pop3 = new PMT::POP3ItemImporter;
$pop3->connect();

# import items
#while (my $item = $pop3->test_next(3)) {
while (my $item = $pop3->next()) {
    import_item($item);
}
#$pop3->test_connection();

# finish up
$pop3->close();

close(STDERR);

###########################################################
sub import_item {
    my $item = shift;
    warn "Importing...\n";
    warn $item->{from} . "\n";
    warn $item->{subject} . "\n";
    warn $item->{body} . "\n";

    my $config = new PMT::Config;
    my $username = $config->{importer_user};
    my $type = 'action item';
    my $pid = $config->{importer_pid};
    my $project = PMT::Project->retrieve($pid);
    my $mid = $project->upcoming_milestone();
    my $milestone = PMT::Milestone->retrieve($mid);
    my $target_date = $milestone->target_date;
    my $title = escape($item->{subject}) || "no title";
    # TODO: Add separate assigned-to user in importer config?
    my $assignee  = $username;
    my $owner = $username;
    my $description = "Received Via " . $item->{delivery_method} . " From: " . $item->{from} . "\n\n" . $item->{body};
    # TODO: Add client check support
    my @clients;
    my @tags;
    if (my $client = PMT::Client->retrieve('email' => $item->{from})) {
        push(@clients, $client->{client_id});
    }

    my %item = (type         => $type,
                pid          => $pid,
                mid          => $mid,
                title        => $title,
                assigned_to  => $assignee,
                owner        => $owner,
                priority     => '',
                target_date  => $target_date,
                url          => '',
                description  => $description,
                tags         => \@tags,
                clients      => \@clients,
                estimated_time => 0,
               );

    my $iid = PMT::Item::add_item(\%item);
    warn "Item $iid created\n\n";
}