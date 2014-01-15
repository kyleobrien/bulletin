bulletin
========

A link-blog, static site generator built on top of Pinboard. Modeled after the [Linked List](http://daringfireball.net/linked/) side of Daring Fireball and [Waxy Links](http://waxy.org/links/).

This is meant as a prototype for a more robust, self-hosted service.

Changelog
========

0.8.2 - Was not tracking changes, since the initial 0.8.0 release.

Component List
============

+ Server (DigitalOcean)
+ Web Server (Nginx)
+ Ruby
+ Ruby Games
  + aws-s3
  + json
  + redcarpet
  + zip
+ Cron
+ Pinboard Account
+ (optional) Amazon Web Services Accoutn with S3 Access

Pseudocode
==========

1. Cron launches process at predetermined interval, once a day.
2. Grab items you posted to Pinboard that have a special tag.
3. Pull out all items posted in the last 24 hours.
4. Create a web page with those items.
5. Archive the items for the day in a JSON file.
6. Create ann RSS feed.
7. Zip up content of site and backup to Amazon S3. 

License
=======

Code is available under a BSD-style license. See the included LICENSE file for details.

