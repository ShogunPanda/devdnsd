# devdnsd

[![Gem Version](https://badge.fury.io/rb/devdnsd.png)](http://badge.fury.io/rb/devdnsd)
[![Dependency Status](https://gemnasium.com/ShogunPanda/devdnsd.png?travis)](https://gemnasium.com/ShogunPanda/devdnsd)
[![Build Status](https://secure.travis-ci.org/ShogunPanda/devdnsd.png?branch=master)](http://travis-ci.org/ShogunPanda/devdnsd)
[![Code Climate](https://codeclimate.com/github/ShogunPanda/devdnsd.png)](https://codeclimate.com/github/ShogunPanda/devdnsd)
[![Coverage Status](https://coveralls.io/repos/ShogunPanda/devdnsd/badge.png)](https://coveralls.io/r/ShogunPanda/devdnsd)
[![Bitdeli Trend](https://d2weczhvl823v0.cloudfront.net/ShogunPanda/devdnsd/trend.png)](https://bitdeli.com/free "Bitdeli Badge")
<iframe src="http://ghbtns.com/github-btn.html?user=ShogunPanda&repo=devdnsd&type=fork&count=true" allowtransparency="true" frameborder="0" scrolling="0" width="135" height="20"></iframe>

A small DNS server to enable local .dev domain resolution.

http://sw.cow.tc/devdnsd

http://rdoc.info/gems/devdnsd

## Description

DevDNSd is a small DNS server which add a resolver to the system only for single TLD (by default, **.dev**). This way you can access your local application by typing every kind of url, i.e. *locallapp.dev*.

Of course, DevDNSd is inspired by [pow](https://github.com/37signals/pow), but it only provides DNS features, delegating the setup of a web-server to the user.

## Basic usage

1. Install the gem:

	`gem install devdnsd`

2. Install the service:

	`devdnsd install`

**You're done!**

## Dual stack (IPv4/IPv6) usage

If you experience slowness in resolving host from clients (Chrome, curl etc.) when you don't specify the address type, make sure you have both a `A` and `AAAA` rules set for the same host, like this:

```ruby
config.add_rule(/\.dev$/, "127.0.0.1")
config.add_rule(/\.dev$/, "::1", :AAAA)
```

## Advanced usage

Just type `devdnsd help` and you'll see all available options.

## Configuration

By defaults, DevDNSd uses a configuration file in `~/.devdnsd/default.conf`, but you can change the path using the `--config` switch.

The file is a plain Ruby file with a single `config` object that supports the following directives.

* `foreground`: If run the application in foreground.
* `address`: The IP to bind, 0.0.0.0 by default.
* `port`: The port to bind, 7771 by default.
* `pid_file`: The PID file to use.
* `tld`: The TLD to handle.
* `log_file`: The default log file. Not used if run in foreground.
* `log_level`: The default log level. Valid values are from 0 to 5 where 0 means "all messages".
* `add_rule`: Add a rule to the server. See section *Rules* below.

## Rules

DevDNSd has a nice rules system for matching name.
You can add rules by calling `config.add_rule(...)` into the configuration file.

The first argument of the function is the name you want to match. You can use regular expressions and this is highly recommended if you want to pass a block to the method (see below).

The second argument should be the IP associated to the name. If the first argument is a regexp with groups, you can use the standard Ruby `String#gsub` substitution syntax for the reply.
You can also use `false` to reject matching for this nameserver. In this case the next nameserver for the system will be used. You can skip this argument if you pass a block to the function.
If you return `nil` from the block, then you'll be responsible to set the response via the [`transaction`](http://rubydoc.info/gems/rubydns/RubyDNS/Transaction) variable.

The third argument can optionally be the record type for the resolv. By default is `:A`.
This argument is ignored if you pass the block, as it assumes that the second argument is the record type.

If you pass a block to the method, its return code will be taken as the result of the resolving. So if you return `false` then the resolving will be rejected. The block takes three arguments, `match`, `type` and `transaction`. If you used regular expression for the first argument, then `match` will contain all the match information for the name.

For some examples of rules, see the `config/devdnsd_config.sample` file into the repository.

## Remarks

DevDNSd as a local resolver is tightly coupled with the OSX name resolution system, so it is only available for MacOSX.

You can, anyway, run the software as DNS server.

## Contributing to devdnsd

* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## Copyright

This software have been made possible by the awesome job of [Samuel Williams](https://github.com/ioquatix), with his [RubyDNS](https://github.com/rubydns) and [RExec](https://github.com/rexec) gems.

Copyright (C) 2013 and above Shogun (shogun@cowtech.it).

Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
