# MagLev
[![Build Status](https://travis-ci.org/jhoffner/mag-lev.svg?branch=master)](https://travis-ci.org/jhoffner/mag-lev)

Lift your Rails app with additional conventions and utilities that will turbo charge your development. These include:
 

- **Listeners**: Leverage listeners to cleanly manage cross-cutting concerns. 
- **Serializers**: JBuilder is slow, use our serializers instead to write clean and maintainable JSON serialization logic.
- **Current User**: Manage which user is currently acting on the data
- **AciveJob Extensions**: a number of productivity improvements are provided, including:
    - Ability to track the current user across backend tasks
    - Unique jobs to prevent redundant tasks from being ran (requires Redis)
    - Listener integration
    - Timeouts
    - Expiration
    - Reliability feature (requires Redis)
    - Automatic retries with configurable backoff
    - Enhanced serialization for automatically serializing objects via GlobalID, Yaml and special handling for destroyed models
    - Service Objects - Leverage service objects which are designed to be a more robust way of moving complicated logic into ActiveJob
    - Deferrable methods - include the DeferredMethods module to make any model method easily callable as an ActiveJob job
    - Ability to pass provider specific options to the configured queue adapter (currently Sidekiq only)
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

### Listeners

Listeners are central to the MagLev way of doing things. They are an essential way to extract cross-cutting
concerns into their own class. For example, say you have an app that sends email, uses Pusher to send websocket
messages to your client, and your team uses Slack to receive important notifications about your app. You could extract
all of this functionality out into listeners. 

Lets demonstrate this with a Slack listener:

```ruby
# app/listeners/slack_listener.rb
class SlackListener
    def user_created(user)
        # use an active job to do the actual work
        User::NotifyInSlack.perform_later(user)       
    end
    
    # notice that this listener isn't just for users, anything that results in slack messages being created
    # should be placed in this listener so that you can see all Slack related functionality in one place.
    def comment_created(post)
        Comment::NotifyInSlack.perform_later(comment)
    end
    
    # async callback handlers are supported
    def comment_replied_async(post)
        # do slack related code inline here, it will be ran within an ActiveJob since the method was suffixed with _async.
    end
end
```

```ruby
# app/models/user.rb
class User < ActiveRecord::Base
    include MagLev::Broadcastable
    
    after_create do
        # notice that we explicitly indicate which listeners should be broadcasted to. This is done
        # to prevent code indirection. You can still follow what is happening in the flow of data from within this file.  
        broadcast(:user_created, self).to(SlackListener)
    end
end
```
```ruby
# config/initializers/maglev.rb
MagLev.configure do |config|
    config.listeners.registrations = [:SlackListener]
end

```

With listeners you dont have to search through your codebase trying to figure out where and when you send emails, or 
where all of your cache invalidation is done, etc.

#### Disabling Listeners

There is another huge benefit to listeners. You can turn them off. If you have ever added something like 
`skip_slack_notifications` into your code then you will know what I mean. When you have functionality
 wired directly into your models it can slow down your tests, or cause you to embed functionality flags into your
 code so that you can ignore certain sets of functionality. With listeners all you have to do is this:
 
```ruby
MagLev.broadcaster.ignore(SlackListener) do
    
end

# or if you just want to turn it off completely
MagLev.broadcaster.ignore(SlackListener)

# or if you want to just turn on specific listeners for a given operation
MagLev.broadcaster.only(EmailListener) do
    # only the email listener will be in affect
end
```

When combined with our RSpec integration, listeners will be turned off by default within tests. This speeds things
up greatly when you do not mean to test the full code path. To turn them on is simple:

```ruby
describe User, listeners: true do
    # all listeners will be active during these tests
end

# or if you just want to test a specific listener
describe User, listeners: SlackListener do
    # SlackListener will be active during these tests
end

# or if you just want to test a set of listeners
describe User, listeners: [SlackListener, MailListener] do
    # Slack and Email listeners will be active during these tests
end

```

### Serializers

TODO

### Current User

TODO

### Active Job Extensions

#### Retry

By default all jobs are configured to retry up to 10 times, with a decaying backoff time. After 10 attempts each retry will be around once a day.

```ruby
class MyJob < MagLev::ActiveJob::Base
  retry_limit 0 # turn off retries
end
```

```ruby
class MyJob < MagLev::ActiveJob::Base
  # retry up to 30 times, adding an additional minute of delay for each retry attempt
  retry_limit 30
  def retry_delay
    retry_attempt.minutes
  end
end
```

```ruby
class MyJob < MagLev::ActiveJob::Base
  retry_queue :default # default is "retries"
end
```

```ruby
class MyJob < MagLev::ActiveJob::Base
  rescue_from ArgumentError do |ex|
    # dont retry argument errors
  end
end
```

```ruby
class MyJob < MagLev::ActiveJob::Base
  after_retry do
    # called after each time a retry_job is called (done automatically by retry feature)
  end
  
  after_retries_exhausted do
    # all 10 default retry attempts failed, now do something about it
  end
end
```

## Reliable

A basic reliability feature is provided which will store a running job in Redis and remove it once the job has been completed.
Later on the Redis store can be sweeped of any lost jobs that can be recovered (enqueued again). 

To enable simply set `reliable true` within a job. By default this feature is turned off as it depends on Redis and
involves 2 additional external calls for each job. It is recommended to only use this feature on important jobs since it 
will create a performance penelty.

### Service Objects

A special type of base job is provided called a Service Object. A Service Object extends ActiveJob so that the arguments
are set before the perform method is called, so that you can setup extended validation logic, have access to a set of helper methods
and to make testing easier. 

For example, consider the following class that doesn't use active job:

```ruby
class User::SyncChangesWithExternalService
    def initialize(user, changes = user.changes)
        @user = user
        @changes = changes
    end
 
    def should_sync?
        (%w{name email address} & @changes.keys).any?
    end
 
    def perform
        # Do your sync logic here
    end
end

# example of how we might call this object
class SyncListener
    def user_updated(user)
        sync_changes = User::SyncChangesWithExternalService.new(user)
        # notice that we have the should_sync? method which is useful before calling the perform method.
        sync_changes.perform if sync_changes.should_sync?
    end
end
```

If this was a normal ActiveJob object, we wouldn't be able to utilize the `should_sync?` method, since `perform` is essentially
the entry point for the object. We would have to move our logic inside of the perform method, which means that we would have 
to enqueue the job even though we might not need to run it at all. The other option would be to just have a should_sync? method
on the model or within the listener method, but then you are separating your business logic across different files. It doesn't scale
well as your codebase gets more complex. Ideally you want to keep everything related to the context of a specific type of operation
in one place. This is where ServiceObject's come in. 

Here is the same component rewritten as a service object:

```ruby
class User::SyncChangesWithExternalService < MagLev::ActiveJob::ServiceObject
    argument :user, type: User, guard: :nil
    argument :changes do |value|
        value || user.changes
    end
 
    def should_sync?
        (%w{name email address} & changes.keys).any?
    end
 
    def on_perform
        # Do your sync logic here
    end
end
```

Here we use the special `argument` method which declares that the first argument passed in will be called `user` and 2nd will be called `changes`. 
This method will handled initializing the arguments regardless if being ran in-process or when being handled by a queue. 

It also provides additional features. First, it setup a getter method. Then, using the `type` option, we setup a guard to
ensure that the user value passed in is of the right type. We also setup a :nil check to ensure that the value isn't being passed in as nil.
 
For the `changes` argument we also setup a block for transforming the value passed in. In this case we simply replace nil values with 
the `user.changes` value.

Also notice that instead of using a `perform` method we use the `on_perform` method. This is because ActiveJob will need it's perform
method to have the arguments passed in. Our `on_perform` method is actually called by the perform method and doesn't require arguments.

Another advantage to using `on_perform` is that the return value is ignored. With service objects, perform (and perform_now) always return
the service object, making it chainable: 

```ruby
sync_changes.perform_now.user
```

By the way, this is why they are called ServiceObjects and not just Services. Each service acts as its own result object. 
 
```ruby
result = User::Cleanup.perform_now(user)
result.stuff_that_was_cleaned_up
result.other_useful_data_as_a_result_of_the_operation
```

> Technically the above example could be done just as easily with a normal ActiveJob, by ensuring that `self` is returned within
the `perform` method. The point here is that it is encouraged to use the service object pattern this way. It is also encouraged 
to use jobs for functionality that you don't even intend to run within the background. Any distinct operation that has 
a non-trivial implementation is a candidate for being a ServiceObject. 

#### Named Arguments

You can also setup named arguments like so:

```ruby
class User::Cleanup < MagLev::ActiveJob::ServiceObject
    argument :user
    argument :fields_to_clean, named: true, type: Array, default: [:tags]
end

# called like so
User::Cleanup.new(user, fields_to_clean: [:tags, :locations]).enqueue

# or instead using perform_later
User::Cleanup.perform_later(user, fields_to_clean: [:tags, :locations])

```

#### Callbacks

```ruby
    class User::Cleanup < MagLev::ActiveJob::ServiceObject
        argument :user, type: User, guard: :nil
        
        after_arguments do
            # called after the arguments have been initialized
        end
    end
```

#### Argument Inheritance

Something to keep note of is that using the `argument` functionality doesn't work well with inheritance if you need to 
change the argument structure from an inherited class. This is because arguments are stored as an array on the job and the
getter methods that are created by calling `argument` simply point to that array. The reason for doing this is so that
you are never operating on a value that is different from what will be passed to the background queue when `enqueue` is called.

To demonstrate this:

```ruby
class User::Cleanup < MagLev::ActiveJob::ServiceObject
    argument :user, type: User, guard: :nil, default: ->{ User.current }
end

# On a basic level the above code gets turned into this:

class User::Cleanup < MagLev::ActiveJob::ServiceObject
    def name
        arguments[0]
    end
    
    protected
    
    # this method is called to initialize the arguments either during the initialize method or during deserialization
    def initialize_arguments
        arguments[0] ||= User.current
        Guard.nil(:name, name)
        Guard.type(:name, name, User)             
    end
end
```

If you need to use inheritance and change the argument structure, its best to use named arguments where possible. In our
experience if you come to a point where you need to completely change the argument structure on a service object, its usually a good
sign that things are getting too complicated.

#### Scaffolding

A service object generator is provided. i.e.: `rails g service_object User::SyncWithExternalService`

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/maglev.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

