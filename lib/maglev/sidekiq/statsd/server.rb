module MagLev
  module Sidekiq
    module Statsd
      class Server
        def call(worker, msg, queue, &block)
          name = msg['wrapped'.freeze] || worker.class.to_s
          MagLev::Statsd.next_cycle.increment('sidekiq.processor.started')
          MagLev::Statsd.perform("jobs", name, &block)
        end
      end
    end
  end
end
