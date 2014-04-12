#!/bin/bash

. /projects/scout/.bashrc
cd /projects/scout/current

RACK_ENV=production rake deliver:$1 > /projects/scout/shared/cron/deliver/$1.last 2>&1