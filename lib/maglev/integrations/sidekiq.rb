module MagLev
  module Integrations
    module Sidekiq
      module Heartbeat
        def self.start
          set_heartbeat
          set_metrics_cycle
        end

        protected

        def self.set_heartbeat
          # since heartbeats can handle uniquness, we are able to update more often then just the 10ms time window
          id = rand(999999) # Process.id does not give us a unique number on AWS/Docker
          last_heartbeat = Time.now
          @task = Concurrent::TimerTask.new(execution_interval: MagLev.config.sidekiq.heartbeat_interval, run_now: true) do
            MagLev::Statsd.set('sidekiq.heartbeats', id)

            # anytime a heartbeat takes longer than 2 cycles we want to log it as a stutter to keep track
            # of a system that may be getting overloaded
            if last_heartbeat < (MagLev.config.sidekiq.heartbeat_interval*2).seconds.ago
              MagLev::Statsd.increment('sidekiq.stutter_heartbeats')
            end

            # interval = MagLev.config.sidekiq.max_heartbeat_interval
            # if interval and last_heartbeat < interval.seconds.ago
            #   MagLev::Statsd.increment('sidekiq.exits')
            #   MagLev.logger.warn("Heartbeat to spuradic, exiting process expecting supervisor to restart it")
            #   exit
            # end

            last_heartbeat = Time.now
          end
          @task.execute
        end

        def self.set_metrics_cycle
          MagLev::Statsd.every_cycle do |batch|
            begin
              batch.count('sidekiq.processor.failed', ::Sidekiq::Processor::FAILURE.value)
              batch.count('sidekiq.processor.processed', ::Sidekiq::Processor::PROCESSED.value)
              batch.count('sidekiq.processor.busy', ::Sidekiq::Processor::WORKER_STATE.size)
              ::Sidekiq::Queue.all.each do |queue|
                batch.gauge("sidekiq.queue.#{queue.name}.size", queue.size)
              end

              stats = ::Sidekiq::Stats.new
              batch.gauge("sidekiq.processed", stats.processed)
              batch.gauge("sidekiq.failed", stats.failed)
              batch.gauge("sidekiq.scheduled_size", stats.scheduled_size)
              batch.gauge("sidekiq.retry_size", stats.retry_size)
              batch.gauge("sidekiq.dead_size", stats.dead_size)
              batch.gauge("sidekiq.processes_size", stats.processes_size)
              batch.gauge("sidekiq.default_queue_latency", stats.default_queue_latency)
              batch.gauge("sidekiq.workers_size", stats.workers_size)
              batch.gauge("sidekiq.enqueued", stats.enqueued)

            rescue Redis::CannotConnectError
              # just ignore since this is usually a startup issue
            rescue => ex
              MagLev.logger.error(ex)
            end
          end
        end
      end

  end
  end
end