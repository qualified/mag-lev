module MagLev
  module Sidekiq
    module UniqueJobs
      class Server
        def call(worker_class, msg, queue)
          # an early release means that we will release the lock before trying to execute the worker.
          # For workers that may take a long time to run this may be a good idea to use, but be careful
          # because you could end up with multiple workers in the queue and if one fails, many could be queued
          # but not running
          early_release = msg['unique'] == 'early_release'

          if msg['unique_key']
            context = UniqueJobs::Context.new(worker_class, msg)
            begin
              release(context) if early_release
              yield
              release(context) unless early_release
            rescue ::Sidekiq::Shutdown
              # ignore, will be pushed back onto queue during hard_shutdown
              raise
            rescue Exception => ex
              # if retries are turned off or we are out of retries, then release the lock
              if msg['retry'] == false or msg['retry_count'] == msg['retry']
                release(context) unless early_release
              end
              raise
            end
          else
            yield
          end
        end

        protected

        def release(context)
          unless context.lock.release
            MagLev::Statsd.increment('sidekiq.unique_jobs.already_released')
            Rails.logger.warn "Unique Job: lock for #{context.lock_key} was ALREADY RELEASED prior to the job completing"
          end
        end
      end
    end
  end
end
