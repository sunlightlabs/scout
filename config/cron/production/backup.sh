#!/bin/bash

# Scout backup script. It's not the best, but it works.
# TODO:
# * Version on database server should be properly synced to version control.
# * Should run from a different server than the database server.
# * Should be burned down to the ground and turned into a proper backup system.

DUMP_PATH="/home/ubuntu/bkups"
DUMP_DIR="${DUMP_PATH}/dump"
S3_PATH="s3://scout-assets/scout/backups/mongo-scout"

today=$(date +%Y%m%d)
two_weeks_ago=$(date +%Y%m%d --date '14 days ago')

# do things in directory
cd $DUMP_PATH

# so ... there used to be an ip for the mongo host here ... 
# i removed it and just run this from the mongo host
MONGODUMP="mongodump --db=scout"

# maintain a whitelist of collections to dump.
# Obviously: must be updated when new collections are added to the system!

# clear any existing, possibly aborted, past dumps
##rm -rf dump
##rm *.tgz

# easy to store, but easy to restore too
$MONGODUMP --collection=agencies
$MONGODUMP --collection=definitions
$MONGODUMP --collection=legislators
$MONGODUMP --collection=citations
$MONGODUMP --collection=system.indexes

# growth should be manageable for some time
$MONGODUMP --collection=events
$MONGODUMP --collection=receipts
$MONGODUMP --collection=reports

# absolutely vital: must be saved
$MONGODUMP --collection=interests
$MONGODUMP --collection=subscriptions
$MONGODUMP --collection=tags
$MONGODUMP --collection=users

# seen_items is huge (1.7M items as of this writing, takes a while to write),
# but it's worth backing up if possible.
#
# The growth curve could be seriously bent downwards by addressing:
# https://github.com/sunlightlabs/scout/issues/410
#
# But this would not solve the problem -- these 1.7M are already post-restore,
# and represent close to the original ~40 items per-subscription. It's just a lot
# of stuff.
#
# As of right now, it takes up too much disk space, so disabling.
# I would prefer this be backed up, though.
#
# $MONGODUMP --collection=seen_items


# blacklisted:
#
# items are huge, and for purely caching/sitemap purposes.
# they can be restored using the instructions in reindex.md.
# $MONGODUMP --collection=items
#
# caches are huge, and also purely caching. can be restored through normal site use.
# $MONGODUMP --collection=caches
#
# deliveries are an ephemeral queue. anything that might happen to be backed up,
# should not be restored, for fear of re-delivery of old items.
# $MONGODUMP --collection=deliveries

# as of 2014-05-04, /dump takes up 1.1G
# as of 2014-05-04, $today.tgz takes up 135M
tar -czvf $today.tgz $DUMP_DIR

# put to s3
s3cmd put $today.tgz ${S3_PATH}/$today.tgz

# cleanup locally
rm -rf $DUMP_DIR
rm $today.tgz

# cleanup globally
s3cmd del ${S3_PATH/$two_weeks_ago.tgz
