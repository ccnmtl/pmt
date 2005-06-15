#!/bin/bash
COMMON_DIR=/usr/local/share/sandboxes/common
PMT_DIR=$COMMON_DIR/pmt2
export CVS_RSH=ssh
cd $PMT_DIR
sudo -H -u pusher $MAKE cvsupdate

