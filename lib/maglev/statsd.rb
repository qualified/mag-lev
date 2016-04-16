module MagLev
  module Statsd
    @mutex = Mutex.new
    @cycle_callbacks = []

    def self.next_cycle_task
      @next_cycle_task
    end

    # provides access to the shared batch that gets flushed every 10 seconds.
    def self.next_cycle
      if client
        # if a block is passed in then we treat next_cycle as the same usage as client.batch
        if block_given?
          yield(next_cycle)
        else
          @mutex.synchronize do
            @next_cycle ||= ::Statsd::Batch.new(client).tap do |batch|
              @next_cycle_task = Concurrent::TimerTask.new(execution_interval: 10, run_now: true) do
                t = Time.now
                Try.new(@cycle_callbacks).each {|cb| cb.call(batch) }
                batch.flush
                @next_cycle_task.execution_interval = 10 - (Time.now - t)
              end
              @next_cycle_task.execute
              MagLev.logger.debug { "Started Statsd batch timer task" }
            end
          end
        end
      else
        # if there is no client just return this class, since it is designed to receive
        # method calls and ignore them if no client exists
        self
      end
    end

    # pass a block which will be called every cycle (10s). A batch object wil be passed in to the callback which
    # must be used to be flushed with the rest of the cycle. Multiple callbacks can be made using the one batch object.
    def self.every_cycle(&block)
      @cycle_callbacks << block
      next_cycle
    end

    def self.client
      MagLev.config.statsd
    end

    def self.batch(&block)
      if client and !Rails.env.test?
        client.batch(&block)
      else
        block.call(self)
      end
    end

    def self.method_missing(*args, &block)
      if client and !MagLev.test?
        client.send(*args, &block)
      else
        block.call if block
      end
    end

    # captures information such as count, time, success and failures. You can pass in a root and
    # a branch to capture 2 different levels of information. if you only pass in one key then
    # a root level will not be tracked.
    # example: perform("jobs", "my_worker") {}
    def self.perform(root, branch = nil, &block)
      return block.call if MagLev.test?

      if branch
        branch = "#{root}.#{branch}"
      else
        branch = root
        root = nil
      end

      if client
        next_cycle do |batch|
          begin
            batch.increment("#{root}.count") if root
            batch.increment("#{branch}.count")
            branch_perform = -> { batch.time("#{branch}.perform", &block) }

            if root
              batch.time("#{root}.perform") do
                branch_perform.call
              end
            else
              branch_perform.call
            end

            batch.increment("#{root}.success") if root
            batch.increment("#{branch}.success")
          rescue Exception
            batch.increment("#{root}.failure") if root
            batch.increment("#{branch}.failure")
            raise
          end

        end
      else
        block.call
      end
    end
  end
end
