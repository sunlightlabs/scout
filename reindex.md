If reindexing external content -

    rake usc:load
    rake glossary:load
    rake agencies:load
    rake legislators:load

If re-syncing cached content (items collection) (for sitemaps and google) -

    rake sync type=speeches since=2014 && rake sync type=speeches since=2013 && rake sync type=speeches since=2012 && rake sync type=speeches since=2011 && rake sync type=speeches since=2010 && rake sync type=speeches since=2009

    rake sync type=documents since=all

    rake sync type=federal_bills since=all

    rake sync type=regulations since=all

    rake sync type=state_bills since=all

If re-initializing subscriptions -

    # (ensure subscriptions are marked as `initialized: false`)
    # pick a `minutes` value below for it to run (defaults to 25)

    rake subscriptions:reinitialize minutes=25