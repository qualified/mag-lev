module MagLev
  module Sidekiq
    module Statsd
      class Client
        def call(worker_class, msg, queue, redis_pool)
          MagLev::Statsd.next_cycle do |batch|
            batch.increment("sidekiq.enqueued.count")
            batch.increment("sidekiq.enqueued.#{worker_class.to_s}.count")
          end
          yield
        end
      end
    end
  end
end
