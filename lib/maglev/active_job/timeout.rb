module MagLev
  module ActiveJob
    # ensures that the worker does not take up resources for too long. Ruby timeouts can be very
    # problematic and they should only be used as a last-last case resort. Timeouts should be attempted
    # to be handled at a lower level (like using HTTP timeouts). The value here should be set to something
    # like 10 minutes, something unlikely to happen but if it does you are protected with the lesser evil.
    # As a precaution to make sure too small of a timeout is not used, the smallest value allowed is 30 seconds.
    module Timeout
      extend ActiveSupport::Concern

      included do
        extended_option :timeout

        around_perform do |job, block|
          if extended_options['timeout']
            begin
              ::Timeout.timeout([extended_options['timeout'].to_i, 30].max) do
                block.call
              end
            rescue ::Timeout::Error
              MagLev::Statsd.increment("active_job.timeouts.count")
              MagLev::Statsd.increment("active_job.timeouts.#{self.class.name}.count")
              raise
            end
          else
            block.call
          end
        end
      end
    end
  end
end