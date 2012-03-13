#!/bin/bash

. /projects/alarms/.bashrc
cd /projects/alarms/current

rake deliver:$1 > /projects/alarms/shared/cron/deliver/$1.last 2>&1