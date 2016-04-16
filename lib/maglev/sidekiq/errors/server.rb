module MagLev
  module Sidekiq
    module Errors
      class Server

        # placeholder class that will never actually get used
        class NotDefined < StandardError
        end

        # DocumentNotFound errors should just be logged and not retried
        def call(worker_class, msg, queue)
          @worker_class = worker_class
          @started_at = Time.now
          @msg = msg
          begin
            yield
          rescue (defined?(Mongoid::Errors::DocumentNotFound) ? Mongoid::Errors::DocumentNotFound : NotDefined) => ex
            log(ex)
          rescue (defined?(Neo4j::RecordNotFound) ? Neo4j::RecordNotFound : NotDefined) => ex
            log(ex)
          rescue Exception => ex
            log(ex, :error)
            raise
          end
        end

        def log(ex, level = :warn)
          MagLev.logger.send(level, ex)
          begin
            EventReporter.send(level, ex, sidekiq: {msg: @msg, worker: @worker_class}, time_spent: Time.now - @started_at)
            MagLev::Statsd.batch do |batch|
              batch.increment("sidekiq.exception.#{level}")
              batch.increment("sidekiq.exception.#{level}.#{ex.class.name}")
            end
          rescue => ex
            MagLev.logger.error(ex)
          end
        end
      end
    end
  end
end
