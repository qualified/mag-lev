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