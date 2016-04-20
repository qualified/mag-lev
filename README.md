# MagLev

Lift your Rails app with additional conventions and utilities that will turbo charge your development. These include: 

- **Listeners**: Leverage listeners to cleanly manage cross-cutting concerns. 
- **Service Objects**: Leverage service objects to wrap complicated functionality and easily execute that logic within a backend queue.
- **Serializers**: JBuilder is slow, use our serializers instead to write clean and maintainable JSON serialization logic.
- **Current User**: Manage which user is currently acting on the data
- **Sidekiq Extensions**: Sidekiq is integrated into all conventions with a number of productivity improvements, including:
    - Ability to track the current user across backend tasks
    - Unique jobs to prevent redundant tasks from being ran
    - Listener integration
    - Timeouts
    - Reliability feature (currently requires MongoDB)
    - Better error handling
    - Improved serialization for automatically serializing objects via GlobalID, Yaml and special handling for destroyed models
- **Statsd Integration**: The framework is preconfigured and ready to start logging essential data with Statsd
- **Utilities**: Features such as UnitOfWork, Try, Guard, Lock, Memo and error reporting.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'mag-lev'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install mag-lev

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/maglev.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

