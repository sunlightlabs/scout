#!/bin/bash

today=$(date +%Y%m%d)

cd /home/eric/backups


# maintain a whitelist of collections to dump.
# Obviously: must be updated when new collections are added to the system!

# clear any existing, possibly aborted, past dumps
rm -rf dump
rm *.tgz

# easy to store, but easy to restore too
mongodump --db=scout --collection=agencies
mongodump --db=scout --collection=definitions
mongodump --db=scout --collection=legislators
mongodump --db=scout --collection=citations
mongodump --db=scout --collection=system.indexes

# growth should be manageable for some time
mongodump --db=scout --collection=events
mongodump --db=scout --collection=receipts
mongodump --db=scout --collection=reports

# absolutely vital: must be saved
mongodump --db=scout --collection=interests
mongodump --db=scout --collection=subscriptions
mongodump --db=scout --collection=tags
mongodump --db=scout --collection=users

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
# mongodump --db=scout --collection=seen_items

# blacklisted:
#
# items are huge, and for purely caching/sitemap purposes.
# they can be restored using the instructions in reindex.md.
# mongodump --db=scout --collection=items
#
# caches are huge, and also purely caching. can be restored through normal site use.
# mongodump --db=scout --collection=caches
#
# deliveries are an ephemeral queue. anything that might happen to be backed up,
# should not be restored, for fear of re-delivery of old items.
# mongodump --db=scout --collection=deliveries

# as of 2014-05-04, /dump takes up 1.1G
# as of 2014-05-04, $today.tgz takes up 135M
tar -czvf $today.tgz dump

s3cmd put $today.tgz s3://scout-assets/scout/backups/mongo-scout/$today.tgz

rm -rf dump
rm $today.tgz
