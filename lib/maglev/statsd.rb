require 'concurrent'

module MagLev
  module Statsd
    def self.method_missing(*args, &block)
      statsd_call(*args, &block)
    end

    def self.enabled?
      if @enabled.nil?
        @enabled = !!defined?(StatsD)
      end
      @enabled
    end

    def self.statsd_call(*args, &block)
      if enabled? && StatsD.respond_to?(args.first)
        StatsD.send(*args, &block)
      else
        block.call if block
      end
    end

    # captures information such as count, time, success and failures. You can pass in a root and
    # a branch to capture 2 different levels of information. if you only pass in one key then
    # a root level will not be tracked.
    # example: perform("jobs", "my_worker") {}
    def self.perform(name, tags, &block)
      if enabled?
        begin
          StatsD.measure("#{name}.perform", tags: tags) do
            block.call
          end

          StatsD.increment("#{name}.success", tags: tags)
        rescue Exception
          StatsD.increment("#{name}.failure", tags: tags)
          raise
        end
      else
        block.call
      end
    end
  end
end
