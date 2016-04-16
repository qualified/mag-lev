require 'digest'
module MagLev
  module Sidekiq
    module UniqueJobs
      class Context
        attr_reader :msg, :worker_class

        def initialize(worker_class, msg)
          @worker_class = worker_class.is_a?(String) ? worker_class : worker_class.class.name
          @msg = msg
          @lock_key = msg['unique_key']
        end

        def lock
          @lock ||= MagLev::Lock.new(lock_key, unique_timeout)
        end

        def lock_key
          @lock_key ||= "#{worker_class}:#{lock_key_digest}"
        end

        def lock_key_digest
          @lock_key_digest ||= Digest::MD5.hexdigest(args.to_json)
        end

        def args
          msg['args']
        end

        def unique_timeout
          msg['unique_timeout'] || 10.minutes
        end
      end
    end
  end
end

