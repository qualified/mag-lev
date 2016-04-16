module MagLev
  module Sidekiq
    # ensures that the worker does not take up resources for too long. Ruby timeouts can be very
    # problematic and they should only be used as a last-last case resort. Timeouts should be attempted
    # to be handled at a lower level (like using HTTP timeouts). The value here should be set to something
    # like 10 minutes, something unlikely to happen but if it does you are protected with the lesser evil.
    # As a precaution to make sure too small of a timeout is not used, the smallest value allowed is 30 seconds.
    module Timeout
      class Server
        def call(worker_class, msg, queue)
          if msg['timeout']
            ::Timeout.timeout([msg['timeout'].to_i, 30].max) do
              yield
            end
          else
            yield
          end
        end
      end
    end
  end
end
