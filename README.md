# Scout

A government-wide search and notification system. Currently deployed to [scout.sunlightfoundation.com](https://scout.sunlightfoundation.com/).

[![Build Status](https://secure.travis-ci.org/sunlightlabs/scout.png)](http://travis-ci.org/sunlightlabs/scout)

## Setting Up

Scout can run on **Ruby 1.9 and up**. It's currently developed on Ruby 2.1.

**Recommended**: use [rbenv](https://github.com/sstephenson/rbenv) to install Ruby 2.1 to your home directory.

You need a MongoDB server. Scout will create its own database and collections as needed.

After a `gem install bundler`, install included dependencies with:

```bash
bundle install --local
```

Create configuration files:

```bash
cp config.ru.example config.ru
cp config/config.yml.example config/config.yml
```

Change anything in `config.yml` that needs to be changed. Among other things, you will need to add your own Sunlight API key. You can get an API key [here](http://sunlightfoundation.com/api/accounts/register/). You can change the MongoDB configuration in this file if you need to.

Then run the app on port 8080 with:

```
bundle exec unicorn
```

## What It Does

* Alice visits the [Scout website](https://scout.sunlightfoundation.com/) and searches for terms of interest to her, e.g. ["intellectual property"](https://scout.sunlightfoundation.com/search/all/intellectual%20property).
* Alice subscribes to be sent messages via email when new items are published for those search terms: that is, new items related to her interest.
* Soon after new items are published, Alice receives one email message per interest, which may contain multiple new items.

### Notification settings

Alice may [log in](https://scout.sunlightfoundation.com/login) to [configure notification settings](https://scout.sunlightfoundation.com/account/settings):

* She may add and verify a phone number to receive SMS messages in addition to email messages. If so, she receives one SMS message per interest.
* She may change the email frequency from "immediate" to "daily", or turn off all notifications. If daily, she receives a single email message for all interests once per day.
* She may [configure interests](https://scout.sunlightfoundation.com/account/subscriptions) to have different notification settings: she may set a notification to be sent immediately, daily or via SMS only, or she may turn off notifications for the interest.

### Collections

* Alice may [tag interests](https://scout.sunlightfoundation.com/account/subscriptions). All interests with the same tag are called a *collection* of interests.
* Collections are private by default, but if Alice fills in her user profile, she may share the collection in public.
* Bob may subscribe to Alice's collection to be sent messages when new items are published related to the interests in the collection. If Alice makes the collection private again, Bob will no longer receive messages.

### Other features

Scout also implements an "RSS/Atom to Email/SMS" feature.

## Under the Hood

* Scout checks for new items in multiple data sources. To add a new data source, you must write a *subscription adapter*. The adapter tells Scout how to query the data source with the search terms provided by its users.
* When users subscribe to be sent messages, they create an *interest*. The user may choose to receive new items for all data sources, or just one. An interest will have one or more *subscriptions* per data source.

## Re-use

We'd really love it if others used the Scout codebase to set up their own alert system. To that end, Scout's architecture is fairly well decoupled from the specific data sources that Sunlight's implementation currently uses.

But if you do want to set this up yourself, there will surely turn out to be more to do! Send [konklone](https://github.com/konklone) a message if this is something you're interested in.

Copyright (c) 2011-2013 Sunlight Foundation, [released](https://github.com/sunlightlabs/scout/blob/master/LICENSE) under the [GNU General Public License, Version 3](http://www.gnu.org/licenses/gpl-3.0.txt).
