# devdnsd

A small DNS server to enable local .dev domain resolution.
http://github.com/ShogunPanda/devdnsd

## Description

DevDNSd is a small DNS server which add a resolver to the system only for single TLD (by default, **.dev**). This way you can access your local application by typing every kind of url, i.e. *locallapp.dev*.

Of course, DevDNSd is inspired by [pow](https://github.com/37signals/pow), but it only provides DNS functionalities, delegating the setup of a web-server to the user.

## Basic usage

1. Install the gem:

	`gem install devdnsd`

2. Install the service:

	`devdnsd install`

**You're done!**

## Advanced usage

Just type `devdns help` and you'll see all available options.

## Configuration

By defaults, DevDNSd uses a configuration file in `~/.devdnsd_config`, but you can change the path using the `--config` switch.

The file is a plain Ruby file with a single `config` object that supports the following directives.

* `foreground`: If run the application in foreground.
* `address`: The IP to bind, 0.0.0.0 by default.
* `port`: The port to bind, 7771 by default.
* `tld`: The TLD to handle.
* `log_file`: The default log file. Not used if run in foreground.
* `log_level`: The default log level. Valid values are from 0 to 5 where 0 means "all messages".
* `add_rule`: Add a rule to the server. See section *Rules* below.

## Rules

DevDNSd has a nice rules system for matching name.
You can add rules by calling `config.add_rule(...)` into the configuration file.

The first argument of the function is the name you want to match. You can use regular expressions and this is highly recommended if you want to pass a block to the method (see below).

The second argument should be the IP associated to the name. You can use `false` to reject matching for this nameserver. In this case the next nameserver for the system will be used. You can skip this argument if you pass a block to the function.

The third argument can optionally be the record type for the resolv. By default is `:A`.
This argument is ignored if you pass the block, as it assumes that the second argument is the record type.

If you pass a block to the method, its return code will be taken as the result of the resolving. So if you return `false` then the resolving will be rejected. The block takes two arguments, `match` and `transaction`. If you used regular expression for the first argument, then `match` will contain all the match information for the name.

For some examples of rules, see the `config/devdnsd_config.sample` file into the repository.

## Remarks

DevDNSd is tightly coupled with the OSX name resolution system, so it is only available for MacOSX.

## Contributing to devdns

* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it
* Fork the project
* Start a feature/bugfix branch
* Commit and push until you are happy with your contribution
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## Copyright

Copyright (C) 2012 and above Shogun <[shogun_panda@me.com](mailto:shogun_panda@me.com)>.
Licensed under the MIT license, which can be found at [http://www.opensource.org/licenses/mit-license.php](http://www.opensource.org/licenses/mit-license.php).
