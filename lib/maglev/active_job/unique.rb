module MagLev
  module ActiveJob
    module Unique
      extend ActiveSupport::Concern

      included do
        extended_option :unique

        around_enqueue do |job, block|
          if extended_options['unique']
            if lock.acquire
              block.call
            else
              logger.info { "Skipping due to not being unique" }
              MagLev::Statsd.increment('active_job.unique.skipped')
            end
          else
            block.call
          end
        end

        around_perform do |job, block|
          # unique code only executes if it is enabled and was actually sent to the queue
          if extended_options['unique'] and serialized?
            # an early release means that we will release the lock before trying to execute the worker.
            # For workers that may take a long time to run this may be a good idea to use, but be careful
            # because you could end up with multiple workers in the queue and if one fails, many could be queued
            # but not running
            early_release = unique_options['early_release']
            begin
              release_lock if early_release
              block.call
            ensure
              release_lock unless early_release
            end
          else
            block.call
          end
        end

        protected

        def release_lock
          unless lock.release
            MagLev::Statsd.increment('active_job.unique.already_released')
            logger.warn "Unique Job: lock for #{unique_options['key']} was ALREADY RELEASED prior to the job completing"
          end
        end

        def lock
          @lock ||= MagLev::Lock.new(unique_options['key'], unique_options['timeout'])
        end

        def unique_options
          @unique_options ||= extended_option_config(:unique,
            'key' => "#{self.class.name}:#{Digest::MD5.hexdigest(arguments.map(&:to_s).to_json)}",
            'timeout' => 10.minutes
          )
        end
      end
    end
  end
end