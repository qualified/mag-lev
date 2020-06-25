# 0.2.3
- Added ability to optionally define a custom AsyncJob for each listener. This job will be used when handling async events for that given listener.
- Retry schedule no longer allows an extreme level of randomness

# 0.2.2
- Added ability to camelize keys within serializer, to be used with arrays and hash objects not set via nested serializers
- ActiveJob only drains pending operations if entry/parent job

# 0.2.0
- Added operations queue, which allows operations to be performed after all other listeners have been fired
- Added `broadcaster#suspend` method as a more semantic version of calling `only` without any arguments