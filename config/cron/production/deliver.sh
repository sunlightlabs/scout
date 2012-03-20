#!/bin/bash

. /projects/scout/.bashrc
cd /projects/scout/current

rake deliver:$1 > /projects/scout/shared/cron/deliver/$1.last 2>&1