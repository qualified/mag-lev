module MagLev
  module Sidekiq
    module UniqueJobs
      class Client
        def call(worker_class, msg, queue, redis_pool)
          if !!msg['unique']
            context = UniqueJobs::Context.new(worker_class, msg)
            msg['unique_key'] = context.lock_key
            unless context.lock.acquire
              MagLev::Statsd.increment('sidekiq.unique_jobs.skipped')
              MagLev.logger.info "Skipped queuing job, it is not unique: #{worker_class}"
              return false
            end
          end

          yield
        end
      end
    end
  end
end
