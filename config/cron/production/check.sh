#!/bin/bash

. /projects/scout/.bashrc
cd /projects/scout/current

rake subscriptions:check:$1 > /projects/scout/shared/cron/check/$1.last 2>&1