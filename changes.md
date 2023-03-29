# 0.8.2
- Updated DeferredMethods for compatibility with Ruby 3.0 keyword arguments.
# 0.8.1
- Require `redis` gem older than v5.0.
# 0.8
- Updated enhanced serialize and arguments to handle keyword arguments for Ruby 3.0
# 0.7
- Updated dependencies (activemodel, activejob, activesupport, rails) for compatibility with rails 6.1
# 0.6
- current_user_class now sets to an object lazily, which fixes issues with autoloading constants during Rails initialization
# 0.5
- Updated dependencies (activemodel, activejob, activesupport, rails) for compatibility with rails 6.0
# 0.4
- operations_queue no longer suspends listeners. Should now do this manually within the operation if the functionality is needed.
- serializer now tries to default to relation name, instead of sends - in order to prevent issues where the relation might not actually exist on the model
- fixed guard error message (was missing ending parenthesis)
# 0.3.5
- Clear request store on each Sidekiq job
- SidekiqAdapter methods switched to instance based 

# 0.3.4
- Added support for ActiveJob NewRelic transaction names, if NewRelic gem is loaded

# 0.3.3
- Added "source" as a context value to statsd and event reporter context when broadcasting events

# 0.3.2
- Added "broadcasts.events" statsd event

# 0.3.1
- StatsD updated to use tags instead of multiple measures

# 0.3.0
- StatsD implementation changed to use statsd-instrument instead of statsd-ruby

# 0.2.9
- DeferredJobs unique options given a better unique key and reduced in timeout

# 0.2.8
- UnitOfWork as_json added to prevent stack errors when serializing models

# 0.2.7
- Unique now converts arguments to strings before creating a uniqueness key, which should fix issues where jobs were not being treated as unique

# 0.2.6
- Reliable now wraps redis calls in a rescue to ensure that the functionality doesn't cause the actual job to fail

# 0.2.5
- ServiceObject generator now includes predefined logger_name method 

# 0.2.4
- Reliable#recover fixed by utilizing JSON to further serialize job hash

# 0.2.3
- Added ability to optionally define a custom AsyncJob for each listener. This job will be used when handling async events for that given listener.
- Retry schedule no longer allows an extreme level of randomness

# 0.2.2
- Added ability to camelize keys within serializer, to be used with arrays and hash objects not set via nested serializers
- ActiveJob only drains pending operations if entry/parent job

# 0.2.0
- Added operations queue, which allows operations to be performed after all other listeners have been fired
- Added `broadcaster#suspend` method as a more semantic version of calling `only` without any arguments
