module MagLev
  module ActiveJob
    module Stats
      extend ActiveSupport::Concern

      included do
        after_exception do
          MagLev::Statsd.batch do |batch|
            batch.increment("active_job.exception")
            batch.increment("active_job.exception.#{@exception.class.name}")
          end
        end

        after_retry do
          MagLev::Statsd.next_cycle do |batch|
            batch.increment("active_job.retries")
            batch.increment("active_job.retries.#{self.class.name}")
          end
        end

        after_retries_exhausted do
          MagLev::Statsd.batch do |batch|
            batch.increment("active_job.retries_exhausted")
            batch.increment("active_job.retries_exhausted.#{self.class.name}")
          end
        end

        before_enqueue do
          MagLev::Statsd.next_cycle do |batch|
            batch.increment("active_job.enqueued")
            batch.increment("active_job.enqueued.#{self.class.name}")
          end
        end

        around_perform do |job, block|
          MagLev::Statsd.next_cycle.increment('active_job.perform.started')
          MagLev::Statsd.perform("jobs", self.class.name) do
            block.call
          end
        end
      end
    end
  end
end