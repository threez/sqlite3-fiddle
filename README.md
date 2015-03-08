# Sqlite3 Fiddle

This is a fork of the original sqlite3-ruby gem. It replaces the original C extension with a fiddle based replacement.

Sometimes the problem is, that one has a system like a synology NAS, that has a ruby interpreter and a recent version
of libsqlite3, but no c compiler and headers installed. To not manually compile the extension i replaced its
base functionality with ruby fiddle. A stdlib to dynamically use shared libraries.

I copied a lot of the original code, so that this replacement behaves exactly like the original. There is however
no guarantee, that it actually behaves in all cases exactly the same. The problem is, that there is a long history
in the c code and it is in parts not very clear or easy to understand (no offence). Especially the function and
aggregate interface is very unituitively implemented. The test suite used is the original unchanged.

So far all test are passing with ruby 2.1.x and a recent version of libsqlite3.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sqlite3-fiddle'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sqlite3-fiddle

## Usage

Should be used like the [sqlite3-ruby](https://github.com/sparklemotion/sqlite3-ruby) gem.

By default the libsqlite3 is searched in the regular way that shares libraries are found. If one wants to explicitly change the location to the libsqlite3, do it either using the global `$LIBSQLITE3` or using the environment variable `LIBSQLITE3`. In both cases the full path inclusive extension has to be used to specify the lib to use. Example:

		LIBSQLITE3=/usr/local/Cellar/sqlite/3.8.8.3/lib/libsqlite3.dylib rake

## Contributing

1. Fork it ( https://github.com/[my-github-username]/sqlite3-fiddle/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
