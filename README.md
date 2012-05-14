A government-wide search and notification system, called Scout.

Sinatra is used for the web framework, MongoDB for the database, Postmark for email delivery, HTTParty for API consumption.

The architecture is conceived of as a series of tubes that receive search result data from remote APIs that users can subscribe to for updates. Each type of data that comes into the system (bills in Congress, federal regulations, etc.) is defined a set of small adapters to consume that data and display it in a variety of places.

[![Build Status](https://secure.travis-ci.org/sunlightlabs/scout.png)](http://travis-ci.org/sunlightlabs/scout)