module ActiveJob
  module QueueAdapters
    # == Sidekiq adapter for Active Job with additional "provider_options" feature
    #
    # Simple, efficient background processing for Ruby. Sidekiq uses threads to
    # handle many jobs at the same time in the same process. It does not
    # require Rails but will integrate tightly with it to make background
    # processing dead simple.
    #
    # Read more about Sidekiq {here}[http://sidekiq.org].
    #
    # To use Sidekiq set the queue_adapter config to +:sidekiq+.
    #
    #   require 'maglev/active_job/adapters/sidekiq_adapter'
    #   Rails.application.config.active_job.queue_adapter = :sidekiq
    class SidekiqAdapter
      def enqueue(job) #:nodoc:
        #Sidekiq::Client does not support symbols as keys
        Sidekiq::Client.push(base_msg(job))
      end

      def enqueue_at(job, timestamp) #:nodoc:
        Sidekiq::Client.push(base_msg(job).merge('at' => timestamp))
      end

      def base_msg(job)
        msg = {
          'class' => job.try(:job_wrapper) || JobWrapper,
          'wrapped' => job.class.to_s,
          'queue' => job.queue_name,
          'args'  => [ job.serialize ]
        }

        if job.respond_to?(:extended_options)
          msg.merge!((job.extended_options['provider_options'] || {}).stringify_keys)
        end

        msg
      end

      class JobWrapper #:nodoc:
        include Sidekiq::Worker

        def perform(job_data)
          begin
            Base.execute job_data.merge("provider_job_id" => jid)
          ensure
            RequestStore.clear!
          end
        end
      end
    end
  end
end
