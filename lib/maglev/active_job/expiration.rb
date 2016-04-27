module MagLev
  module ActiveJob
    module Expiration
      extend ActiveSupport::Concern

      included do
        extended_option :expires_at
        extended_option :expires_in

        before_enqueue do
          if extended_options['expires_at']
            extended_options['expires_at'] = extended_options['expires_at'].to_s
          end

          if extended_options['expires_in']
            extended_options['expires_at'] = (Time.now + extended_options.delete('expires_in')).to_s
          end
        end

        around_perform do |_, block|
          if extended_options['expires_at']
            if extended_options['expires_at'].to_time < Time.now
              MagLev::Statsd.next_cycle.increment("active_job.expired")
              MagLev::Statsd.next_cycle.increment("active_job.expired.#{self.class.name}")
              logger.info { "Job is expired" }
              next
            end
          end

          block.call
        end

      end
    end
  end
end