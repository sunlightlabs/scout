#!/bin/bash

. /projects/alarms/.bashrc
cd /projects/alarms/current

FIRST=$1
shift
rake subscriptions:check:$FIRST $@ > /projects/alarms/shared/cron/check/$FIRST.last 2>&1