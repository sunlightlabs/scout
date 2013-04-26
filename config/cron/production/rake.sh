#!/bin/bash

. /projects/scout/.bashrc
cd /projects/scout/current

FIRST=$1
shift
rake $FIRST $@ > /projects/scout/shared/cron/$FIRST.last 2>&1