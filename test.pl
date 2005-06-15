#!/usr/bin/perl -w

# File: test.pl
# Time-stamp: <Fri Dec 21 14:06:53 2001>
#
# Copyright (C) 2001 by anders pearson
#
# Author: anders pearson
#
# Description:
# 
# trying out CVS  giddyup.

use strict;
use lib qw(.);
use Test::Harness;

runtests("t/load.t");
runtests("t/user.t");
runtests("t/project.t");
runtests("t/milestone.t");
runtests("t/item.t");
runtests("t/client.t");
runtests("t/model.t");
runtests("t/cleanup.t");
