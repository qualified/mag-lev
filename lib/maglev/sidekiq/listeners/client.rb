module MagLev
  module Sidekiq
    module Listeners
      # Handles setting any logic related to the `listeners` config value.
      #  Values can be:
      #     - true (use default listeners)
      #     - false (off)
      #     - :inherit (whatever listeners are currently listening will be passed to Sidekiq)
      class Client
        def call(worker_class, msg, queue, redis_pool)

          # set default value for listeners
          unless msg.has_key?(:listeners)
            # the default value is true, unless we are in the test environment, in which
            # we have to use inherit since listeners are always enabled on a per need basis
            # TODO: decide if we should just always inherit by default, to avoid this muddyness
            msg[:listeners] = MagLev.test? ? :inherit : true
          end

          # if globally enabled cool
          if Broadcaster.instance.enabled?
            # if inherit is set then that indicates that we should use the existing set of listeners instead
            # of assuming the defaults on the sidekiq server
            if msg[:listeners] == :inherit
              msg[:listeners] = Broadcaster.instance.listeners.map(&:class)
            end
          end

          yield
        end
      end
    end
  end
end
