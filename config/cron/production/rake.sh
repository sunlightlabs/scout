#!/bin/bash

. /projects/scout/.bashrc
cd /projects/scout/current

rake $1 > /projects/scout/shared/cron/$1.last 2>&1