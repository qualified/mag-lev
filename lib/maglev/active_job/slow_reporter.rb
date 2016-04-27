module MagLev
  module ActiveJob
    module SlowReporter
      extend ActiveSupport::Concern

      included do
        extended_option :slow_threshold

        around_perform do |job, block|
          start = Time.now
          begin
            block.call
          ensure
            if extended_options['slow_threshold']
              threshold = extended_options['slow_threshold'].to_i
              time = Time.now - start
              if threshold < time
                MagLev::EventReporter.warn("#{self.class.name} was found to be too slow", arguments: arguments)
              end
            end
          end
        end
      end
    end
  end
end