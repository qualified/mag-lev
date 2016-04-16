module MagLev
  module Sidekiq
    # You can set a "slow_threshold" on a worker. If set, the worker will be reported to the event service
    # if it takes longer than the threshold. Useful for tracking slow jobs and specifically which data may be slow.
    module SlowReporter
      class Server
        def call(worker, msg, queue, &block)
          start = Time.now
          begin
            block.call
          ensure
            if msg['slow_threshold']
              threshold = msg['slow_threshold'].to_i
              time = Time.now - start
              if threshold < time
                name = msg['wrapped'.freeze] || worker.class.to_s
                MagLev::EventReporter.warn("#{name} was found to be too slow", msg: msg)
              end
            end
          end
        end
      end
    end
  end
end
