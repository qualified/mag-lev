module MagLev
  module ActiveJob
    module Stats
      extend ActiveSupport::Concern

      included do
        after_exception do
          MagLev::Statsd.increment("active_job.exception")
          MagLev::Statsd.increment("active_job.exception.#{@exception.class.name}")
        end

        after_retry do
          MagLev::Statsd.increment("active_job.retries")
          MagLev::Statsd.increment("active_job.retries.#{self.class.name}")
        end

        after_retries_exhausted do
          MagLev::Statsd.increment("active_job.retries_exhausted")
          MagLev::Statsd.increment("active_job.retries_exhausted.#{self.class.name}")
        end

        before_enqueue do
          MagLev::Statsd.increment("active_job.enqueued")
          MagLev::Statsd.increment("active_job.enqueued.#{self.class.name}")
        end

        around_perform do |job, block|
          MagLev::Statsd.increment('active_job.perform.started')
          MagLev::Statsd.perform("active_job.jobs", self.class.name) do
            block.call
          end
        end
      end
    end
  end
end