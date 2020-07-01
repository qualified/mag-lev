module MagLev
  module ActiveJob
    # provides a basic reliable queueing mechanism. Each job is added to a Redis
    # hash with a timestamp, when the job completes or fails it is acknowledged and removed
    # from the hash. Any jobs that sit within the hash for too long can later be sweeped and retried
    # using the "recover" method.
    module Reliable
      extend ActiveSupport::Concern

      included do
        extended_option :reliable

        around_perform do |job, block|
          if extended_options['reliable'] and serialized?
            rely!(&block)
          else
            block.call
          end
        end
      end

      def self.count
        MagLev.redis {|r| r.hlen(key) }
      end

      def self.key
        @reliable_key ||= "#{MagLev.env_name}_aj_reliable"
      end

      def self.find_since(time)
        MagLev.redis do |conn|
          conn.hgetall(key).select {|k, v| v.to_time < time}
        end
      end

      # retries any unaknowledged jobs that are older than the time provided (default = 30 minutes)
      def self.recover(time = 30.minutes.ago)
        MagLev.redis do |conn|
          find_since(time).each do |key, value|
            job = MagLev::ActiveJob::Base.deserialize(JSON.parse(key))
            job.extended_options['reliable_retry'] = true
            job.retry_job
            conn.hdel(self.key, key)
          end.count
        end
      end

      protected

      def rely_key
        @rely_key ||= serialize.to_json
      end

      # adds the job to the reliable collection. Provided as its own method so that a job
      # could optionally decide to use reliable functionality within its own perform method.
      # A block should be provided so that ack! will be sure to be called
      def rely!(&block)
        MagLev.redis do |conn|
          conn.hset(Reliable.key, rely_key, Time.now)
        end
        @rely = true

        if block
          begin
            block.call
          ensure
            ack!
          end
        end
      end

      # acknowledge the job is done. Provided here as its own method so that a complex
      # job could ack before it completes, if the need is there. This method is idempotent.
      def ack!
        if @rely
          MagLev.redis {|r| r.hdel(Reliable.key, rely_key) }
          @rely = false
          true
        else
          false
        end
      end
    end
  end
end