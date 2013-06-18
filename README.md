# Scout

A government-wide search and notification system. Currently deployed to [scout.sunlightfoundation.com](https://scout.sunlightfoundation.com/). [![Build Status](https://secure.travis-ci.org/sunlightlabs/scout.png)](http://travis-ci.org/sunlightlabs/scout)


## Setting Up

Scout depends on **Ruby 2.0**.

**Recommended**: use [rvm](https://rvm.io/) to install Ruby 2.0 and create a virtual environment for the project.

Install included dependencies with:

```bash
bundle install --local
```

Create configuration files:

```bash
cp config.ru.example config.ru
cp config/config.yml.example config/config.yml
```

Change anything in `config.yml` that needs to be changed. Among other things, you will need to add your own Sunlight API key.

Then run the app on port 8080 with:

```
bundle exec unicorn
```


## Re-use

We'd really love it if others used the Scout codebase to set up their own alert system. To that end, Scout's architecture is fairly well decoupled from the specific data sources that Sunlight's implementation currently uses.

But if you do want to set this up yourself, there will surely turn out to be more to do! Send [konklone](/konklone) a message if this is something you're interested in.
