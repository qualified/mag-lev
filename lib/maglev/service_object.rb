module MagLev
  class ServiceObject
    include ClassLogger

    attr_reader :jid

    def executed?
      @executed ||= false
    end

    # executes the context. Inheriting classes should implement a on_execute method.
    def execute(*args)
      if executed?
        logger.warn 'execute skipped, already called once'

      else
        @executed = true
        start = Time.now
        logger.info 'executing...'
        EventReporter.with_context(self.class.name, self) do
          on_execute(*args)
        end
        logger.info "executed - took #{Time.now - start} seconds to complete"
      end

      self
    end

    # can set dynamic sidekiq options to be used when queuing as a background job
    def async_options
      @async_options ||= default_async_options
    end

    def set_async_options(options)
      async_options.merge!(options)
      self
    end

    protected

    def default_async_options
      {}
    end

    def perform_async(*args)
      @jid ||= worker_class.set(async_options).perform_async(*args)
      logger.info 'queued for background execution' if @jid
      self
    end

    def perform_in(duration, *args)
      if duration == 0
        @jid ||= worker_class.set(async_options).perform_async(*args)
      else
        @jid ||= worker_class.set(async_options).perform_in(duration, *args)
      end
      logger.info "queued for delayed background execution in #{duration}" if @jid
      self
    end

    def perform_at(at, *args)
      @jid ||= worker_class.set(async_options).perform_at(at, *args)
      logger.info "queued for delayed background execution at #{at}" if @jid
      self
    end

    def worker_class
      self.class::Worker
    end
  end
end