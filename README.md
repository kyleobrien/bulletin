bulletin
========

A static site generator built on top of Pinboard.

Dependencies
============

+ Server (using EC2)
+ Web Server (using lighttpd)
+ Ruby
  + Gem 1
  + Gem 2
+ Cron
+ Pinboard account

Notes to Self
=============

// Have to download a package to extend yum.
get http://packages.sw.be/rpmforge-release/rpmforge-release-0.5.2-2.el6.rf.x86_64.rpm
rpm --import http://apt.sw.be/RPM-GPG-KEY.dag.txt
rpm -K rpmforge-release-0.5.2-2.el6.rf.*.rpm
rpm -i rpmforge-release-0.5.2-2.el6.rf.*.rpm

// Install lighttpd
yum install lighttpd

// start lighttpd after configuration
/etc/init.d/lighttpd start

// CONFIGURE IPATBLES!
vim /etc/sysconfig/iptables
-A INPUT -m tcp -p tcp --dport 80 -j ACCEPT

// Install Ruby
yum install ruby
yum install ruby-devel
yum install irb
yum install rubygems
yum install gcc
yum install make

// File location
/var/www/


