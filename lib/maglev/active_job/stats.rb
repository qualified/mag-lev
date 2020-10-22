module MagLev
  module ActiveJob
    module Stats
      extend ActiveSupport::Concern

      included do
        after_exception do
          MagLev::Statsd.increment("active_job.exception", tags: { class: self.class.name, exception: @exception.class.name })
        end

        after_retry do
          MagLev::Statsd.increment("active_job.retries", tags: { class: self.class.name })
        end

        after_retries_exhausted do
          MagLev::Statsd.increment("active_job.retries_exhausted", tags: { class: self.class.name })
        end

        before_enqueue do
          MagLev::Statsd.increment("active_job.enqueued", tags: { class: self.class.name })
        end

        around_perform do |job, block|
          MagLev::Statsd.perform("active_job", { class: self.class.name }) do
            block.call
          end
        end
      end
    end
  end
end