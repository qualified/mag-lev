module MagLev
  module ActiveJob
    module Retry
      extend ActiveSupport::Concern

      included do
        define_callbacks :retry
        define_callbacks :retries_exhausted
        define_callbacks :exception

        extended_option :retry_limit
        extended_option :retry_queue
        extended_option :retry_schedule
        extended_option :retry_attempt, internal: true
      end

      def retry_attempt
        extended_options['retry_attempt'].to_i
      end

      def retry_job(options = {})
        run_callbacks :retry do
          options[:queue] ||= extended_options['retry_queue'] || queue_name
          extended_options['retry_attempt'] = retry_attempt + 1
          super
        end
      end

      DEFAULT_RETRY_SCHEDULE = [0, 1.minute, 5.minutes, 10.minutes, 15.minutes, 30.minutes, 45.minutes, 1.hours, 2.hours, 4.hours, 8.hours, 12.hours]

      # calculates the delay that should be used to retry the job. Can be overridden
      # in a class to customize the retry strategy.
      def retry_delay
        schedule = extended_options['retry_schedule'] || DEFAULT_RETRY_SCHEDULE
        # each time we retry, at most we want to
        delay = retry_attempt >= schedule.count ? schedule.last : schedule[retry_attempt]
        # add a degree of randomness to it, but not more than the delay itself, or 30 seconds
        delay + rand([30, delay.to_i].min)
      end

      protected

      def rescue_with_handler(exception)
        run_callbacks :exception do
          @exception = exception
          logger.error "Failed with \"#{exception.message}\", Arguments = #{arguments}"

          if super
            true
          else
            logger.report(:error, exception, arguments: arguments)

            limit = extended_options['retry_limit'].to_i
            # retries are only enabled for enqueued jobs when not in test mode and when the limit > 0
            if limit > 0 and serialized? and !MagLev.config.active_job.test_mode
              if retry_attempt < limit
                retry_job(wait: retry_delay)
                true
              else
                retries_exhausted!
                return false
              end
            else
              return false
            end
          end
        end
      end

      def retries_exhausted!
        run_callbacks :retries_exhausted do
          logger.report(:warn, "Active Job retries have been exhausted", arguments: arguments, job: self.class.name)
        end
      end

      module ClassMethods
        def before_retry(*filters, &blk)
          set_callback(:retry, :before, *filters, &blk)
        end

        def after_retry(*filters, &blk)
          set_callback(:retry, :after, *filters, &blk)
        end

        def after_retries_exhausted(*filters, &blk)
          set_callback(:retries_exhausted, :after, *filters, &blk)
        end

        def after_exception(*filters, &blk)
          set_callback(:exception, :after, *filters, &blk)
        end
      end
    end
  end
end